package com.linapps.swedish3000

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.test.runTest
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],application=Application::class)
class IosParityContractTest {
    private val context:Context get()=ApplicationProvider.getApplicationContext()
    @Test fun allWordsMatchTheReleasedTopicContractWithoutDuplicateProgress()=runTest {
        val repository=LocalStudyRepository(context);val words=repository.loadWords()
        assertEquals(9,VocabularyTopic.themes.size);assertEquals(7,VocabularyTopic.coreCollections.size)
        assertTrue(words.all {it.studyTopics.isNotEmpty()})
        val groups=VocabularyTopic.coreCollections.map {topic -> words.filter {topic in it.studyTopics}}
        assertTrue(groups.all {it.size in 1..300})
        val ids=groups.flatten().map {it.id};assertEquals(1390,ids.size);assertEquals(ids.size,ids.toSet().size)
        val shared=words.first {it.studyTopics.size>1}
        repository.rate(shared.id,LearningStatus.KNOWN)
        assertEquals(1,repository.ratings().getValue(shared.id).count)
        assertTrue(shared.studyTopics.all {topic -> words.count {it.id==shared.id && topic in it.studyTopics}==1})
    }
    @Test fun exactOrderedSessionAndSettingsSurviveNewPreferences() {
        val p=LocalPreferences(context)
        val saved=SavedStudySession(WordFilter(scope=Scope.ALL,letter="A",topic=VocabularyTopic.commonVerbs.title),listOf("a","c","b"),7,true)
        p.session=saved
        assertEquals(saved,LocalPreferences(context).session)
        assertEquals(7,LocalPreferences(context).session?.initialCount)
    }
    @Test fun halfHourlyRemindersUseSleepHoursAndHaveNoFourSlotLimit() {
        val settings=ReminderSettings(frequency=ReminderFrequency.HALF_HOURLY)
        assertEquals(28,settings.dailyMinutes.size)
        assertEquals(480,settings.dailyMinutes.first());assertEquals(1290,settings.dailyMinutes.last())
        assertEquals(48,settings.copy(sleepEnabled=false).dailyMinutes.size)
        val now=Instant.parse("2026-11-08T00:00:00Z")
        val times=ReminderPlan.dates(settings,now,ZoneId.of("Europe/Helsinki"))
        assertTrue(times.size>4);assertTrue(times.all {val local=Instant.ofEpochMilli(it).atZone(ZoneId.of("Europe/Helsinki"));settings.awake(local.hour*60+local.minute)})
        assertTrue(settings.copy(sleepEnd=1320).dailyMinutes.isEmpty())
    }
    @Test fun freeDownloadContainsOnlyAllowedAssetsAndRejectsPaidRanges()=runTest {
        val words=LocalStudyRepository(context).loadWords();val media=LessonMedia(context);media.configurePreview(words)
        val free=words.filter {it.initial=="A"}
        val paid=words.first {it.initial=="B"}
        assertEquals(211,free.size)
        val expected=free.flatMap {listOf("image/${it.image}","image/${it.thumbnail}",recordingKey("en-US",it.english),recordingKey("sv-SE",it.swedish),recordingKey("sv-SE",it.sentence))}.toSet()
        assertEquals(expected,media.previewKeys)
        try {media.downloadPreview("image/${paid.image}");fail("Paid illustration must not enter a Free download")} catch(_:IllegalArgumentException) {}
        assertTrue(media.previewStatus.value.totalBytes<media.status.value.totalBytes)
    }
    @Test fun reminderFrequencyChoicesMatchTheReleasedIOS() {
        assertEquals(listOf(30,60,120,180,240),ReminderFrequency.entries.mapNotNull {it.interval})
        assertEquals(listOf(540),ReminderFrequency.ONCE_DAILY.presetTimes)
        assertEquals(listOf(540,1020),ReminderFrequency.TWICE_DAILY.presetTimes)
        assertEquals(listOf(540,780,1020,1260),ReminderFrequency.FOUR_DAILY.presetTimes)
        assertEquals(5,ReminderSettings(frequency=ReminderFrequency.THREE_HOURLY).dailyMinutes.size)
        assertEquals(4,ReminderSettings(frequency=ReminderFrequency.FOUR_HOURLY).dailyMinutes.size)
    }
    @Test fun vocabularySearchMatchesIOSCaseAccentAndNativeSentenceRules() {
        val w=word().copy(english="résumé",swedish="åäö",sentence="Ääni kuuluu täällä.",sentenceEnglish="An English-only example")
        listOf("RESUME","aao","aani","taalla").forEach {assertTrue(WordFilter(query=it,scope=Scope.ALL).matches(w,LearningStatus.NEW))}
        assertFalse(WordFilter(query="English-only",scope=Scope.ALL).matches(w,LearningStatus.NEW))
    }

}
