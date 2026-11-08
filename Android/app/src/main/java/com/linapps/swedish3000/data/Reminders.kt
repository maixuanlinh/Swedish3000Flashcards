package com.linapps.swedish3000.data

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.linapps.swedish3000.MainActivity
import com.linapps.swedish3000.R
import com.linapps.swedish3000.SwedishApplication
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

class Reminders(private val context: Context, private val repository: StudyRepository, private val artwork: ArtworkRepository,private val media: LessonMedia) {
    private val prefs=context.getSharedPreferences("word-reminders",Context.MODE_PRIVATE)
    private val alarm=context.getSystemService(AlarmManager::class.java)
    private val notifications=NotificationManagerCompat.from(context)
    private val lock=Mutex()
    var settings: ReminderSettings
        get()=runCatching { JSONObject(prefs.getString("settings","{}")!!).let { j ->
            val times=j.optJSONArray("times")
            ReminderSettings(j.optBoolean("enabled"),if(times==null) listOf(540,780,1020,1260) else (0 until times.length()).map { times.getInt(it) },ReminderPool.valueOf(j.optString("pool","ALL")),j.optString("letter").takeIf { it.isNotEmpty() },ReminderPrompt.valueOf(j.optString("prompt","SWEDISH")),j.optBoolean("sound"),j.optBoolean("artwork",true),
                if(j.has("frequency")) ReminderFrequency.valueOf(j.getString("frequency")) else if(j.has("times")) ReminderFrequency.CUSTOM else ReminderFrequency.HOURLY,
                j.optBoolean("sleepEnabled",!j.has("times")),j.optInt("sleepStart",1320),j.optInt("sleepEnd",480)).normalized()
        } }.getOrDefault(ReminderSettings())
        private set(value) { val j=JSONObject().put("enabled",value.enabled).put("times",JSONArray(value.times)).put("pool",value.pool.name).put("letter",value.letter ?: "").put("prompt",value.prompt.name).put("sound",value.sound).put("artwork",value.showArtwork).put("frequency",value.frequency.name).put("sleepEnabled",value.sleepEnabled).put("sleepStart",value.sleepStart).put("sleepEnd",value.sleepEnd); check(prefs.edit().putString("settings",j.toString()).commit()) }
    val nextDate: Long? get() { val a=queue();return (0 until a.length()).map { a.getJSONObject(it).getLong("at") }.filter { it>System.currentTimeMillis() }.minOrNull() }
    fun allowed(): Boolean = (Build.VERSION.SDK_INT<33 || ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) && notifications.areNotificationsEnabled()
    private fun queue()=JSONArray(prefs.getString("queue","[]"))
    private fun pending(slot: Int, generation: Long, flags: Int=PendingIntent.FLAG_UPDATE_CURRENT): PendingIntent? = PendingIntent.getBroadcast(context,slot,Intent(context,ReminderReceiver::class.java).setAction("com.linapps.swedish3000.REMINDER").putExtra("slot",slot).putExtra("generation",generation),flags or PendingIntent.FLAG_IMMUTABLE)
    private fun cancelScheduled() { for(slot in 0..57) pending(slot,0,PendingIntent.FLAG_NO_CREATE)?.let { alarm.cancel(it);it.cancel() } }
    suspend fun save(value: ReminderSettings, access: Entitlement): Boolean=lock.withLock {
        check(!value.enabled || access==Entitlement.COMPLETE) { "Word reminders require Premium." }
        check(!value.enabled || value.dailyMinutes.isNotEmpty()) { "Choose different sleep and wake times so there are waking hours for reminders." }
        if(value.enabled && !allowed()) return@withLock false
        if(value.enabled && ReminderPlan.eligible(repository.loadWords(),repository.ratings(),value).isEmpty()) error("No words match. Choose another group or letter.")
        settings=value.normalized(); rebuild(access);true
    }
    suspend fun refresh(access: Entitlement, force: Boolean=false)=lock.withLock {
        val future=nextDate
        val zone=ZoneId.systemDefault().id
        if(force || prefs.getString("zone",null)!=zone || prefs.getString("access",null)!=access.name || future==null || prefs.getLong("planned",0)<System.currentTimeMillis()-24*60*60*1000L) rebuild(access)
    }
    private suspend fun rebuild(access: Entitlement) {
        cancelScheduled()
        val settings=settings
        if(!settings.enabled || (access!=Entitlement.COMPLETE && prefs.getString("access",null)==Entitlement.COMPLETE.name)) notifications.cancelAll()
        if(!settings.enabled || !allowed() || access!=Entitlement.COMPLETE) {
            prefs.edit().putString("queue","[]").putString("access",access.name).apply()
            if(access!=Entitlement.COMPLETE) notifications.cancelAll()
            return
        }
        val words=repository.loadWords(); val ratings=repository.ratings()
        val recent=prefs.getString("recent","")!!.split(',').filter { it.isNotBlank() }
        val plan=ReminderPlan.make(words,ratings,settings,Instant.now(),ZoneId.systemDefault(),recent)
        val entries=JSONArray(plan.map { JSONObject().put("at",it.at).put("id",it.wordId) })

        val generation=maxOf(System.currentTimeMillis(),prefs.getLong("generation",0)+1)
        check(prefs.edit().putString("queue",entries.toString()).putLong("generation",generation).putLong("planned",System.currentTimeMillis()).putString("zone",ZoneId.systemDefault().id).putString("access",access.name).commit())
        // One next alarm, replenished after delivery. There is no four-times or
        // two-week expiry, and no restricted exact-alarm permission is required.
        if(entries.length()>0) alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,entries.getJSONObject(0).getLong("at"),pending(0,generation)!!)
    }
    suspend fun sample(value: ReminderSettings, access: Entitlement) {
        check(access==Entitlement.COMPLETE) { "Word reminders require Premium." }
        check(allowed()) { "Allow notifications first, then send a sample." }
        val words=ReminderPlan.eligible(repository.loadWords(),repository.ratings(),value)
        val word=words.firstOrNull { it.english=="apple" } ?: words.firstOrNull() ?: error("No words match.")
        delay(5000); deliver(word,value,access,1000)
    }
    suspend fun receive(slot: Int,generation: Long,access: Entitlement) = lock.withLock {
        if(generation!=prefs.getLong("generation",-1) || !settings.enabled || !allowed()) return@withLock
        if(access!=Entitlement.COMPLETE) { rebuild(access);return@withLock }
        val entry=queue().optJSONObject(slot) ?: return@withLock
        if(entry.getLong("at")>System.currentTimeMillis()) return@withLock
        // Battery-saving modes can delay an alarm into the sleep window.
        // Drop that notification and schedule the next waking slot instead.
        val now=Instant.now().atZone(ZoneId.systemDefault())
        if(settings.awake(now.hour*60+now.minute)) {
            val id=entry.getString("id")
            val words=repository.loadWords()
            val eligible=ReminderPlan.eligible(words,repository.ratings(),settings)
            val word=eligible.firstOrNull { it.id==id } ?: eligible.firstOrNull()
            if(word!=null) {
                deliver(word,settings,access,slot)
                val recent=(prefs.getString("recent","")!!.split(',')+word.id).filter { it.isNotBlank() }.takeLast(56)
                prefs.edit().putString("recent",recent.joinToString(",")).apply()
            }
        }
        rebuild(access)
    }
    private fun deliver(word: Word,settings: ReminderSettings,access: Entitlement,slot: Int) = notify(word,settings,access,slot)
    @Suppress("MissingPermission")
    private fun notify(word: Word?, settings: ReminderSettings, access: Entitlement, slot: Int) {
        if(!allowed() || access!=Entitlement.COMPLETE) return
        val channel=if(settings.sound) "word-reminders-sound" else "word-reminders-silent"
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(channel,if(settings.sound) "Word reminders with sound" else "Silent word reminders",NotificationManager.IMPORTANCE_DEFAULT).apply { if(!settings.sound) setSound(null,null) })
        val text=word?.let { ReminderPlan.text(it,settings.prompt) } ?: ("Ready for more Swedish?" to "Open 3000 Swedish Words to prepare your next two weeks of reminders.")
        val intent=Intent(context,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP).putExtra("reminderWord",word?.id).putExtra("reminderEnglish",settings.prompt==ReminderPrompt.ENGLISH).putExtra("reminderSettings",word==null)
        val content=PendingIntent.getActivity(context,slot,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=NotificationCompat.Builder(context,channel).setSmallIcon(R.drawable.ic_notification).setContentTitle(text.first).setContentText(text.second).setStyle(NotificationCompat.BigTextStyle().bigText(text.second)).setContentIntent(content).setAutoCancel(true)
        if(word!=null && settings.showArtwork && AccessPolicy.hasLesson(word,access)) {
            val bitmap=runCatching {
                artwork.active(word.id)?.let { BitmapFactory.decodeFile(artwork.file(it.thumbnail).path) }
                    ?: media.cached("image/${word.thumbnail}")?.let { BitmapFactory.decodeByteArray(it,0,it.size) }
            }.getOrNull()
            bitmap?.let { builder.setLargeIcon(it) }
        }
        notifications.notify(slot,builder.build())
    }
}
class ReminderReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context,intent: Intent) {
        val pending=goAsync();val app=context.applicationContext as SwedishApplication
        app.background.launch {
            try {
                val access=app.entitlements.access.value
                if(intent.action=="com.linapps.swedish3000.REMINDER") app.reminders.receive(intent.getIntExtra("slot",-1),intent.getLongExtra("generation",-1),access)
                else app.reminders.refresh(access,force=true)
            } catch(e: Exception) { android.util.Log.e("WordReminders","Could not refresh or deliver a reminder",e) }
            finally { pending.finish() }
        }
    }
}
