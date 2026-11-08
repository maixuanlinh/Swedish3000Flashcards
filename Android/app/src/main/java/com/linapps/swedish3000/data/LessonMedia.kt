package com.linapps.swedish3000.data

import android.content.Context
import android.os.StatFs
import com.linapps.swedish3000.BuildConfig
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.*
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.coroutineContext
import com.linapps.swedish3000.domain.*

internal fun mediaHash(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
internal fun recordingKey(language: String, text: String) = "audio/$language/${mediaHash(text.toByteArray(Charsets.UTF_8))}"

data class MediaPack(val file: String, val bytes: Long, val sha256: String, val starter: Boolean)
data class MediaItem(val key: String, val pack: String, val offset: Long, val bytes: Int, val sha256: String)
class MediaCatalog(json: JSONObject) {
    val version = json.getString("version")
    val packs: Map<String,MediaPack>
    val items: Map<String,MediaItem>
    init {
        require(json.getString("format")=="sisu-lesson-media-v1" && version.matches(Regex("[0-9a-f]{64}")))
        val p=json.getJSONArray("packs")
        val packList=(0 until p.length()).map { i -> p.getJSONObject(i).let { MediaPack(it.getString("file"),it.getLong("bytes"),it.getString("sha256"),it.getBoolean("starter")) } }
        require(packList.isNotEmpty() && packList.size<=200)
        packList.forEach { require(it.sha256.matches(Regex("[0-9a-f]{64}")) && it.file=="pack-${it.sha256}.bin" && it.bytes in 1..12_000_000) }
        packs=packList.associateBy { it.file };require(packs.size==packList.size)
        val a=json.getJSONArray("assets")
        val itemList=(0 until a.length()).map { i -> a.getJSONObject(i).let { MediaItem(it.getString("key"),it.getString("pack"),it.getLong("offset"),it.getInt("bytes"),it.getString("sha256")) } }
        require(itemList.size in 1..20_000)
        itemList.forEach { require(it.sha256.matches(Regex("[0-9a-f]{64}")) && it.bytes in 1..4_000_000 && it.offset>=0 && it.offset+it.bytes<=packs.getValue(it.pack).bytes) }
        items=itemList.associateBy { it.key };require(items.size==itemList.size)
    }
}

data class MediaStatus(val loading: Boolean=true, val totalBytes: Long=0, val savedBytes: Long=0,
    val installedBytes: Long=0, val packsReady: Int=0, val packCount: Int=0, val error: String?=null,val partialBytes: Long=0) {
    val ready get() = !loading && packCount>0 && packsReady==packCount
    val storageUsedBytes get() = savedBytes+partialBytes
    val remainingBytes get() = (totalBytes-savedBytes-installedBytes-partialBytes).coerceAtLeast(0)
}

internal class MediaResponse(val code: Int, val range: String?, val stream: InputStream, val disconnect: ()->Unit = {}): Closeable {
    override fun close() { try { stream.close() } finally { disconnect() } }
}
internal fun interface MediaSource { fun open(pack: MediaPack, start: Long, end: Long?): MediaResponse }
private class HostedMediaSource(base: String): MediaSource {
    private val url=base.trimEnd('/')+"/"
    init { require(base.isEmpty() || (URL(url).protocol=="https" && URL(url).userInfo==null)) }
    override fun open(pack: MediaPack,start: Long,end: Long?): MediaResponse {
        check(url!="/") { "Lesson downloads are not available in this installation." }
        val connection=URL(url+pack.file).openConnection() as HttpURLConnection
        connection.connectTimeout=15_000;connection.readTimeout=20_000;connection.instanceFollowRedirects=false
        connection.setRequestProperty("Accept-Encoding","identity")
        if(start>0 || end!=null) connection.setRequestProperty("Range","bytes=$start-${end ?: ""}")
        try {
            val code=connection.responseCode
            check(code==200 || code==206) { "The lesson download is unavailable. Please try again later." }
            return MediaResponse(code,connection.getHeaderField("Content-Range"),connection.inputStream) { connection.disconnect() }
        } catch(e: Exception) { connection.disconnect();throw e }
    }
}

/** Stored media is immutable. Full offline packs live in filesDir, never the evictable cache. */
class LessonMedia internal constructor(private val context: Context,
    private val manifest: ()->JSONObject,
    private val source: MediaSource): AutoCloseable {
    constructor(context: Context): this(context,
        { JSONObject(context.assets.open("lesson-media.json").bufferedReader().use { it.readText() }) },
        HostedMediaSource(BuildConfig.MEDIA_BASE_URL))
    val catalog by lazy { MediaCatalog(manifest()) }
    private val directory=File(context.filesDir,"lesson-media").apply { mkdirs() }
    private val cache=File(context.cacheDir,"lesson-media").apply { mkdirs() }
    private val locks=ConcurrentHashMap<String,Mutex>()
    private val verified=ConcurrentHashMap<String,Pair<Long,Long>>()
    private val state=MutableStateFlow(MediaStatus())
    val status=state.asStateFlow()
    private val previewState=MutableStateFlow(MediaStatus())
    val previewStatus=previewState.asStateFlow()
    var previewKeys: Set<String> = emptySet(); private set
    private val previewDirectory=File(directory,"preview").apply { mkdirs() }
    private val verifiedPreviews=ConcurrentHashMap<String,Pair<Long,Long>>()
    suspend fun configurePreview(words: List<Word>) {
        val free=words.filter { it.initial=="A" }
        require(free.isNotEmpty() && (words.size!=3000 || free.size==211))
        previewKeys=free.flatMap { listOf("image/${it.image}","image/${it.thumbnail}",recordingKey("en-US",it.english),recordingKey("sv-SE",it.swedish),recordingKey("sv-SE",it.sentence)) }.toSet()
        require(previewKeys.all { it in catalog.items })
        refresh()
    }
    private fun previewFile(item: MediaItem): File? {
        val file=File(previewDirectory,item.sha256)
        if(!file.isFile || file.length()!=item.bytes.toLong()) return null
        val signature=file.length() to file.lastModified()
        if(verifiedPreviews[item.sha256]!=signature) {
            if(mediaHash(file.readBytes())!=item.sha256) { file.delete();return null }
            verifiedPreviews[item.sha256]=signature
        }
        return file
    }
    suspend fun downloadPreview(key: String) = withContext(Dispatchers.IO) {
        require(key in previewKeys) { "Only A-set lessons are available for Free offline study." }
        val item=catalog.items.getValue(key)
        locks.getOrPut("preview:${item.sha256}") { Mutex() }.withLock {
            val pack=catalog.packs.getValue(item.pack)
            if(installed(pack) || saved(pack)!=null || previewFile(item)!=null) return@withLock
            val data=load(key)
            coroutineContext.ensureActive()
            val temporary=File(previewDirectory,item.sha256+".tmp")
            FileOutputStream(temporary).use { it.write(data);it.fd.sync() }
            coroutineContext.ensureActive()
            check(temporary.renameTo(File(previewDirectory,item.sha256)))
            refresh()
        }
    }
    private val bundled by lazy { context.assets.list("").orEmpty().toSet() }
    private fun installed(pack: MediaPack) = pack.file in bundled
    private fun saved(pack: MediaPack): File? {
        val file=File(directory,pack.file)
        if(!file.isFile || file.length()!=pack.bytes) return null
        val signature=file.length() to file.lastModified()
        if(verified[pack.file]!=signature) {
            if(mediaHash(file.readBytes())!=pack.sha256) { file.delete();verified.remove(pack.file);return null }
            verified[pack.file]=signature
        }
        return file
    }
    suspend fun refresh() = withContext(Dispatchers.IO) {
        try {
            val p=catalog.packs.values
            // Old versions cannot be read with the current immutable manifest.
            directory.listFiles().orEmpty().filter { it.name.matches(Regex("pack-[0-9a-f]{64}\\.bin(\\.part)?")) && it.name.removeSuffix(".part") !in catalog.packs }
                .forEach { it.delete() }
            state.value=MediaStatus(false,p.sumOf { it.bytes },p.filter { !installed(it) && saved(it)!=null }.sumOf { it.bytes },
                p.filter(::installed).sumOf { it.bytes },p.count { installed(it) || saved(it)!=null },p.size,
                partialBytes=p.filter { !installed(it) && saved(it)==null }.sumOf { File(directory,it.file+".part").length().coerceAtMost(it.bytes) })
            if(previewKeys.isNotEmpty()) {
                val assets=previewKeys.map { catalog.items.getValue(it) }
                val included=assets.filter { installed(catalog.packs.getValue(it.pack)) }
                val downloaded=assets.filter { !installed(catalog.packs.getValue(it.pack)) && (saved(catalog.packs.getValue(it.pack))!=null || previewFile(it)!=null) }
                previewState.value=MediaStatus(false,assets.sumOf { it.bytes.toLong() },downloaded.sumOf { it.bytes.toLong() },included.sumOf { it.bytes.toLong() },included.size+downloaded.size,assets.size)
            }
        } catch(e: Exception) {
            if(e is CancellationException) throw e
            previewState.value=MediaStatus(loading=false,error="Lesson downloads could not be loaded. Please try again.")
            state.value=MediaStatus(loading=false,error="Lesson downloads could not be loaded. Please try again.")
        }
    }
    fun missingPacks() = catalog.packs.values.filter { !installed(it) && saved(it)==null }
    private fun readRange(input: InputStream,item: MediaItem): ByteArray {
        var remaining=item.offset
        while(remaining>0) { val n=input.skip(remaining);if(n>0) remaining-=n else { check(input.read()!=-1);remaining-- } }
        val data=ByteArray(item.bytes);DataInputStream(input).readFully(data)
        check(mediaHash(data)==item.sha256) { "This lesson could not be verified. Connect to the internet and try again." }
        return data
    }
    /** Used by notifications: never starts a network request. */
    fun cached(key: String): ByteArray? {
        val item=catalog.items[key] ?: return null
        val pack=catalog.packs.getValue(item.pack)
        val local=if(installed(pack)) null else saved(pack)
        return runCatching {
            when {
                installed(pack) -> context.assets.open(pack.file).use { readRange(it,item) }
                local!=null -> local.inputStream().use { readRange(it,item) }
                else -> (previewFile(item) ?: File(cache,item.sha256).takeIf { it.isFile })?.readBytes()?.takeIf { mediaHash(it)==item.sha256 }
            }
        }.onFailure { if(local!=null) { local.delete();verified.remove(pack.file) } }.getOrNull()
    }
    suspend fun load(key: String): ByteArray = withContext(Dispatchers.IO) {
        val item=catalog.items[key] ?: error("This lesson has no recording or illustration available.")
        locks.getOrPut(item.sha256) { Mutex() }.withLock {
            cached(key)?.let { return@withLock it }
            if(state.value.ready) refresh()
            val pack=catalog.packs.getValue(item.pack)
            val bytes=source.open(pack,item.offset,item.offset+item.bytes-1).use { response ->
                if(response.code==206) {
                    check(response.range=="bytes ${item.offset}-${item.offset+item.bytes-1}/${pack.bytes}") { "The lesson download could not be verified." }
                    val data=ByteArray(item.bytes);DataInputStream(response.stream).readFully(data);data
                } else {
                    // Hosts without Range support may return one whole, bounded pack.
                    val bytes=readBounded(response.stream,pack.bytes)
                    check(bytes.size.toLong()==pack.bytes && mediaHash(bytes)==pack.sha256)
                    bytes.copyOfRange(item.offset.toInt(),item.offset.toInt()+item.bytes)
                }
            }
            check(mediaHash(bytes)==item.sha256) { "The lesson download could not be verified. Please retry." }
            coroutineContext.ensureActive()
            val file=File(cache,item.sha256)
            val temporary=File(cache,item.sha256+".tmp")
            temporary.writeBytes(bytes);check(temporary.renameTo(file))
            file.setLastModified(System.currentTimeMillis())
            trimCache()
            bytes
        }
    }
    suspend fun prefetch(words: List<Word>,access: Entitlement) {
        for((kind,value) in prefetchLessons(words,access)) {
            coroutineContext.ensureActive()
            try { load(if(kind=="image") "image/$value" else recordingKey(kind.removePrefix("audio/"),value)) }
            catch(e: CancellationException) { throw e }
            catch(_: Exception) { return } // Swiping never waits for speculative downloads.
        }
    }
    suspend fun download(pack: MediaPack) = withContext(Dispatchers.IO) {
        locks.getOrPut(pack.file) { Mutex() }.withLock {
            if(installed(pack) || saved(pack)!=null) return@withLock
            val partial=File(directory,pack.file+".part")
            if(partial.length()>pack.bytes) partial.delete()
            if(partial.isFile && partial.length()==pack.bytes) {
                if(mediaHash(partial.readBytes())==pack.sha256) {
                    check(partial.renameTo(File(directory,pack.file)));refresh();return@withLock
                }
                partial.delete()
            }
            check(StatFs(directory.path).availableBytes>pack.bytes-partial.length()+16_000_000) { "There isn’t enough free storage. Free some space and try again." }
            val start=partial.length()
            source.open(pack,start,null).use { response ->
                val append=response.code==206 && start>0
                if(response.code==206) check(response.range=="bytes $start-${pack.bytes-1}/${pack.bytes}") { "The download could not be verified." }
                val already=if(append) start else 0L
                FileOutputStream(partial,append).use { out ->
                    val buffer=ByteArray(32768);var count=already
                    while(true) {
                        coroutineContext.ensureActive()
                        val n=response.stream.read(buffer);if(n<0) break
                        count+=n;check(count<=pack.bytes) { "The downloaded lesson pack is too large." };out.write(buffer,0,n)
                    }
                    out.fd.sync()
                }
            }
            check(partial.length()==pack.bytes) { "The download was interrupted. Tap Download to continue." }
            if(mediaHash(partial.readBytes())!=pack.sha256) { partial.delete();error("The download could not be verified. Please retry.") }
            coroutineContext.ensureActive()
            check(partial.renameTo(File(directory,pack.file)))
            refresh()
        }
    }
    suspend fun removeDownloads() = withContext(Dispatchers.IO) {
        directory.listFiles().orEmpty().forEach { file ->
            if(file.name.matches(Regex("pack-[0-9a-f]{64}\\.bin(\\.part)?"))) locks.getOrPut(file.name.removeSuffix(".part")) { Mutex() }.withLock {
                if(file.exists()) check(file.delete())
            }
        }
        previewDirectory.listFiles().orEmpty().forEach { file ->
            locks.getOrPut("preview:${file.name.removeSuffix(".tmp")}") { Mutex() }.withLock { if(file.exists()) check(file.delete()) }
        }
        verified.clear();verifiedPreviews.clear()
        refresh()
    }
    fun checkSpace(previewOnly: Boolean=false) { check(StatFs(directory.path).availableBytes>(if(previewOnly) previewState.value else status.value).remainingBytes+16_000_000) { "There isn’t enough free storage for all lessons. Free some space and try again." } }
    private fun trimCache() {
        val files=cache.listFiles().orEmpty().filter { it.name.matches(Regex("[0-9a-f]{64}")) }.sortedBy { it.lastModified() }
        var bytes=files.sumOf { it.length() }
        files.forEach { if(bytes>64_000_000) { val size=it.length();if(it.delete()) bytes-=size } }
    }
    override fun close() {}
    private suspend fun readBounded(input: InputStream,limit: Long): ByteArray {
        val out=ByteArrayOutputStream();val buffer=ByteArray(32768)
        while(true) { coroutineContext.ensureActive();val n=input.read(buffer);if(n<0) break;check(out.size().toLong()+n<=limit);out.write(buffer,0,n) }
        return out.toByteArray()
    }
}
