package com.linapps.swedish3000.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

enum class PlaybackState { IDLE, PLAYING, PAUSED, FINISHED }
data class StudyUiState(
    val loading: Boolean = true, val loadFailed: Boolean = false,
    val words: List<Word> = emptyList(), val ratings: Map<String, Rating> = emptyMap(),
    val events: List<ReviewEvent> = emptyList(), val filter: WordFilter = WordFilter(),
    val search: String = "", val selectedWords: Boolean = false,
    val queue: List<String> = emptyList(), val cursor: Int = 0, val initialCount: Int = 0,
    val revealed: Boolean = false, val tab: Int = 0, val detail: String? = null,
    val englishFirst: Boolean = true, val promptOverride: Boolean? = null,
    val history: List<UndoRating> = emptyList(), val busy: Boolean = false, val message: String? = null,
    val premiumRequested: Boolean = false,
    val reminderSettingsRequested: Boolean = false,
    val navigationRequest: Int = 0,
    val access: Entitlement = Entitlement.UNKNOWN, val settings: PlaybackSettings = PlaybackSettings(),
    val playback: PlaybackState = PlaybackState.IDLE, val playIds: List<String> = emptyList(),
    val playIndex: Int = 0, val completed: Set<String> = emptySet()
) {
    val byId by lazy { words.associateBy { it.id } }
    val matches by lazy { words.filter { filter.copy(query=search).matches(it, ratings[it.id]?.status ?: LearningStatus.NEW) } }
    val undo get() = history.lastOrNull()
    val showsEnglishFirst get() = promptOverride ?: englishFirst
    val current: Word? get() = byId[if(playback == PlaybackState.IDLE) queue.getOrNull(cursor) else playIds.getOrNull(playIndex)]
    val filterTitle get() = listOfNotNull(if(selectedWords) "Selected words" else filter.scope.title, filter.letter, filter.topic).joinToString(" · ")
}
class StudyViewModel(
    private val repository: StudyRepository, private val entitlements: EntitlementRepository,
    private val preferences: Preferences, private val speech: Speech
): ViewModel() {
    private val state = MutableStateFlow(StudyUiState(englishFirst=preferences.englishFirst, settings=preferences.playback))
    val uiState = state.asStateFlow()
    private var playbackJob: Job? = null
    private var speechJob: Job? = null
    private var loadJob: Job? = null
    private var session = 0
    private var pendingReminder: Pair<String,Boolean>? = null
    init {
        load()
        viewModelScope.launch {
            entitlements.access.collect { access ->
                if(state.value.playIds.mapNotNull { state.value.byId[it] }.any { !AccessPolicy.hasLesson(it,access) }) stop()
                state.update { it.copy(access=access) }
            }
        }
        refreshAccess()
    }
    fun refreshAccess() { viewModelScope.launch { entitlements.refresh() } }
    fun openReminderSettings() { pause(); state.update { it.copy(tab=2,reminderSettingsRequested=true) } }
    fun consumeReminderSettings() { state.update { it.copy(reminderSettingsRequested=false) } }
    fun load() {
        if(state.value.busy || loadJob?.isActive == true) return
        state.update { it.copy(loading=true,loadFailed=false) }
        loadJob=viewModelScope.launch {
            try {
                val words=repository.loadWords(); val ratings=repository.ratings(); val events=repository.events()
                state.update { it.copy(loading=false,words=words,ratings=ratings,events=events) }
                resetQueue()
                pendingReminder?.let { pendingReminder=null; openReminder(it.first,it.second) }
            } catch(e: Exception) {
                if(e is CancellationException) throw e
                state.update { it.copy(loading=false,loadFailed=true,message="Could not load local vocabulary. ${e.message}") }
            }
        }
    }
    private fun resetQueue(ids: List<String>? = null) {
        session++
        state.update { s ->
            val selected=ids?.toSet()
            val queue=s.words.filter { s.filter.copy(query="").matches(it,s.ratings[it.id]?.status ?: LearningStatus.NEW) && (selected==null || it.id in selected) }.map(Word::id)
            s.copy(queue=queue,cursor=0,initialCount=queue.size,revealed=false,history=emptyList(),selectedWords=ids!=null,promptOverride=null,navigationRequest=s.navigationRequest+1)
        }
    }
    fun search(query: String) { state.update { it.copy(search=query) } }
    fun filter(filter: WordFilter) { stop(); state.update { it.copy(filter=filter.copy(query="")) }; resetQueue() }
    fun practice() {
        val ids=state.value.matches.map(Word::id)
        stop(); resetQueue(ids); state.update { it.copy(tab=0,detail=null) }
    }
    fun studyAll() { filter(WordFilter(scope=Scope.ALL)); tab(0) }
    fun previewA() { filter(WordFilter(scope=Scope.ALL,letter="A")); state.update { it.copy(tab=0,detail=null,premiumRequested=false) } }
    fun keepPractising() {
        filter(state.value.filter.copy(scope=if(state.value.ratings.values.any { it.status==LearningStatus.LEARNING }) Scope.LEARNING else Scope.REMAINING))
        tab(0)
    }
    fun openReminder(id: String, englishFirst: Boolean) {
        if(state.value.loading) { pendingReminder=id to englishFirst; return }
        if(id !in state.value.byId) return
        stop(); session++
        state.update { it.copy(tab=0,detail=null,filter=WordFilter(scope=Scope.ALL),queue=listOf(id),cursor=0,initialCount=1,history=emptyList(),selectedWords=true,promptOverride=englishFirst,premiumRequested=false,navigationRequest=it.navigationRequest+1) }
    }
    fun shuffle() { stop(); state.update { it.copy(queue=it.queue.drop(it.cursor).shuffled(),cursor=0,revealed=false) } }
    fun tab(tab: Int) { pause(); state.update { it.copy(tab=tab,detail=null) } }
    fun detail(id: String?) { pause(); state.update { it.copy(detail=id) } }
    fun direction() {
        val next=!state.value.showsEnglishFirst
        stop(); preferences.englishFirst=next
        state.update { it.copy(englishFirst=next,promptOverride=null,revealed=false) }
    }
    fun flip() { if(state.value.busy) return; pause(); state.update { it.copy(revealed=!it.revealed) } }
    fun clearMessage() { state.update { it.copy(message=null) } }
    fun message(text: String) { state.update { it.copy(message=text) } }
    fun premium(show: Boolean) { pause(); state.update { it.copy(premiumRequested=show) } }
    fun rate(id: String, status: LearningStatus) {
        if(state.value.busy || id !in state.value.byId) return
        val fromDetail=state.value.detail!=null
        val wasRevealed=state.value.revealed
        val request=session
        stop(); state.update { it.copy(busy=true) }
        viewModelScope.launch {
            try {
                val snapshot=repository.rate(id,status)
                val ratings=repository.ratings(); val events=repository.events()
                state.update { s ->
                    val queue=if(request!=session) s.queue else s.queue.drop(s.cursor).filter { value ->
                        (fromDetail || value!=id) && s.filter.copy(query="").matches(s.byId.getValue(value),ratings[value]?.status ?: LearningStatus.NEW)
                    }
                    s.copy(ratings=ratings,events=events,history=if(!fromDetail && request==session) s.history+snapshot else s.history,queue=queue,cursor=0,revealed=fromDetail && queue.firstOrNull()==s.current?.id && wasRevealed)
                }
            } catch(e: Exception) { if(e is CancellationException) throw e; message(e.message ?: "Rating could not be saved.") }
            finally { state.update { it.copy(busy=false) } }
        }
    }
    fun undo() {
        val snapshot=state.value.undo ?: return
        if(state.value.busy) return
        val request=session
        stop(); state.update { it.copy(busy=true) }
        viewModelScope.launch {
            try {
                repository.undo(snapshot)
                val ratings=repository.ratings(); val events=repository.events()
                state.update { s -> if(request==session) s.copy(ratings=ratings,events=events,history=s.history.dropLast(1),queue=listOf(snapshot.wordId)+s.queue.drop(s.cursor).filter { it!=snapshot.wordId },cursor=0,revealed=false) else s.copy(ratings=ratings,events=events) }
            } catch(e: Exception) { if(e is CancellationException) throw e; message(e.message ?: "Could not undo.") }
            finally { state.update { it.copy(busy=false) } }
        }
    }
    fun speak(word: Word, sentence: Boolean = false) {
        pause()
        if(sentence && !AccessPolicy.hasLesson(word,state.value.access)) return
        speechJob=viewModelScope.launch {
            try { speech.say(if(sentence) word.sentence else word.swedish,"sv-SE",state.value.settings.rate) }
            catch(e: Exception) { if(e !is CancellationException) message(e.message ?: "Speech unavailable.") }
        }
    }
    fun settings(settings: PlaybackSettings) { pause(); preferences.playback=settings; state.update { it.copy(settings=settings) } }
    fun play() {
        if(state.value.busy) return
        if(state.value.playback==PlaybackState.PLAYING) { pause(); return }
        val s=state.value
        if(s.playback==PlaybackState.IDLE || s.playback==PlaybackState.FINISHED) {
            val selected=s.queue.drop(s.cursor).mapNotNull { s.byId[it] }
            if(selected.isEmpty()) return
            if(!AccessPolicy.canPlay(selected,s.access)) { premium(true); return }
            state.update { it.copy(playIds=selected.map(Word::id),playIndex=0,completed=emptySet()) }
        }
        runPlayback()
    }
    private fun runPlayback() {
        val previous=playbackJob
        previous?.cancel(); speechJob?.cancel(); speech.stop()
        state.update { it.copy(playback=PlaybackState.PLAYING,revealed=false) }
        playbackJob=viewModelScope.launch {
            try {
                previous?.join()
                if(state.value.settings.let { it.readPrompt || it.readAnswer || it.readSentence }) speech.beginSession { viewModelScope.launch { pause() } }
                while(true) {
                    val s=state.value
                    val word=s.byId[s.playIds.getOrNull(s.playIndex)] ?: break
                    state.update { it.copy(revealed=false) }
                    PlaybackCycle(speech).play(word,s.showsEnglishFirst,s.settings) { state.update { it.copy(revealed=true) } }
                    state.update { it.copy(completed=it.completed+word.id) }
                    if(s.playIndex==s.playIds.lastIndex) { state.update { it.copy(playback=PlaybackState.FINISHED) }; break }
                    state.update { it.copy(playIndex=it.playIndex+1) }
                }
            } catch(e: Exception) {
                if(e !is CancellationException) state.update { it.copy(playback=PlaybackState.PAUSED,message=e.message ?: "Playback interrupted.") }
            } finally { speech.endSession() }
        }
    }
    fun pause() {
        playbackJob?.cancel(); playbackJob=null; speechJob?.cancel(); speechJob=null; speech.stop(); speech.endSession()
        if(state.value.playback==PlaybackState.PLAYING) state.update { it.copy(playback=PlaybackState.PAUSED) }
    }
    fun step(delta: Int) {
        if(state.value.playIds.isEmpty()) return
        val wasPlaying=state.value.playback==PlaybackState.PLAYING
        pause(); state.update { it.copy(playIndex=(it.playIndex+delta).coerceIn(0,it.playIds.lastIndex),revealed=false,playback=PlaybackState.PAUSED) }
        if(wasPlaying) runPlayback()
    }
    fun stop() { pause(); state.update { it.copy(playback=PlaybackState.IDLE,playIds=emptyList(),playIndex=0,completed=emptySet(),revealed=false) } }
    override fun onCleared() { speech.close() }
}
