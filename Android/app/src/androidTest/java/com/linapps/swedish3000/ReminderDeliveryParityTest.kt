package com.linapps.swedish3000

import android.app.NotificationManager
import androidx.test.platform.app.InstrumentationRegistry
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.junit.*
import org.junit.Assert.*
import java.time.ZonedDateTime

/** Rewrites only the isolated emulator's alarm fixture; never run on a learner's phone. */
class ReminderDeliveryParityTest {
    private val app get()=InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as SwedishApplication
    private val prefs get()=app.getSharedPreferences("word-reminders",0)
    private fun makeNextAlarmDue():Long {
        val generation=prefs.getLong("generation",-1)
        val queue=JSONArray(prefs.getString("queue","[]"));assertTrue(queue.length()>0)
        queue.getJSONObject(0).put("at",System.currentTimeMillis()-1000)
        assertTrue(prefs.edit().putString("queue",queue.toString()).commit());return generation
    }
    @Test fun deliveryReplenishesTheScheduleAndRevokedPremiumCancelsIt()=runBlocking {
        val original=app.reminders.settings
        try {
            assertTrue(app.reminders.save(ReminderSettings(enabled=true,letter="A",sleepEnabled=false,showArtwork=false,frequency=ReminderFrequency.HALF_HOURLY),Entitlement.COMPLETE))
            val generation=makeNextAlarmDue()
            app.reminders.receive(0,generation,Entitlement.COMPLETE)
            assertTrue(app.getSystemService(NotificationManager::class.java).activeNotifications.any {it.id==0})
            assertTrue(prefs.getLong("generation",-1)>generation)
            assertTrue(app.reminders.nextDate!!>System.currentTimeMillis())
            app.reminders.refresh(Entitlement.FREE,force=true)
            assertNull(app.reminders.nextDate)
            assertTrue(app.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
        } finally {app.reminders.save(original.copy(enabled=false),Entitlement.COMPLETE)}
    }
    @Test fun anAlarmDelayedIntoSleepIsDroppedAndTheNextAwakeSlotIsScheduled()=runBlocking {
        val original=app.reminders.settings
        try {
            app.reminders.save(original.copy(enabled=false),Entitlement.COMPLETE)
            val now=ZonedDateTime.now();val minute=now.hour*60+now.minute
            val settings=ReminderSettings(enabled=true,letter="A",showArtwork=false,frequency=ReminderFrequency.HALF_HOURLY,sleepStart=(minute+1439)%1440,sleepEnd=(minute+2)%1440)
            assertFalse(settings.awake(minute));assertTrue(app.reminders.save(settings,Entitlement.COMPLETE))
            val generation=makeNextAlarmDue();app.reminders.receive(0,generation,Entitlement.COMPLETE)
            assertTrue(app.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
            assertTrue(prefs.getLong("generation",-1)>generation);assertNotNull(app.reminders.nextDate)
        } finally {app.reminders.save(original.copy(enabled=false),Entitlement.COMPLETE)}
    }
}
