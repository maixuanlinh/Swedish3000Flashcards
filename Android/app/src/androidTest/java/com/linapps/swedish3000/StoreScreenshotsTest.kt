package com.linapps.swedish3000

import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.ui.*
import kotlinx.coroutines.runBlocking
import org.junit.*
import java.io.File

/** Genuine screenshots on the isolated store-capture emulator. Never run on a learner's phone. */
class StoreScreenshotsTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private lateinit var vm:StudyViewModel
    private val app get()=compose.activity.application as SwedishApplication
    private fun loaded() {
        compose.activityRule.scenario.onActivity {vm=ViewModelProvider(it)[StudyViewModel::class.java];it.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)}
        compose.waitUntil(30000) {!vm.uiState.value.loading && vm.uiState.value.access!=Entitlement.UNKNOWN}
        shell("settings put global sysui_demo_allowed 1")
        listOf("enter","clock --es hhmm 0941","battery --es level 100 --es plugged false","network --es wifi show --es level 4 --es mobile show --es datatype lte --es fully true","notifications --es visible false").forEach {shell("am broadcast -a com.android.systemui.demo --es command $it")}
    }
    private fun shell(command:String) {android.os.ParcelFileDescriptor.AutoCloseInputStream(InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command)).use {it.readBytes()}}
    @After fun resetStatusBar() {shell("am broadcast -a com.android.systemui.demo --es command exit");shell("settings put global sysui_demo_allowed 0")}
    private fun capture(name:String) {
        compose.waitForIdle();android.os.SystemClock.sleep(700)
        val i=InstrumentationRegistry.getInstrumentation();val bitmap=i.uiAutomation.takeScreenshot() ?: error("No screenshot")
        check(bitmap.width==1080 && bitmap.height==1920) {"Use the 1080 x 1920 store capture configuration"}
        val folder=File(i.targetContext.getExternalFilesDir(null),"play-store-1.1.0").apply {mkdirs()}
        File(folder,"$name.jpg").outputStream().use {bitmap.compress(Bitmap.CompressFormat.JPEG,97,it)};bitmap.recycle()
    }
    @Test fun freeScreensMatchTheReleaseUI() {
        loaded();check(vm.uiState.value.access==Entitlement.FREE)
        val saved=app.preferences.session;val undo=mutableListOf<UndoRating>()
        try {
            val apple=vm.uiState.value.words.first {it.english=="apple"}
            runBlocking {app.media.load("image/${apple.image}");app.offline.pause()}
            compose.runOnIdle {vm.openReminder(apple.id,true);vm.flip()}
            compose.onNodeWithTag("card.answer").assertExists();capture("01-study-answer")
            compose.onNodeWithTag("tab.Words").performClick();compose.runOnIdle {vm.browseTopics()}
            compose.onNodeWithTag("topic.home").assertExists();capture("02-topic-library")
            compose.onNodeWithTag("words.filters").performScrollTo().performClick()
            compose.onNodeWithTag("filter.topic.home").performScrollTo().performClick();capture("03-inline-topic-filters")
            compose.onNodeWithText("Cancel").performClick()
            compose.onNodeWithTag("words.coreGroups").performScrollTo().performClick()
            compose.onNodeWithTag("topic.commonVerbs").assertExists();capture("04-word-groups")
            runBlocking {vm.uiState.value.words.filter {it.initial=="A"}.drop(1).take(5).forEach {undo+=app.repository.rate(it.id,LearningStatus.LEARNING)}}
            compose.runOnIdle {vm.load()};compose.waitUntil(30000) {!vm.uiState.value.loading}
            compose.onNodeWithTag("tab.Progress").performClick();capture("05-progress-learning")
            compose.onNodeWithTag("tab.Settings").performClick();compose.onNodeWithTag("settings.membership",useUnmergedTree=true).assertTextEquals("3000 Swedish Words Free");capture("06-settings")
            compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
            compose.onNodeWithTag("offline.total").assertTextContains("Free A-set lessons",substring=true);capture("07-offline-free-lessons")
        } finally {
            runBlocking {undo.asReversed().forEach {app.repository.undo(it)}}
            app.preferences.session=saved
        }
    }
    @Test fun premiumReminderScreenMatchesTheReleaseUI() {
        loaded();org.junit.Assume.assumeTrue(vm.uiState.value.access==Entitlement.COMPLETE)
        if(compose.onAllNodesWithTag("offlinePrompt.later").fetchSemanticsNodes().isNotEmpty()) compose.onNodeWithTag("offlinePrompt.later").performClick()
        compose.onNodeWithTag("tab.Settings").performClick();compose.onNodeWithTag("settings.reminders").performScrollTo().performClick()
        compose.onNodeWithTag("reminders.frequency").performScrollTo().performClick();compose.onAllNodesWithText("Every 30 minutes").onLast().performScrollTo().performClick()
        compose.onNodeWithTag("reminders.sleepEnd").performScrollTo().assertExists();capture("08-premium-reminders")
    }
}
