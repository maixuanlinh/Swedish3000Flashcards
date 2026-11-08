package com.linapps.swedish3000

import android.app.Activity
import android.app.NotificationManager
import android.os.Build
import android.os.SystemClock
import androidx.lifecycle.ViewModelProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.ui.StudyViewModel
import kotlinx.coroutines.runBlocking
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith

/** Cold notification launch has its own lifecycle, independent of ActivityScenario's fixture. */
@RunWith(AndroidJUnit4::class)
class NotificationParityTest {
    @Test fun coldAndWarmNotificationLaunchKeepExactWordDirectionAndProgress() {
        Assume.assumeTrue(Build.MODEL.contains("sdk") || Build.MODEL.contains("Emulator"))
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val app=instrumentation.targetContext.applicationContext as SwedishApplication
        if(Build.VERSION.SDK_INT>=33) instrumentation.uiAutomation.grantRuntimePermission(app.packageName,android.Manifest.permission.POST_NOTIFICATIONS)
        val original=app.reminders.settings
        val events=runBlocking { app.repository.events() }
        val direction=app.preferences.englishFirst
        var opened: Activity?=null
        fun tap(notification: android.app.Notification) {
            // A real tap is sent by SystemUI. The background test process must emulate
            // that authorized sender; ordinary app-initiated background launches are blocked.
            instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.START_ACTIVITIES_FROM_BACKGROUND")
            try {
                val options=android.app.ActivityOptions.makeBasic()
                if(Build.VERSION.SDK_INT>=34) options.setPendingIntentBackgroundActivityStartMode(android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                notification.contentIntent.send(app,0,null,null,null,null,options.toBundle())
            } finally { instrumentation.uiAutomation.dropShellPermissionIdentity() }
        }
        try {
            val settings=ReminderSettings(enabled=true,letter="A",prompt=ReminderPrompt.ENGLISH)
            assertTrue(runBlocking { app.reminders.save(settings,Entitlement.COMPLETE) })
            assertNotNull(app.reminders.nextDate)
            runBlocking { app.reminders.sample(settings,Entitlement.COMPLETE) }
            val manager=app.getSystemService(NotificationManager::class.java)
            val sample=manager.activeNotifications.single { it.id==1000 }
            assertEquals("Can you say it in Swedish?",sample.notification.extras.getString(android.app.Notification.EXTRA_TITLE))
            tap(sample.notification)
            var resumed: MainActivity?=null
            val deadline=SystemClock.elapsedRealtime()+10000
            while(resumed==null && SystemClock.elapsedRealtime()<deadline) {
                instrumentation.runOnMainSync { resumed=ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED).filterIsInstance<MainActivity>().firstOrNull() }
                if(resumed==null) SystemClock.sleep(50)
            }
            val activity=resumed ?: error("Notification did not open the app")
            opened=activity
            lateinit var vm: StudyViewModel
            instrumentation.runOnMainSync { vm=ViewModelProvider(activity)[StudyViewModel::class.java] }
            fun awaitCard(englishFirst: Boolean) {
                val deadline=SystemClock.elapsedRealtime()+10000
                while(SystemClock.elapsedRealtime()<deadline && (vm.uiState.value.loading || vm.uiState.value.current?.english!="apple" || vm.uiState.value.showsEnglishFirst!=englishFirst)) SystemClock.sleep(50)
                val state=vm.uiState.value
                assertFalse(state.loading);assertEquals("apple",state.current?.english)
                assertEquals(englishFirst,state.showsEnglishFirst);assertEquals(0,state.tab)
            }
            awaitCard(true)
            runBlocking { app.reminders.sample(settings.copy(prompt=ReminderPrompt.SWEDISH),Entitlement.COMPLETE) }
            tap(manager.activeNotifications.single { it.id==1000 }.notification)
            awaitCard(false)
            instrumentation.runOnMainSync {
                assertEquals(1,ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED).count { it is MainActivity })
            }
            assertEquals(events,runBlocking { app.repository.events() })
            assertEquals(direction,app.preferences.englishFirst)
        } finally {
            runBlocking { app.reminders.save(original,Entitlement.COMPLETE) }
            instrumentation.runOnMainSync { opened?.finish() }
        }
    }
}
