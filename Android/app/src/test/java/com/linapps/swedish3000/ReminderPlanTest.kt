package com.linapps.swedish3000

import com.linapps.swedish3000.domain.*
import org.junit.Test
import org.junit.Assert.*
import java.time.*
import kotlin.random.Random

class ReminderPlanTest {
    @Test fun normalizesTimesWithoutTurningOnReminders() {
        val settings=ReminderSettings(times=listOf(-1,780,540,540,3000)).normalized()
        assertFalse(settings.enabled);assertEquals(listOf(540,780),settings.times)
        assertEquals(listOf(540),ReminderSettings(times=emptyList()).normalized().times)
        assertNull(ReminderSettings(letter="Å").normalized().letter)
    }
    @Test fun scheduleIsFutureBoundedAndKeepsLocalTimeAcrossDST() {
        val zone=ZoneId.of("Europe/Helsinki");val now=Instant.parse("2026-10-24T12:00:00Z")
        val dates=ReminderPlan.dates(ReminderSettings(times=listOf(540),frequency=ReminderFrequency.CUSTOM,sleepEnabled=false),now,zone).map { Instant.ofEpochMilli(it).atZone(zone) }
        assertEquals(14,dates.size);assertTrue(dates.all { it.toInstant()>now && it.hour==9 && it.minute==0 })
        assertEquals(ZoneOffset.ofHours(2),dates.first().offset)
        assertTrue(ReminderPlan.dates(ReminderSettings(),now,zone).size<=56)
    }
    @Test fun overlappingTimeIsDeliveredOnlyOncePerDay() {
        val zone=ZoneId.of("Europe/Helsinki")
        val dates=ReminderPlan.dates(ReminderSettings(times=listOf(210),frequency=ReminderFrequency.CUSTOM,sleepEnabled=false),Instant.parse("2026-10-24T12:00:00Z"),zone).map { Instant.ofEpochMilli(it).atZone(zone) }
        assertEquals(dates.size,dates.map { it.toLocalDate() }.toSet().size)
        assertEquals(ZoneOffset.ofHours(3),dates.first().offset)
    }
    @Test fun shuffleCyclesAvoidRepeatedNeighboursAndRespectLearningPool() {
        val words=listOf(word("apple","a"),word("abandon","b"),word("bicycle","c"))
        val settings=ReminderSettings(pool=ReminderPool.LEARNING,letter="A")
        val ratings=words.associate { it.id to Rating(LearningStatus.LEARNING) }
        val plan=ReminderPlan.make(words,ratings,settings,Instant.parse("2026-10-24T12:00:00Z"),ZoneId.of("Europe/Helsinki"),recent=listOf("a"),random=Random(4))
        assertTrue(plan.isNotEmpty());assertEquals("b",plan.first().wordId)
        assertTrue(plan.all { it.wordId!="c" });assertTrue(plan.zipWithNext().all { it.first.wordId!=it.second.wordId })
        assertTrue(ReminderPlan.make(words,emptyMap(),settings,Instant.now(),ZoneId.of("UTC")).isEmpty())
    }
    @Test fun promptMatchesIOSAndKnownWordsRemainEligibleInAllPool() {
        assertEquals("Can you say it in Swedish?",ReminderPlan.text(word(),ReminderPrompt.ENGLISH).first)
        assertTrue(ReminderPlan.text(word(),ReminderPrompt.SWEDISH).second.startsWith("ETT ÄPPLE"))
        assertEquals(1,ReminderPlan.eligible(listOf(word()),mapOf(word().id to Rating(LearningStatus.KNOWN)),ReminderSettings()).size)
    }
}
