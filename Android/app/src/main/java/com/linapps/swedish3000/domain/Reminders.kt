package com.linapps.swedish3000.domain

import java.time.*
import java.util.Locale
import kotlin.random.Random

enum class ReminderPool(val title: String) { ALL("All words"), LEARNING("Still learning"), REMAINING("New & learning") }
enum class ReminderPrompt(val title: String) { SWEDISH("Swedish question"), ENGLISH("English question"), PAIR("Word and meaning") }
enum class ReminderFrequency(val title: String,val interval: Int?) {
    HALF_HOURLY("Every 30 minutes",30), HOURLY("Every hour",60), TWO_HOURLY("Every 2 hours",120), THREE_HOURLY("Every 3 hours",180), FOUR_HOURLY("Every 4 hours",240), ONCE_DAILY("Once a day",null), TWICE_DAILY("Twice a day",null), FOUR_DAILY("Four times a day",null), CUSTOM("Custom times",null);
    val presetTimes:List<Int>? get()=when(this) {ONCE_DAILY->listOf(540);TWICE_DAILY->listOf(540,1020);FOUR_DAILY->listOf(540,780,1020,1260);else->null}
}
data class ReminderSettings(
    val enabled: Boolean=false, val times: List<Int> = listOf(540,780,1020,1260),
    val pool: ReminderPool=ReminderPool.ALL, val letter: String?=null,
    val prompt: ReminderPrompt=ReminderPrompt.SWEDISH, val sound: Boolean=false, val showArtwork: Boolean=true,
    val frequency: ReminderFrequency=ReminderFrequency.HOURLY, val sleepEnabled: Boolean=true,
    val sleepStart: Int=1320, val sleepEnd: Int=480
) {
    fun awake(minute: Int): Boolean {
        if(!sleepEnabled) return true
        if(sleepStart==sleepEnd) return false
        return if(sleepStart<sleepEnd) minute !in sleepStart until sleepEnd else minute in sleepEnd until sleepStart
    }
    val dailyMinutes: List<Int> get() {
        val normalized=normalized()
        val interval=frequency.interval
        val minutes=if(interval==null) normalized.times else (0 until 1440 step interval).map { ((if(sleepEnabled) normalized.sleepEnd else 0)+it)%1440 }
        return minutes.filter { normalized.awake(it) }.distinct().sorted()
    }
    fun normalized() = copy(times=times.filter { it in 0..1439 }.distinct().sorted().take(48).ifEmpty { listOf(540) },letter=letter?.takeIf { it.length==1 && it[0] in 'A'..'Z' },sleepStart=sleepStart.coerceIn(0,1439),sleepEnd=sleepEnd.coerceIn(0,1439))
}
data class PlannedReminder(val at: Long, val wordId: String)
object ReminderPlan {
    fun eligible(words: List<Word>, ratings: Map<String,Rating>, settings: ReminderSettings) = words.filter { word ->
        (settings.letter==null || word.initial==settings.letter) && when(settings.pool) {
            ReminderPool.ALL -> true
            ReminderPool.LEARNING -> ratings[word.id]?.status==LearningStatus.LEARNING
            ReminderPool.REMAINING -> ratings[word.id]?.status!=LearningStatus.KNOWN
        }
    }
    fun dates(settings: ReminderSettings, now: Instant, zone: ZoneId): List<Long> {
        val start=now.atZone(zone).toLocalDate()
        val end=now.atZone(zone).plusDays(14).toInstant()
        // atZone advances nonexistent local times through DST gaps and uses the first offset for overlaps.
        return (0L..14L).flatMap { day -> settings.dailyMinutes.map { minute ->
            start.plusDays(day).atTime(minute/60,minute%60).atZone(zone).toInstant()
        } }.distinct().filter { it>now && it<end }.sorted().take(56).map { it.toEpochMilli() }
    }
    fun make(words: List<Word>, ratings: Map<String,Rating>, settings: ReminderSettings, now: Instant, zone: ZoneId, recent: List<String> = emptyList(), random: Random=Random.Default): List<PlannedReminder> {
        val pool=eligible(words,ratings,settings.normalized())
        if(pool.isEmpty()) return emptyList()
        var bag=pool.filter { it.id !in recent }.shuffled(random).toMutableList()
        var previous=recent.lastOrNull()
        return dates(settings,now,zone).map { at ->
            if(bag.isEmpty()) bag=pool.shuffled(random).toMutableList()
            if(bag.last().id==previous && bag.size>1) { val first=bag[0]; bag[0]=bag.last(); bag[bag.lastIndex]=first }
            val word=bag.removeAt(bag.lastIndex); previous=word.id
            PlannedReminder(at,word.id)
        }
    }
    fun text(word: Word, prompt: ReminderPrompt): Pair<String,String> = when(prompt) {
        ReminderPrompt.SWEDISH -> "Do you remember this word?" to "${word.swedish.uppercase(Locale.ROOT)}\nTap to recall its English meaning."
        ReminderPrompt.ENGLISH -> "Can you say it in Swedish?" to "${word.english.uppercase(Locale.ROOT)}\nTap to recall the Swedish word."
        ReminderPrompt.PAIR -> "A little Swedish practice" to "${word.swedish.uppercase(Locale.ROOT)} — ${word.english}\nTap to practise this word."
    }
}
