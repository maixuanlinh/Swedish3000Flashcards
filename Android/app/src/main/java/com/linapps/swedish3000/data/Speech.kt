package com.linapps.swedish3000.data

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import com.linapps.swedish3000.domain.Speech
import kotlinx.coroutines.*
import java.io.File
import java.util.UUID

/** Plays our prerecorded clips. No Android TTS engine or voice installation is used. */
class RecordedSpeech(context: Context, private val media: LessonMedia): Speech {
    private val audio=context.getSystemService(AudioManager::class.java)
    private val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
    private var player: MediaPlayer?=null
    private var pending: CompletableDeferred<Unit>?=null
    private var sessionInterruption: (() -> Unit)?=null
    private val cacheDirectory=context.cacheDir
    private val focus=AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        .setAudioAttributes(attributes).setOnAudioFocusChangeListener { change ->
            if(change<0) {
                pending?.completeExceptionally(IllegalStateException("Audio was interrupted. Tap Play to restart this card."))
                player?.let { runCatching { it.pause() } }
                sessionInterruption?.invoke()
            }
        }.build()
    override suspend fun say(text: String,language: String,rate: Float) {
        stop()
        val bytes=try { media.load(recordingKey(language,text)) }
        catch(e: CancellationException) { throw e }
        catch(e: Exception) { throw IllegalStateException("Connect to the internet to hear this lesson, or download lessons for offline study. ${e.message.orEmpty()}",e) }
        currentCoroutineContext().ensureActive()
        val temporary=File(cacheDirectory,"pronunciation-${UUID.randomUUID()}.mp3")
        val done=CompletableDeferred<Unit>()
        val current=MediaPlayer()
        player=current;pending=done
        try {
            withContext(Dispatchers.IO) { temporary.writeBytes(bytes) }
            check(audio.requestAudioFocus(focus)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio is busy. Try again." }
            current.setAudioAttributes(attributes)
            current.setDataSource(temporary.path)
            current.setOnPreparedListener {
                if(player!==it) return@setOnPreparedListener
                runCatching {
                    it.playbackParams=it.playbackParams.setSpeed(rate.coerceIn(.5f,1.5f)).setPitch(1f)
                    it.start()
                }.onFailure { error -> done.completeExceptionally(error) }
            }
            current.setOnCompletionListener { done.complete(Unit) }
            current.setOnErrorListener { _,_,_ -> done.completeExceptionally(IllegalStateException("This recording could not be played. Please try again."));true }
            current.prepareAsync()
            withTimeout(90_000) { done.await() }
        } finally {
            if(player===current) { pending=null;player=null;current.release();if(sessionInterruption==null) audio.abandonAudioFocusRequest(focus) }
            temporary.delete()
        }
    }
    override fun beginSession(onInterruption: ()->Unit) {
        sessionInterruption=onInterruption
        check(audio.requestAudioFocus(focus)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio is busy. Try again." }
    }
    override fun endSession() { sessionInterruption=null;audio.abandonAudioFocusRequest(focus) }
    override fun stop() {
        pending?.cancel();pending=null
        player?.release();player=null
        if(sessionInterruption==null) audio.abandonAudioFocusRequest(focus)
    }
    override fun close() { stop();endSession() }
}
