package com.linapps.swedish3000

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.ArtworkRepository
import kotlinx.coroutines.test.runTest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import android.util.Base64

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],application=android.app.Application::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ArtworkRepositoryTest {
    private lateinit var context: Context
    @Before fun setup() { context=ApplicationProvider.getApplicationContext();File(context.filesDir,"artwork").deleteRecursively() }
    private fun image()=context.assets.open("BundledArtwork/"+runTestImage()).use { it.readBytes() }
    private fun runTestImage(): String {
        val manifest=JSONArray(context.assets.open("BundledArtwork/manifest.json").bufferedReader().use { it.readText() })
        return manifest.getJSONObject(0).getString("filename")
    }
    @Test fun imageHistorySurvivesRelaunchAndOriginalKeepsRevisions()=runTest {
        val repo=ArtworkRepository(context);val word=word()
        val revision=repo.importBytes(word,image(),"My prompt","My hook","Files")
        assertTrue(revision.width<=768 && revision.height<=768)
        val fresh=ArtworkRepository(context)
        assertEquals(revision.id,fresh.active(word.id)?.id)
        assertEquals("My hook",fresh.active(word.id)?.memoryHook)
        fresh.activate(word.id,null)
        assertNull(fresh.active(word.id));assertEquals(1,fresh.history(word.id).images.size)
        fresh.activate(word.id,revision.id);assertEquals(revision.id,fresh.active(word.id)?.id)
        val exported=JSONObject(String(fresh.export(word)))
        assertEquals("swedish-cards-artwork-v1",exported.getString("format"))
        assertTrue(exported.getJSONArray("images").getJSONObject(0).getBoolean("isActive"))
    }
    @Test fun invalidImagePreservesActiveAndPromptsAreDeduplicated()=runTest {
        val repo=ArtworkRepository(context);val word=word()
        val revision=repo.importBytes(word,image(),"Prompt","Hook","Files")
        try { repo.importBytes(word,byteArrayOf(1,2,3),"Bad","Bad","Files");fail("Expected invalid image") } catch(_: IllegalArgumentException) {}
        assertEquals(revision.id,repo.active(word.id)?.id)
        repo.savePrompt(word.id,"Prompt","Hook");assertEquals(1,repo.history(word.id).prompts.size)
        repo.savePrompt(word.id,"Changed","Hook");assertEquals(2,repo.history(word.id).prompts.size)
    }
    @Test fun compatiblePackIsIdempotentAndRejectsUnknownWordsBeforeChangingImages()=runTest {
        val repo=ArtworkRepository(context);val word=word();val encoded=Base64.encodeToString(image(),Base64.NO_WRAP)
        fun record(id: String,asset: String)=JSONObject().put("wordID",id).put("assetID",asset).put("prompt","Pack prompt").put("memoryHook","Pack hook").put("jpegBase64",encoded)
        fun pack(records: List<JSONObject>)=JSONObject().put("format","swedish-cards-artwork-pack-v1").put("records",JSONArray(records)).toString().toByteArray()
        val bytes=pack(listOf(record(word.id,"asset-one")))
        assertEquals(1 to 0,repo.importPack(bytes,listOf(word)))
        assertEquals(0 to 1,repo.importPack(bytes,listOf(word)))
        val active=repo.active(word.id)?.id
        try { repo.importPack(pack(listOf(record(word.id,"asset-two"),record("unknown","asset-three"))),listOf(word));fail("Expected unknown word rejection") } catch(_: IllegalArgumentException) {}
        assertEquals(active,repo.active(word.id)?.id);assertEquals(1,repo.history(word.id).images.size)
    }
}
