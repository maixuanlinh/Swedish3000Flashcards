package com.linapps.swedish3000

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.LocalStudyRepository
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
        assertEquals(211,words.size)
        assertEquals(211,words.map { it.id }.toSet().size)
        assertEquals(211,words.count { it.initial=="A" })
        assertTrue(words.all { it.sentence.isNotBlank() && it.sentenceEnglish.isNotBlank() })
        assertEquals("a, an",words.first().english)
        val apple=words.single { it.id=="sv-0136" }
        assertEquals("Vocabulary",apple.topic)
        assertEquals("ett äpple",apple.swedish)
        assertTrue(apple.image.isEmpty())
        val article=words.single { it.id=="sv-0001" }
        assertEquals("en / ett",article.swedish)
        context.assets.open("BundledArtwork/${article.image}").use { assertTrue(it.read()>0) }
        assertTrue(words.all { it.id.startsWith("sv-") })
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
