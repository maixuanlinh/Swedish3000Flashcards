package com.linapps.swedish3000

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.linapps.swedish3000.data.RecordedSpeech
import com.linapps.swedish3000.data.recordingKey
import kotlinx.coroutines.*
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

/** Uses only media cache and navigation; never rates cards or removes downloads. */
class HostedMediaSmokeTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    @Test fun swedishHostedImageAndBothRecordedLanguagesWork()=runBlocking {
        val app=compose.activity.application as SwedishApplication
        val words=app.repository.loadWords()
        val word=words.first { w ->
            val item=app.media.catalog.items.getValue("image/${w.image}")
            !app.media.catalog.packs.getValue(item.pack).starter
        }
        val image=app.media.load("image/${word.image}")
        val bitmap=android.graphics.BitmapFactory.decodeByteArray(image,0,image.size)
        assertNotNull(bitmap);bitmap?.recycle()
        assertArrayEquals(image,app.media.cached("image/${word.image}"))
        for ((language,text) in listOf("sv-SE" to word.swedish,"en-US" to word.english,"sv-SE" to word.sentence)) {
            assertTrue(app.media.load(recordingKey(language,text)).isNotEmpty())
            withContext(Dispatchers.Main) {
                val speech=RecordedSpeech(app,app.media)
                try { speech.say(text,language,1f) } finally { speech.close() }
            }
        }
    }
    @Test fun offlineDownloadControlsAreReachable() {
        compose.waitUntil(30000) { compose.onAllNodesWithTag("tab.Settings").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("tab.Settings").performClick()
        compose.waitUntil(30000) { compose.onAllNodesWithTag("settings.offline").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
        compose.onNodeWithTag("offline.download").performScrollTo().assertExists()
        compose.onNodeWithText("Your 211 Free A-set lessons download automatically over Wi-Fi or mobile data. You can pause at any time.").assertExists()
        capturePhone("04-offline-options")
    }
}

internal fun capturePhone(name: String) {
    // Dialog/window animations are outside the Compose test clock.
    android.os.SystemClock.sleep(650)
    val instrumentation=androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
    val folder=java.io.File(instrumentation.targetContext.getExternalFilesDir(null),"swedish-verification").apply { mkdirs() }
    val bitmap=instrumentation.uiAutomation.takeScreenshot() ?: error("Screenshot unavailable")
    java.io.File(folder,"$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it) }
    bitmap.recycle()
}
