package com.linapps.swedish3000

import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.linapps.swedish3000.domain.PlaybackSettings
import com.linapps.swedish3000.ui.PlaybackState
import com.linapps.swedish3000.ui.StudyViewModel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.linapps.swedish3000.data.RecordedSpeech
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File

/** Run in the disposable media-preview emulator, never on a personal phone. */
@RunWith(AndroidJUnit4::class)
class OfflineMediaScreenTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    @Test fun hostedLessonDownloadsAndPlaysWithoutAnAndroidVoice()=runBlocking {
        Assume.assumeTrue(BuildConfig.MEDIA_BASE_URL.isNotEmpty())
        val app=compose.activity.application as SwedishApplication
        val word=app.repository.loadWords().first { word ->
            val item=app.media.catalog.items["image/${word.image}"]
            item!=null && !app.media.catalog.packs.getValue(item.pack).starter
        }
        val key="image/${word.image}"
        val bytes=app.media.load(key)
        val image=android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.size)
        assertNotNull(image);image?.recycle()
        assertArrayEquals(bytes,app.media.cached(key))
        withContext(Dispatchers.Main) {
            val speech=RecordedSpeech(app,app.media)
            try { speech.say(word.swedish,"sv-SE",1f) } finally { speech.close() }
        }
    }
    @Test fun recordedAutomaticStudyCompletesAndOfflineStorageControlsAreReachable() {
        lateinit var vm: StudyViewModel
        compose.activityRule.scenario.onActivity {
            it.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            vm=ViewModelProvider(it)[StudyViewModel::class.java]
        }
        compose.waitUntil(30_000) { !vm.uiState.value.loading }
        val app=compose.activity.application as SwedishApplication
        val settings=app.preferences.playback
        val events=runBlocking { app.repository.events() }
        val ratings=runBlocking { app.repository.ratings() }
        try {
            compose.activityRule.scenario.onActivity {
                vm.openReminder("sv-0136",true)
                vm.settings(PlaybackSettings(recallSeconds=1,answerSeconds=1))
            }
            compose.waitForIdle()
            assertEquals("apple",vm.uiState.value.current?.english)
            assertEquals(listOf("sv-0136"),vm.uiState.value.queue)
            compose.onNodeWithTag("study.autoplay").performClick()
            compose.waitUntil(60_000) { vm.uiState.value.playback!=PlaybackState.PLAYING }
            assertEquals(vm.uiState.value.message,PlaybackState.FINISHED,vm.uiState.value.playback)
            assertEquals(1,vm.uiState.value.completed.size)
            assertEquals(events,runBlocking { app.repository.events() })
            assertEquals(ratings,runBlocking { app.repository.ratings() })
            compose.onNodeWithTag("tab.Settings").performClick()
            compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
            compose.onNodeWithText("Offline study").assertExists()
            compose.onNodeWithTag("offline.total").assertExists()
            compose.onNodeWithText("Download images and audio to study without an internet connection. Downloads are optional and occupy storage space on your phone.").assertExists()
            val instrumentation=InstrumentationRegistry.getInstrumentation()
            val screenshot=instrumentation.uiAutomation.takeScreenshot()
            val folder=File(instrumentation.targetContext.getExternalFilesDir(null),"media-preview").apply { mkdirs() }
            screenshot?.let { image -> File(folder,"offline-study.png").outputStream().use { image.compress(Bitmap.CompressFormat.PNG,100,it) };image.recycle() }
        } finally {
            compose.activityRule.scenario.onActivity { vm.stop();vm.settings(settings) }
        }
    }
}
