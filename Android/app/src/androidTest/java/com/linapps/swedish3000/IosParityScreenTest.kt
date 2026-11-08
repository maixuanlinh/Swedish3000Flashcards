package com.linapps.swedish3000

import android.app.NotificationManager
import android.graphics.Bitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.ui.*
import kotlinx.coroutines.runBlocking
import org.junit.*
import org.junit.Assert.*
import org.junit.runners.MethodSorters
import org.junit.runner.RunWith
import java.io.File

internal fun captureParity(name:String) {
    val i=InstrumentationRegistry.getInstrumentation()
    val folder=File(i.targetContext.getExternalFilesDir(null),"ios-parity-1.1.0").apply {mkdirs()}
    android.os.SystemClock.sleep(300)
    val image=i.uiAutomation.takeScreenshot() ?: error("Screenshot unavailable")
    File(folder,"$name.png").outputStream().use {image.compress(Bitmap.CompressFormat.PNG,100,it)};image.recycle()
}
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class IosParityScreenTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private lateinit var vm:StudyViewModel
    private val app get()=compose.activity.application as SwedishApplication
    private fun loaded() {
        compose.activityRule.scenario.onActivity {vm=ViewModelProvider(it)[StudyViewModel::class.java];it.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)}
        compose.waitUntil(30000) {!vm.uiState.value.loading && vm.uiState.value.access!=Entitlement.UNKNOWN}
        compose.onNodeWithTag("tab.Settings").assertExists()
    }
    @Test fun a_freeDownloadDoesNotBlockStudyAndCannotStartPaidDownloads() {
        loaded();assertEquals(Entitlement.FREE,vm.uiState.value.access)
        compose.onNodeWithTag("review.learning").assertDoesNotExist();compose.onNodeWithTag("review.known").assertDoesNotExist()
        compose.onNodeWithTag("card.flip").performClick();compose.onNodeWithTag("card.translation").assertExists()
        captureParity("01-free-study")
        runBlocking {
            app.offline.ensureInitialized()
            try {app.offline.start(false,false);fail("Free must not download full packs")} catch(_:IllegalStateException) {}
            try {app.reminders.save(ReminderSettings(enabled=true),Entitlement.FREE);fail("Free reminders must be locked")} catch(_:IllegalStateException) {}
            app.offline.pause()
        }
        assertFalse(app.offline.status.value.wifiOnly)
    }
    @Test fun b_topicsAndCoreGroupsMatchTheFinishedIOS() {
        loaded();compose.onNodeWithTag("tab.Words").performClick()
        compose.runOnIdle {vm.browseTopics()}
        compose.onNodeWithTag("topic.home").assertExists();captureParity("02-topic-library")
        compose.onNodeWithTag("words.coreGroups").performClick()
        compose.onNodeWithTag("topic.commonVerbs").assertExists();captureParity("03-core-groups")
        compose.onNodeWithTag("topic.commonVerbs").performClick()
        compose.onNodeWithTag("words.filteredCount").performScrollTo().assertTextEquals("247 shown")
        compose.onNodeWithTag("words.search").performScrollTo().performTextInput("eat")
        val matching=vm.uiState.value.matches.map {it.id}
        assertTrue(matching.any {vm.uiState.value.byId[it]?.english=="eat"})
        compose.onNodeWithTag("words.practice").performClick()
        assertTrue(vm.uiState.value.current!!.id in matching)
        assertEquals(matching.size,vm.uiState.value.initialCount)
    }
    @Test fun c_learningListAndExactSessionAreSaved() {
        loaded();compose.runOnIdle {vm.studyAll()}
        val first=vm.uiState.value.current!!.id
        compose.onNodeWithTag("study.card").performTouchInput {swipeLeft()}
        compose.waitUntil(10000) {vm.uiState.value.ratings[first]?.status==LearningStatus.LEARNING && !vm.uiState.value.busy}
        val next=vm.uiState.value.current!!.id
        assertEquals(next,LocalPreferences(app).session!!.ids.first())
        compose.onNodeWithTag("tab.Progress").performClick()
        compose.onNodeWithText("Currently learning").assertExists()
        compose.onNodeWithTag("progress.resume").assertExists();captureParity("04-progress-learning")
        compose.onNodeWithTag("progress.resume").performClick()
        assertEquals(next,vm.uiState.value.current!!.id)
        compose.activityRule.scenario.recreate()
        loaded();assertEquals(next,vm.uiState.value.current!!.id)
    }
    @Test fun d_footerFiltersAndPlaybackMatchIOS() {
        loaded();compose.runOnIdle {vm.previewA();vm.settings(PlaybackSettings(1,1,false,false,false))}
        compose.onNodeWithTag("study.toolbar").assertExists()
        compose.onNodeWithTag("study.options").performClick()
        compose.onNodeWithTag("study.option.playback").assertDoesNotExist()
        compose.onNodeWithTag("study.option.shuffle").assertExists();compose.onNodeWithTag("study.option.direction").assertExists()
        compose.onNodeWithTag("study.option.shuffle").performClick()
        compose.onNodeWithTag("study.filters").performClick()
        assertTrue(compose.onNodeWithText("TOPIC").getUnclippedBoundsInRoot().top < compose.onNodeWithText("ENGLISH STARTS WITH").getUnclippedBoundsInRoot().top)
        compose.onNodeWithText("Cancel").performClick()
        compose.onNodeWithTag("card.flip").performClick();compose.onNodeWithTag("card.translation").assertExists()
        compose.onNodeWithTag("study.autoplay").performClick()
        compose.onNodeWithTag("playback.next").assertExists();compose.onNodeWithTag("study.autoplay").performClick()
        captureParity("05-study-playback")
        compose.onNodeWithTag("study.playbackSettings").performClick()
        compose.onNodeWithTag("playback.stop").performClick()
        compose.onNodeWithTag("playback.next").assertDoesNotExist()
    }
    @Test fun e_settingsSeparateProgressAndLockFreeReminders() {
        loaded();compose.onNodeWithTag("tab.Settings").performClick()
        compose.onNodeWithTag("settings.membership",useUnmergedTree=true).assertTextEquals("3000 Swedish Words Free")
        compose.onNodeWithTag("settings.reminders").performScrollTo().performClick()
        compose.onNodeWithTag("reminders.save").assertDoesNotExist()
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
        compose.onNodeWithTag("offline.total").assertTextContains("Free A-set lessons",substring=true);captureParity("06-free-offline")
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithTag("settings.website").performScrollTo().assertExists()
        compose.onNodeWithTag("settings.report").performScrollTo().assertExists();captureParity("07-settings-support")
        compose.onNodeWithTag("settings.privacy").performScrollTo().assertExists()
    }
}
@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class PremiumParityScreenTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private lateinit var vm:StudyViewModel
    private val app get()=compose.activity.application as SwedishApplication
    private fun loaded() {
        compose.activityRule.scenario.onActivity {vm=ViewModelProvider(it)[StudyViewModel::class.java]}
        compose.waitUntil(30000) {!vm.uiState.value.loading && vm.uiState.value.access==Entitlement.COMPLETE}
    }
    @Test fun a_englishPremiumChoiceRemembersLater() {
        loaded();compose.waitUntil(15000) {compose.onAllNodesWithTag("offlinePrompt.later").fetchSemanticsNodes().isNotEmpty()}
        compose.onNodeWithText("Learn anywhere, even offline").assertExists()
        compose.onNodeWithTag("offlinePrompt.wifi").assertExists();compose.onNodeWithTag("offlinePrompt.now").assertExists()
        captureParity("08-premium-download-choice")
        compose.onNodeWithTag("offlinePrompt.later").performClick()
        compose.onNodeWithTag("offlinePrompt.later").assertDoesNotExist()
        assertTrue(app.getSharedPreferences("offline-lessons",0).getBoolean("premiumPromptHandled",false))
        compose.activityRule.scenario.recreate();loaded()
        compose.onNodeWithTag("offlinePrompt.later").assertDoesNotExist()
    }
    @Test fun b_premiumHalfHourlySleepScheduleSavesAndReplenishes() {
        loaded();runBlocking {app.reminders.save(ReminderSettings(),Entitlement.COMPLETE)};compose.onNodeWithTag("tab.Settings").performClick()
        compose.onNodeWithTag("settings.reminders").performScrollTo().performClick()
        compose.onNodeWithTag("reminders.frequency").performScrollTo().performClick()
        compose.onAllNodesWithText("Every 30 minutes").onLast().performClick()
        compose.onNodeWithTag("reminders.dailyCount").assertTextEquals("28 reminders per day · repeats daily")
        compose.onNodeWithTag("reminders.sleepStart").performScrollTo().assertExists();captureParity("09-reminder-sleep-hours")
        compose.onNodeWithTag("toggle.Word reminders").performScrollTo().performClick()
        compose.onNodeWithTag("reminders.save").performClick()
        compose.waitUntil(15000) {app.reminders.settings.enabled && app.reminders.nextDate!=null}
        assertEquals(28,app.reminders.settings.dailyMinutes.size);assertNotNull(app.reminders.nextDate)
        runBlocking {app.reminders.sample(app.reminders.settings,Entitlement.COMPLETE)}
        val notifications=app.getSystemService(NotificationManager::class.java).activeNotifications
        assertTrue(notifications.isNotEmpty())
        runBlocking {app.reminders.save(app.reminders.settings.copy(enabled=false),Entitlement.COMPLETE)}
    }
    @Test fun c_everyReleasedIOSFrequencyCanBeSelected() {
        loaded();runBlocking {app.reminders.save(ReminderSettings(),Entitlement.COMPLETE)}
        compose.onNodeWithTag("tab.Settings").performClick();compose.onNodeWithTag("settings.reminders").performScrollTo().performClick()
        listOf("Every 3 hours" to 5,"Every 4 hours" to 4,"Once a day" to 1,"Twice a day" to 2,"Four times a day" to 4).forEach {(label,count) ->
            compose.onNodeWithTag("reminders.frequency").performScrollTo().performClick()
            compose.onAllNodesWithText(label).onLast().performScrollTo().performClick()
            compose.onNodeWithTag("reminders.dailyCount").assertTextEquals("$count reminders per day · repeats daily")
        }
        captureParity("11-all-reminder-frequencies")
    }

    @Test fun d_premiumOfflineSizeAndWifiPreferenceFollowIOS() {
        loaded();compose.onNodeWithTag("tab.Settings").performClick()
        compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
        compose.onNodeWithTag("offline.total").assertTextContains("Complete collection",substring=true)
        val before=app.offline.wifiOnlyPreference
        compose.onNodeWithTag("toggle.Download over Wi-Fi only").performScrollTo().performClick()
        assertEquals(!before,app.offline.wifiOnlyPreference)
        compose.onNodeWithText("Done").performClick()
        compose.onNodeWithTag("settings.offline").performScrollTo().performClick()
        if(before) compose.onNodeWithTag("toggle.Download over Wi-Fi only").assertIsOff() else compose.onNodeWithTag("toggle.Download over Wi-Fi only").assertIsOn()
        captureParity("12-premium-offline-preference")
        app.offline.wifiOnlyPreference=before
    }

}
