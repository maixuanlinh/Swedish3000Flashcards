package com.linapps.swedish3000

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.test.runTest
import org.json.*
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],application=Application::class)
class FreeOfflinePersistenceTest {
    @Test fun exactFreeRangesSurviveNewMediaRepositoryWithoutInternet()=runTest {
        val context:Context=ApplicationProvider.getApplicationContext()
        File(context.filesDir,"lesson-media").deleteRecursively();File(context.cacheDir,"lesson-media").deleteRecursively()
        val a=word().copy(thumbnail="a.jpg");val b=word("bicycle","paid").copy(image="b.jpg",thumbnail="b.jpg")
        val keys=listOf("image/a.jpg",recordingKey("en-US",a.english),recordingKey("sv-SE",a.swedish),recordingKey("sv-SE",a.sentence),"image/b.jpg")
        val values=keys.mapIndexed {index,key -> "$index:$key".toByteArray()};val pack=values.fold(byteArrayOf()) {all,value -> all+value}
        val hash=mediaHash(pack);val file="pack-$hash.bin"
        val assets=JSONArray();var offset=0
        keys.zip(values).forEach { (key,value) -> assets.put(JSONObject().put("key",key).put("pack",file).put("offset",offset).put("bytes",value.size).put("sha256",mediaHash(value)));offset+=value.size }
        fun manifest()=JSONObject().put("format","sisu-lesson-media-v1").put("version","a".repeat(64))
            .put("packs",JSONArray().put(JSONObject().put("file",file).put("bytes",pack.size).put("sha256",hash).put("starter",false))).put("assets",assets)
        val requests=mutableListOf<Pair<Long,Long?>>()
        val source=MediaSource {_,start,end -> requests+=start to end;check(end!=null);MediaResponse(206,"bytes $start-$end/${pack.size}",ByteArrayInputStream(pack.copyOfRange(start.toInt(),end.toInt()+1)))}
        val media=LessonMedia(context,::manifest,source);media.configurePreview(listOf(a,b))
        for(key in media.previewKeys) media.downloadPreview(key)
        assertEquals(4,requests.size)
        assertTrue(requests.all {it.first<pack.size-values.last().size})
        assertFalse(File(context.filesDir,"lesson-media/$file").exists())
        assertTrue(media.previewStatus.value.ready);assertFalse(media.status.value.ready)
        val offline=LessonMedia(context,::manifest,MediaSource {_,_,_ -> throw IOException("Offline")})
        offline.configurePreview(listOf(a,b));assertTrue(offline.previewStatus.value.ready)
        keys.take(4).forEachIndexed {index,key -> assertArrayEquals(values[index],offline.load(key))}
        try {offline.downloadPreview("image/b.jpg");fail("Paid image must stay outside Free downloads")} catch(_:IllegalArgumentException) {}
    }
}
