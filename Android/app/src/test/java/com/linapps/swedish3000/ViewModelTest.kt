@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
package com.linapps.swedish3000

import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelProvider
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.ui.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.*
import org.junit.*
import org.junit.Assert.*

class ViewModelTest {
    private val dispatcher=StandardTestDispatcher()
    private lateinit var repo: FakeRepository
    private lateinit var vm: StudyViewModel
    private val store=ViewModelStore()
    private val access=object: EntitlementRepository {
        override val access=MutableStateFlow(Entitlement.FREE)
        override suspend fun refresh() {}
    }
    @Before fun setup() {
        Dispatchers.setMain(dispatcher)
        repo=FakeRepository()
        val prefs=object: Preferences {
            override var englishFirst=true
            override var playback=PlaybackSettings(recallSeconds=1,answerSeconds=1,readPrompt=false,readAnswer=false,readSentence=false)
        }
        val speech=object: Speech {
            override suspend fun say(text: String,language: String,rate: Float) {}
            override fun stop() {}
            override fun close() {}
        }
        vm=ViewModelProvider(store,object: ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T: androidx.lifecycle.ViewModel> create(modelClass: Class<T>) = StudyViewModel(repo,access,prefs,speech) as T
        })[StudyViewModel::class.java]
    }
    @After fun cleanup() { store.clear();Dispatchers.resetMain() }
    @Test fun ratingUpdatesSharedFilterAndUndoRestoresCard() = runTest(dispatcher) {
        runCurrent()
        assertEquals(2,vm.uiState.value.queue.size)
        vm.rate("a",LearningStatus.KNOWN);runCurrent()
        assertEquals(listOf("b"),vm.uiState.value.queue)
        assertEquals(1,vm.uiState.value.matches.size)
        vm.undo();runCurrent()
        assertEquals("a",vm.uiState.value.current?.id)
        assertTrue(vm.uiState.value.events.isEmpty())
    }
    @Test fun autoPlaybackCompletesWithoutLearningWritesAndStopRestoresManualQueue() = runTest(dispatcher) {
        runCurrent()
        val manual=vm.uiState.value.queue
        vm.play();advanceUntilIdle()
        assertEquals(PlaybackState.FINISHED,vm.uiState.value.playback)
        assertEquals(2,vm.uiState.value.completed.size)
        assertTrue(repo.history.isEmpty())
        assertTrue(repo.progress.isEmpty())
        vm.stop()
        assertEquals(manual,vm.uiState.value.queue)
        assertEquals("a",vm.uiState.value.current?.id)
    }
    @Test fun skippingExcludesUnfinishedCardAndTabChangePauses() = runTest(dispatcher) {
        runCurrent();vm.play();runCurrent()
        vm.step(1);runCurrent();vm.tab(1);advanceUntilIdle()
        assertEquals(PlaybackState.PAUSED,vm.uiState.value.playback)
        assertTrue(vm.uiState.value.completed.isEmpty())
        assertTrue(repo.history.isEmpty())
        vm.play();advanceUntilIdle()
        assertEquals(setOf("b"),vm.uiState.value.completed)
    }
    @Test fun accessRevocationStopsPaidPlayback() = runTest(dispatcher) {
        runCurrent();repo.words=listOf(word("bicycle","b"));vm.load();runCurrent()
        access.access.value=Entitlement.COMPLETE;runCurrent();vm.play();runCurrent()
        assertEquals(PlaybackState.PLAYING,vm.uiState.value.playback)
        access.access.value=Entitlement.FREE;runCurrent()
        assertEquals(PlaybackState.IDLE,vm.uiState.value.playback)
        assertTrue(repo.history.isEmpty())
    }
    @Test fun automaticStudyUsesRemainingQueueAndUndoCanWalkBackSeveralRatings() = runTest(dispatcher) {
        runCurrent();vm.filter(WordFilter(scope=Scope.ALL))
        vm.rate("a",LearningStatus.KNOWN);runCurrent()
        vm.play();advanceUntilIdle()
        assertEquals(listOf("b"),vm.uiState.value.playIds)
        vm.stop();vm.rate("b",LearningStatus.LEARNING);runCurrent()
        vm.undo();runCurrent();assertEquals("b",vm.uiState.value.current?.id)
        vm.undo();runCurrent();assertEquals(listOf("a","b"),vm.uiState.value.queue)
        assertTrue(repo.history.isEmpty())
    }
    @Test fun searchingLibraryDoesNotChangeStudyAndPractiseUsesSearchSelection() = runTest(dispatcher) {
        runCurrent();val original=vm.uiState.value.queue
        vm.tab(1);vm.search("abandon")
        assertEquals(original,vm.uiState.value.queue)
        assertEquals(listOf("b"),vm.uiState.value.matches.map { it.id })
        vm.practice();assertEquals(listOf("b"),vm.uiState.value.queue)
        assertTrue(vm.uiState.value.selectedWords)
        vm.search("");assertEquals(listOf("b"),vm.uiState.value.queue)
    }
    @Test fun shuffleDoesNotReintroduceReviewedCards() = runTest(dispatcher) {
        runCurrent();vm.filter(WordFilter(scope=Scope.ALL));vm.rate("a",LearningStatus.KNOWN);runCurrent()
        vm.shuffle();assertEquals(listOf("b"),vm.uiState.value.queue)
        assertNotNull(vm.uiState.value.undo)
    }
    @Test fun reminderOpensKnownWordAndTemporarilyOverridesPromptWithoutChangingPreference() = runTest(dispatcher) {
        runCurrent();vm.rate("a",LearningStatus.KNOWN);runCurrent()
        vm.filter(WordFilter(scope=Scope.LEARNING,letter="Z"));vm.openReminder("a",false)
        assertEquals("a",vm.uiState.value.current?.id);assertFalse(vm.uiState.value.showsEnglishFirst)
        assertTrue(vm.uiState.value.englishFirst);assertEquals(1,repo.history.size)
        vm.studyAll();assertTrue(vm.uiState.value.showsEnglishFirst)
        assertEquals(LearningStatus.KNOWN,vm.uiState.value.ratings["a"]?.status)
    }
    @Test fun detailCanResetWordToNewAndDoesNotCreateStudyUndo() = runTest(dispatcher) {
        runCurrent();vm.detail("a");vm.rate("a",LearningStatus.KNOWN);runCurrent()
        assertNull(vm.uiState.value.undo)
        vm.rate("a",LearningStatus.NEW);runCurrent()
        assertEquals(LearningStatus.NEW,vm.uiState.value.ratings["a"]?.status)
        assertEquals(2,repo.history.size)
    }
    private class FakeRepository: StudyRepository {
        var words=listOf(word("apple","a"),word("abandon","b"))
        val progress=mutableMapOf<String,Rating>()
        val history=mutableListOf<ReviewEvent>()
        override suspend fun loadWords()=words
        override suspend fun ratings()=progress.toMap()
        override suspend fun events()=history.toList()
        override suspend fun rate(wordId: String,status: LearningStatus): UndoRating {
            val previous=progress[wordId] ?: Rating()
            val event=ReviewEvent(history.size.toLong()+1,wordId,status,1000)
            history+=event;progress[wordId]=Rating(status,previous.count+1,event.at)
            return UndoRating(wordId,previous,event)
        }
        override suspend fun undo(snapshot: UndoRating) { progress[snapshot.wordId]=snapshot.previous;history.remove(snapshot.event) }
    }
}
