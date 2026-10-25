package com.linapps.swedish3000.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.util.AtomicFile
import android.util.Base64
import com.linapps.swedish3000.domain.Word
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.time.Instant
import java.util.UUID

data class ArtworkRevision(val id: String, val wordId: String, val prompt: String, val memoryHook: String,
    val filename: String, val thumbnail: String, val createdAt: String, val source: String, val width: Int, val height: Int, val bytes: Int, val active: Boolean)
data class SavedPrompt(val id: String, val text: String, val memoryHook: String, val createdAt: String)
data class ArtworkHistory(val images: List<ArtworkRevision> = emptyList(), val prompts: List<SavedPrompt> = emptyList())

class ArtworkRepository(private val context: Context) {
    private val directory=File(context.filesDir,"artwork").apply { mkdirs() }
    private val lock=Mutex()
    private val histories=mutableMapOf<String,ArtworkHistory>()
    @Synchronized fun history(id: String): ArtworkHistory = histories[id] ?: run {
        require(id.matches(Regex("[a-zA-Z0-9-]+")))
        val file=AtomicFile(File(directory,"$id.json"))
        val json=if(file.baseFile.exists()) JSONObject(file.openRead().bufferedReader().use { it.readText() }) else JSONObject()
        val images=json.optJSONArray("images") ?: JSONArray()
        val prompts=json.optJSONArray("prompts") ?: JSONArray()
        ArtworkHistory((0 until images.length()).map { index -> images.getJSONObject(index).let {
            ArtworkRevision(it.getString("id"),id,it.getString("prompt"),it.getString("memoryHook"),it.getString("filename"),it.getString("thumbnail"),it.getString("createdAt"),it.getString("source"),it.getInt("width"),it.getInt("height"),it.getInt("bytes"),it.getBoolean("active"))
        } },(0 until prompts.length()).map { index -> prompts.getJSONObject(index).let { SavedPrompt(it.getString("id"),it.getString("text"),it.getString("memoryHook"),it.getString("createdAt")) } }).also { histories[id]=it }
    }
    fun active(id: String)=history(id).images.firstOrNull { it.active && file(it.filename).isFile }
    fun file(path: String): File {
        val result=File(directory,path).canonicalFile
        require(result.path.startsWith(directory.canonicalPath+File.separator)) { "Invalid artwork path." }
        return result
    }
    private fun save(id: String, value: ArtworkHistory) {
        val images=JSONArray(value.images.map { r -> JSONObject().apply {
            put("id",r.id); put("prompt",r.prompt);put("memoryHook",r.memoryHook);put("filename",r.filename);put("thumbnail",r.thumbnail)
            put("createdAt",r.createdAt);put("source",r.source);put("width",r.width);put("height",r.height);put("bytes",r.bytes);put("active",r.active)
        } })
        val prompts=JSONArray(value.prompts.map { p -> JSONObject().apply { put("id",p.id);put("text",p.text);put("memoryHook",p.memoryHook);put("createdAt",p.createdAt) } })
        val atomic=AtomicFile(File(directory,"$id.json")); val out=atomic.startWrite()
        try { out.write(JSONObject().put("images",images).put("prompts",prompts).toString().toByteArray()); atomic.finishWrite(out) }
        catch(e: Exception) { atomic.failWrite(out); throw e }
        synchronized(this) { histories[id]=value }
    }
    private fun withPrompt(old: ArtworkHistory, prompt: String, hook: String): ArtworkHistory {
        if(prompt.isBlank() || (old.prompts.firstOrNull()?.let { it.text==prompt && it.memoryHook==hook }==true)) return old
        return old.copy(prompts=listOf(SavedPrompt(UUID.randomUUID().toString(),prompt,hook,Instant.now().toString()))+old.prompts)
    }
    suspend fun savePrompt(id: String, prompt: String, hook: String) = withContext(Dispatchers.IO) { lock.withLock { save(id,withPrompt(history(id),prompt,hook)) } }
    suspend fun activate(id: String, revisionId: String?) = withContext(Dispatchers.IO) { lock.withLock {
        val old=history(id)
        if(revisionId!=null) check(old.images.any { it.id==revisionId && file(it.filename).isFile }) { "This image is no longer available." }
        save(id,old.copy(images=old.images.map { it.copy(active=it.id==revisionId) }))
    } }
    suspend fun importImage(word: Word, uri: Uri, prompt: String, hook: String, source: String) = withContext(Dispatchers.IO) {
        val bytes=context.contentResolver.openInputStream(uri)?.use { readLimited(it,30*1024*1024) } ?: error("The image could not be opened.")
        importBytes(word,bytes,prompt,hook,source)
    }
    private fun validate(bytes: ByteArray) {
        require(bytes.size<=30*1024*1024) { "Choose an image smaller than 30 MB." }
        val options=BitmapFactory.Options().apply { inJustDecodeBounds=true }
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
        require(options.outWidth>0 && options.outHeight>0 && options.outWidth.toLong()*options.outHeight<=150_000_000) { "Choose a valid image up to 150 megapixels." }
    }
    suspend fun importBytes(word: Word, bytes: ByteArray, prompt: String, hook: String, source: String) = withContext(Dispatchers.IO) { lock.withLock {
        validate(bytes)
        val options=BitmapFactory.Options().apply { inJustDecodeBounds=true }
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
        var sample=1
        while(maxOf(options.outWidth,options.outHeight)/sample>1536) sample*=2
        options.inJustDecodeBounds=false; options.inSampleSize=sample
        var decoded=BitmapFactory.decodeByteArray(bytes,0,bytes.size,options) ?: error("The image could not be decoded.")
        val orientation=runCatching { ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL) }.getOrDefault(1)
        val matrix=Matrix().apply { when(orientation) {
            2 -> setScale(-1f,1f); 3 -> setRotate(180f); 4 -> setScale(1f,-1f)
            5 -> { setRotate(90f); postScale(-1f,1f) }; 6 -> setRotate(90f)
            7 -> { setRotate(270f); postScale(-1f,1f) }; 8 -> setRotate(270f)
        } }
        if(!matrix.isIdentity) { val rotated=Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true); if(rotated!==decoded) decoded.recycle(); decoded=rotated }
        fun scaled(max: Int): Bitmap { val ratio=minOf(1f,max.toFloat()/maxOf(decoded.width,decoded.height)); return Bitmap.createScaledBitmap(decoded,(decoded.width*ratio).toInt().coerceAtLeast(1),(decoded.height*ratio).toInt().coerceAtLeast(1),true) }
        val full=scaled(768); val thumb=scaled(160)
        fun jpeg(bitmap: Bitmap, quality: Int)=ByteArrayOutputStream().use { out -> check(bitmap.compress(Bitmap.CompressFormat.JPEG,quality,out)); out.toByteArray() }
        val fullBytes=jpeg(full,82); val thumbBytes=jpeg(thumb,68)
        val id=UUID.randomUUID().toString(); val folder=File(directory,word.id).apply { mkdirs() }
        val fullFile=File(folder,"$id.jpg"); val thumbFile=File(folder,"$id-thumb.jpg")
        val revision=ArtworkRevision(id,word.id,prompt,hook,"${word.id}/${fullFile.name}","${word.id}/${thumbFile.name}",Instant.now().toString(),source,full.width,full.height,fullBytes.size+thumbBytes.size,true)
        try {
            fullFile.writeBytes(fullBytes); thumbFile.writeBytes(thumbBytes)
            val old=withPrompt(history(word.id),prompt,hook)
            save(word.id,old.copy(images=listOf(revision)+old.images.map { it.copy(active=false) }))
        } catch(e: Exception) { fullFile.delete();thumbFile.delete();throw e }
        finally { listOf(decoded,full,thumb).distinct().forEach { it.recycle() } }
        revision
    } }
    suspend fun export(word: Word): ByteArray = withContext(Dispatchers.IO) {
        val h=history(word.id)
        JSONObject().apply {
            put("format","swedish-cards-artwork-v1");put("wordID",word.id);put("english",word.english);put("swedish",word.swedish);put("sentence",word.sentence)
            put("prompts",JSONArray(h.prompts.map { p -> JSONObject().put("id",p.id).put("text",p.text).put("memoryHook",p.memoryHook).put("createdAt",p.createdAt) }))
            put("images",JSONArray(h.images.map { r -> JSONObject().apply {
                put("id",r.id);put("createdAt",r.createdAt);put("prompt",r.prompt);put("memoryHook",r.memoryHook);put("source",r.source);put("isActive",r.active)
                put("width",r.width);put("height",r.height);put("jpegBase64",Base64.encodeToString(file(r.filename).readBytes(),Base64.NO_WRAP))
            } }))
        }.toString(2).toByteArray()
    }
    suspend fun importPack(uri: Uri, words: List<Word>): Pair<Int,Int> = withContext(Dispatchers.IO) {
        val bytes=context.contentResolver.openInputStream(uri)?.use { readLimited(it,150*1024*1024) } ?: error("The pack could not be opened.")
        importPack(bytes,words)
    }
    suspend fun importPack(bytes: ByteArray, words: List<Word>): Pair<Int,Int> = withContext(Dispatchers.IO) {
        require(bytes.size<=150*1024*1024) { "Choose an artwork pack smaller than 150 MB." }
        val pack=JSONObject(String(bytes));require(pack.optString("format")=="swedish-cards-artwork-pack-v1") { "Choose a prepared artwork pack." }
        val records=pack.getJSONArray("records");require(records.length() in 1..500) { "Packs must contain 1–500 words." }
        val byId=words.associateBy { it.id };val ids=mutableSetOf<String>();val assets=mutableSetOf<String>()
        // Validate every record before changing any active images. Decode one record at a time.
        for(i in 0 until records.length()) {
            val record=records.getJSONObject(i);val id=record.getString("wordID");val asset=record.getString("assetID")
            require(id in byId) { "This pack contains a word outside your vocabulary collection." }
            require(asset.isNotBlank() && ids.add(id) && assets.add(asset)) { "The pack contains duplicate or invalid records." }
            record.getString("prompt");record.getString("memoryHook")
            validate(Base64.decode(record.getString("jpegBase64"),Base64.DEFAULT))
        }
        var imported=0;var skipped=0
        for(i in 0 until records.length()) {
            val r=records.getJSONObject(i);val id=r.getString("wordID");val source="Artwork pack · "+r.getString("assetID")
            if(history(id).images.any { it.source==source }) { skipped++;continue }
            importBytes(byId.getValue(id),Base64.decode(r.getString("jpegBase64"),Base64.DEFAULT),r.getString("prompt"),r.getString("memoryHook"),source);imported++
        }
        imported to skipped
    }
    companion object {
        fun readLimited(input: InputStream, limit: Int): ByteArray {
            val out=ByteArrayOutputStream(); val buffer=ByteArray(8192);var total=0
            while(true) { val count=input.read(buffer);if(count<0) break;total+=count;require(total<=limit) { "The selected file is too large." };out.write(buffer,0,count) }
            return out.toByteArray()
        }
    }
}
