package com.linapps.swedish3000

import com.linapps.swedish3000.domain.*
import org.junit.Assert.*
import org.junit.Test

class MediaPrefetchTest {
    @Test fun preparesOnlyCurrentAndNextThreeCards() {
        val words=(1..8).map { word("apple $it","a-$it").copy(swedish="ett äpple $it",image="a-$it.jpg",thumbnail="a-$it-thumb.jpg",sentence="sentence $it") }
        val requests=prefetchLessons(words,Entitlement.COMPLETE)
        assertEquals(20,requests.size)
        assertTrue("image" to "a-4.jpg" in requests)
        assertFalse("image" to "a-5.jpg" in requests)
    }
    @Test fun basicWordsDoNotPrefetchLockedLessonMedia() {
        val requests=prefetchLessons(listOf(word("bicycle")),Entitlement.FREE)
        assertEquals(listOf("audio/sv-SE" to "ett äpple"),requests)
    }
    @Test fun repeatedAudioIsFetchedOnceAndNoCardsNeedsNoDownloads() {
        val apple=word()
        assertEquals(prefetchLessons(listOf(apple),Entitlement.FREE),prefetchLessons(listOf(apple,apple),Entitlement.FREE))
        assertTrue(prefetchLessons(emptyList(),Entitlement.COMPLETE).isEmpty())
    }
}
