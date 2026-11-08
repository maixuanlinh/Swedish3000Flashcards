package com.linapps.swedish3000

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.LocalStudyRepository
import com.linapps.swedish3000.data.LessonMedia
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.test.runTest
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],application=android.app.Application::class)
class RepositoryTest {
    private lateinit var context: Context
    @Before fun setup() { context=ApplicationProvider.getApplicationContext();context.deleteDatabase("swedish-progress.db") }
    @Test fun actualAssetsHaveCompleteStableContentAndFreeASet() = runTest {
        val words=LocalStudyRepository(context).loadWords()
        assertEquals(3000,words.size)
        assertEquals(3000,words.map { it.id }.toSet().size)
        assertEquals((1..3000).map { "sv-" + it.toString().padStart(4, '0') }.toSet(), words.map { it.id }.toSet())
        for ((letter, count) in mapOf("A" to 211, "B" to 152, "C" to 292, "D" to 163, "E" to 162, "F" to 155, "G" to 73, "H" to 100, "I" to 121, "J" to 23, "K" to 18, "L" to 108, "M" to 134, "N" to 65, "O" to 82, "P" to 238, "Q" to 16, "R" to 163, "S" to 351, "T" to 166, "U" to 50, "V" to 36, "W" to 106, "Y" to 13, "Z" to 2)) {
            assertEquals(letter, count, words.count { it.initial==letter })
        }
        for ((id, meaning) in mapOf("sv-1461" to "en sort", "sv-1462" to "snäll", "sv-1525" to "ligga", "sv-1526" to "ljuga", "sv-1332" to "antyda", "sv-0001" to "en / ett")) {
            assertEquals(meaning, words.single { it.id==id }.swedish)
        }
        assertTrue(words.all { it.sentence.isNotBlank() && it.sentenceEnglish.isNotBlank() })
        assertEquals("a, an",words.first().english)
        val apple=words.single { it.id=="sv-0136" }
        assertEquals("Vocabulary",apple.topic)
        assertEquals("ett äpple",apple.swedish)
        val picture=LessonMedia(context).load("image/${apple.image}")
        assertNotNull(android.graphics.BitmapFactory.decodeByteArray(picture,0,picture.size))
    }
    @Test fun ratingsSurviveNewRepositoryAndUndoRemovesOnlyItsEvent() = runTest {
        val repo=LocalStudyRepository(context)
        repo.rate("sv-0136",LearningStatus.LEARNING)
        val known=repo.rate("sv-0136",LearningStatus.KNOWN)
        val fresh=LocalStudyRepository(context)
        assertEquals(2,fresh.ratings().getValue("sv-0136").count)
        assertEquals(LearningStatus.KNOWN,fresh.ratings().getValue("sv-0136").status)
        fresh.undo(known)
        assertEquals(LearningStatus.LEARNING,repo.ratings().getValue("sv-0136").status)
        assertEquals(1,repo.events().size)
        assertEquals(1,repo.ratings().getValue("sv-0136").count)
    }
    @Test fun staleUndoKeepsNewerRating() = runTest {
        val repo=LocalStudyRepository(context)
        val first=repo.rate("sv-0136",LearningStatus.KNOWN)
        repo.rate("sv-0136",LearningStatus.LEARNING)
        try { repo.undo(first);fail("Expected stale undo rejection") } catch(_: IllegalStateException) {}
        assertEquals(LearningStatus.LEARNING,repo.ratings().getValue("sv-0136").status)
        assertEquals(2,repo.events().size)
    }
}
