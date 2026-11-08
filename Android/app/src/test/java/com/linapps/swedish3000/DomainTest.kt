package com.linapps.swedish3000

import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

internal fun word(english: String="apple",id: String="sv-0136") = Word(id,136,english,"ett äpple","Äpplet är rött.","The apple is red.","Food","a.jpg","a-thumb.jpg","Memory","Prompt")
class DomainTest {
    @Test fun dictionaryOrderIsIndependentOfDeviceLocale() {
        assertEquals("coop",dictionaryKey("Co-op (verb)"))
        assertEquals("resume",dictionaryKey("résumé / resume"))
        assertTrue(dictionaryKey("a, an") < dictionaryKey("abandon"))
    }
    @Test fun combinedFiltersSearchSwedishAndExamples() {
        val filter = WordFilter("RÖTT",Scope.REMAINING,"A","Food")
        assertTrue(filter.matches(word(),LearningStatus.NEW))
        assertFalse(filter.matches(word(),LearningStatus.KNOWN))
        assertFalse(filter.copy(letter="B").matches(word(),LearningStatus.NEW))
        assertFalse(filter.copy(query="the apple is red").matches(word(),LearningStatus.NEW))
        assertTrue(filter.copy(query="ROTT").matches(word(),LearningStatus.NEW))
        assertFalse(filter.copy(topic="Travel").matches(word(),LearningStatus.NEW))
    }
    @Test fun accessDefaultsToFreeWithoutBlockingBasicVocabulary() {
        assertTrue(AccessPolicy.hasLesson(word(),Entitlement.UNKNOWN))
        assertFalse(AccessPolicy.hasLesson(word("bicycle"),Entitlement.FREE))
        assertTrue(AccessPolicy.hasLesson(word("bicycle"),Entitlement.COMPLETE))
        assertFalse(AccessPolicy.canPlay(listOf(word(),word("bicycle")),Entitlement.FREE))
        assertTrue(Scope.ALL.includes(LearningStatus.KNOWN))
    }
    @Test fun playbackWaitsForEveryUtteranceBeforeAdvancing() = runTest {
        val log=mutableListOf<String>()
        val speech=object: Speech {
            override suspend fun say(text: String,language: String,rate: Float) { log+="$language:$text"; delay(50); log+="done" }
            override fun stop() {}
            override fun close() {}
        }
        PlaybackCycle(speech) { log+="wait:$it" }.play(word(),true,PlaybackSettings()) { log+="reveal" }
        assertEquals(listOf("en-US:apple","done","wait:3000","reveal","sv-SE:ett äpple","done","sv-SE:Äpplet är rött.","done","wait:2000"),log)
    }
    @Test fun reverseDirectionAndSilentPlayback() = runTest {
        val log=mutableListOf<String>()
        val speech=object: Speech {
            override suspend fun say(text: String,language: String,rate: Float) { log+="$language:$text" }
            override fun stop() {}
            override fun close() {}
        }
        val cycle=PlaybackCycle(speech) {}
        cycle.play(word(),false,PlaybackSettings(readSentence=false)) {}
        assertEquals(listOf("sv-SE:ett äpple","en-US:apple"),log)
        log.clear()
        cycle.play(word(),true,PlaybackSettings(readPrompt=false,readAnswer=false,readSentence=false)) { log+="reveal" }
        assertEquals(listOf("reveal"),log)
    }
    @Test fun cancellationDuringRecallNeverReveals() = runTest {
        var revealed=false
        val entered=CompletableDeferred<Unit>()
        val speech=object: Speech {
            override suspend fun say(text: String,language: String,rate: Float) {}
            override fun stop() {}
            override fun close() {}
        }
        val job=launch { PlaybackCycle(speech) { entered.complete(Unit); awaitCancellation() }.play(word(),true,PlaybackSettings()) { revealed=true } }
        entered.await();job.cancelAndJoin()
        assertFalse(revealed)
    }
}
