package com.linapps.swedish3000

import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.runBlocking
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class ParityScreenTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private fun loaded() {
        compose.activityRule.scenario.onActivity { it.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
        compose.waitUntil(30000) { runCatching { compose.onAllNodesWithTag("study.filters").fetchSemanticsNodes().isNotEmpty() }.getOrDefault(false) }
    }
    private fun aSet() {
        loaded();compose.onNodeWithTag("study.filters").performClick()
        compose.onNodeWithTag("filter.scope.all").performScrollTo().performClick()
        compose.onNodeWithTag("letter.A").performScrollTo().performClick()
        compose.onNodeWithTag("filter.apply").performClick()
        compose.onNodeWithTag("card.prompt",useUnmergedTree=true).assertExists()
    }
    private fun screenshot(name: String) {
        compose.waitForIdle()
        // Android window/rotation animations run outside Compose's test clock.
        android.os.SystemClock.sleep(600)
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val folder=File(instrumentation.targetContext.getExternalFilesDir(null),"parity-build29").apply { mkdirs() }
        val bitmap=instrumentation.uiAutomation.takeScreenshot() ?: error("Screenshot unavailable")
        File(folder,"$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) };bitmap.recycle()
    }
    @Test fun studyRevealAndWordDetailMatchIOSContent() {
        aSet();screenshot("01-study-prompt")
        compose.onNodeWithTag("card.reveal").performClick()
        compose.onNodeWithTag("card.answer").assertExists()
        compose.onNodeWithTag("card.sentence").assertExists()
        compose.onNodeWithTag("card.translation").assertExists();screenshot("02-study-answer")
        compose.onNodeWithTag("card.detail").performClick()
        compose.onNodeWithTag("detail.swedish").assertExists();screenshot("03-word-detail")
        compose.onNodeWithTag("detail.image").performScrollTo().performClick();screenshot("04-illustration")
        compose.onAllNodesWithText("Done").onLast().performClick()
        compose.onNodeWithTag("detail.sentence").performScrollTo().assertExists()
        compose.onNodeWithTag("detail.translation").performScrollTo().assertExists()
    }
    @Test fun librarySearchDoesNotReplaceStudySessionAndPractiseUsesSelection() {
        aSet();compose.onNodeWithTag("tab.Words").performClick()
        compose.onNodeWithTag("words.search").performTextInput("ett äpple")
        compose.onNodeWithTag("words.filteredCount").assertTextEquals("1 shown");screenshot("05-library-search")
        compose.onNodeWithTag("words.practice").performClick()
        compose.onNodeWithTag("card.prompt",useUnmergedTree=true).assertTextEquals("apple")
        compose.onNodeWithTag("card.reveal").performClick();compose.onNodeWithTag("card.answer").assertTextEquals("ett äpple")
    }
    @Test fun swipeAndUndoPreserveStoredLearningProgress() {
        aSet()
        val app=compose.activity.application as SwedishApplication
        val word=runBlocking { app.repository.loadWords().first() }
        val prior=runBlocking { app.repository.ratings()[word.id] ?: Rating() }
        val before=runBlocking { app.repository.events() }
        try {
            compose.onNodeWithTag("study.card").performTouchInput { swipeRight() }
            compose.waitUntil(10000) { runBlocking { app.repository.events().size>before.size } }
            assertEquals(LearningStatus.KNOWN,runBlocking { app.repository.ratings()[word.id]?.status })
            compose.onNodeWithTag("review.undo").performClick()
            compose.waitUntil(10000) { runBlocking { app.repository.events().size==before.size } }
            assertEquals(prior,runBlocking { app.repository.ratings()[word.id] })
            compose.onNodeWithTag("card.prompt",useUnmergedTree=true).assertTextEquals(word.english)
        } finally {
            val latest=runBlocking { app.repository.events().lastOrNull { it.wordId==word.id } }
            if(latest!=null && latest.id !in before.map { it.id }) runBlocking { app.repository.undo(UndoRating(word.id,prior,latest)) }
        }
    }
    @Test fun progressRemindersHelpAndArtworkEditorAreReachable() {
        aSet();compose.onNodeWithTag("tab.Progress").performClick();screenshot("06-progress")
        compose.onNodeWithTag("progress.reminders").performScrollTo().performClick()
        compose.onNodeWithText("WORD SELECTION").performScrollTo().assertExists();screenshot("07-reminder-settings")
        compose.onAllNodesWithText("Done").onLast().performClick()
        compose.onNodeWithTag("progress.support").performScrollTo().performClick()
        compose.onNodeWithText("Privacy policy").assertExists();screenshot("08-help")
        compose.onAllNodesWithText("Done").onLast().performClick()
        compose.onNodeWithTag("tab.Study").performClick();compose.onNodeWithTag("card.reveal").performClick();compose.onNodeWithTag("card.detail").performClick()
        compose.onNodeWithText("Artwork",useUnmergedTree=true).performClick()
        compose.onNodeWithTag("artwork.prompt").assertExists();screenshot("09-artwork-editor")
    }
    @Test fun silentPlaybackCompletesWithoutRatingsAndSurvivesRotation() {
        aSet()
        val app=compose.activity.application as SwedishApplication
        val preferences=app.preferences.playback
        val before=runBlocking { app.repository.events() }
        try {
            compose.onNodeWithTag("tab.Words").performClick();compose.onNodeWithTag("words.search").performTextInput("ett äpple");compose.onNodeWithTag("words.practice").performClick()
            compose.onNodeWithTag("study.options").performClick();compose.onNodeWithText("Playback settings").performClick()
            repeat(2) { compose.onNodeWithTag("Recall pause.minus").performScrollTo().performClick() }
            compose.onNodeWithTag("Pause after audio.minus").performScrollTo().performClick()
            listOf("Read the prompt","Read the answer","Read the Swedish sentence").forEach { label -> compose.onNodeWithTag("toggle.$label").performScrollTo().performClick() }
            compose.onNodeWithText("Start automatic study").performClick()
            compose.waitUntil(15000) { compose.onAllNodesWithContentDescription("Replay automatic study").fetchSemanticsNodes().isNotEmpty() }
            screenshot("10-playback-complete")
            assertEquals(before,runBlocking { app.repository.events() })
            compose.onNodeWithContentDescription("Return to manual study").performClick()
            compose.onNodeWithTag("card.prompt",useUnmergedTree=true).assertTextEquals("apple")
            compose.activity.requestedOrientation=android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            compose.waitForIdle();compose.onNodeWithTag("card.prompt",useUnmergedTree=true).assertTextEquals("apple");screenshot("11-landscape")
        } finally { app.preferences.playback=preferences;compose.activity.requestedOrientation=android.content.pm.ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED }
    }

}
