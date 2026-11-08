@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
package com.linapps.swedish3000

import androidx.lifecycle.*
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.ui.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.*
import org.junit.*
import org.junit.Assert.*

class SavedSessionViewModelTest {
    private val dispatcher=StandardTestDispatcher()
    private val stores=mutableListOf<ViewModelStore>()
    private val prefs=object:Preferences {override var englishFirst=true;override var playback=PlaybackSettings();override var session:SavedStudySession?=null}
    private val repo=object:StudyRepository {
        val progress=mutableMapOf<String,Rating>();val history=mutableListOf<ReviewEvent>()
        override suspend fun loadWords()=listOf(word("apple","a"),word("abandon","b"))
        override suspend fun ratings()=progress.toMap()
        override suspend fun events()=history.toList()
        override suspend fun rate(wordId:String,status:LearningStatus):UndoRating {val previous=progress[wordId] ?: Rating();val event=ReviewEvent(history.size+1L,wordId,status,1000L+history.size);history+=event;progress[wordId]=Rating(status,previous.count+1,event.at);return UndoRating(wordId,previous,event)}
        override suspend fun undo(snapshot:UndoRating) {progress[snapshot.wordId]=snapshot.previous;history.remove(snapshot.event)}
    }
    private val access=object:EntitlementRepository {override val access=MutableStateFlow(Entitlement.FREE);override suspend fun refresh() {}}
    private fun newVM():StudyViewModel {
        val store=ViewModelStore();stores+=store
        return ViewModelProvider(store,object:ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST") override fun <T:ViewModel> create(modelClass:Class<T>):T = StudyViewModel(repo,access,prefs,object:Speech {override suspend fun say(text:String,language:String,rate:Float) {};override fun stop() {};override fun close() {}}) as T
        })[StudyViewModel::class.java]
    }
    @Before fun setup() {Dispatchers.setMain(dispatcher)}
    @After fun cleanup() {stores.forEach {it.clear()};Dispatchers.resetMain()}
    @Test fun exactRemainingOrderAndUndoSurviveFreshViewModel()=runTest(dispatcher) {
        val first=newVM();runCurrent();first.filter(WordFilter(scope=Scope.ALL,letter="A"));first.rate("a",LearningStatus.LEARNING);runCurrent()
        assertEquals(listOf("b"),prefs.session!!.ids)
        val restored=newVM();runCurrent();assertEquals("b",restored.uiState.value.current!!.id);assertEquals(2,restored.uiState.value.initialCount)
        first.undo();runCurrent();val afterUndo=newVM();runCurrent();assertEquals(listOf("a","b"),afterUndo.uiState.value.queue)
    }
    @Test fun browsingAndSearchingDoNotReplaceTheLearningSession()=runTest(dispatcher) {
        val vm=newVM();runCurrent();vm.filter(WordFilter(scope=Scope.ALL,letter="A"));vm.rate("a",LearningStatus.LEARNING);runCurrent()
        val saved=prefs.session;val queue=vm.uiState.value.queue
        vm.tab(1);vm.search("apple")
        assertEquals(queue,vm.uiState.value.queue);assertEquals(saved,prefs.session)
        vm.tab(0);assertEquals(queue,vm.uiState.value.queue);assertEquals(saved,prefs.session)
    }
    @Test fun notificationSessionDoesNotOverwriteTheBookmark()=runTest(dispatcher) {
        val vm=newVM();runCurrent();val saved=prefs.session
        vm.openReminder("b",false);vm.rate("b",LearningStatus.KNOWN);runCurrent()
        assertEquals(saved,prefs.session)
        val restored=newVM();runCurrent();assertEquals("a",restored.uiState.value.current!!.id);assertEquals(listOf("a"),restored.uiState.value.queue)
    }
    @Test fun backToTopicsClearsLibraryRestrictionsButPreservesStudyBookmark()=runTest(dispatcher) {
        val vm=newVM();runCurrent();vm.filter(WordFilter(scope=Scope.ALL,letter="A"));val saved=prefs.session
        vm.tab(1);vm.collection(VocabularyTopic.home);vm.search("missing");vm.browseTopics()
        assertNull(vm.uiState.value.filter.topic);assertNull(vm.uiState.value.filter.letter);assertEquals("",vm.uiState.value.search)
        assertTrue(vm.uiState.value.browsingTopics);assertEquals(saved,prefs.session)
        vm.tab(0);assertEquals(saved,prefs.session);assertEquals(saved!!.ids,vm.uiState.value.queue)
    }
    @Test fun keepPractisingIncludesLearningWordsOutsideTheLastTopic()=runTest(dispatcher) {
        val vm=newVM();runCurrent();repo.progress["a"]=Rating(LearningStatus.LEARNING)
        vm.load();runCurrent();vm.filter(WordFilter(scope=Scope.ALL,letter="Z",topic=VocabularyTopic.home.title))
        vm.tab(2);vm.keepPractising();runCurrent()
        assertEquals(listOf("a"),vm.uiState.value.queue);assertNull(vm.uiState.value.filter.topic);assertNull(vm.uiState.value.filter.letter)
    }

}
