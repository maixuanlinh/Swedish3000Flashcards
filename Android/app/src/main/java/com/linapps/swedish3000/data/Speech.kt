package com.linapps.swedish3000.data

import com.linapps.swedish3000.domain.Speech
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.*
import java.util.Locale
import java.util.UUID

/** Created on first audio request; only installed offline voices are selected. */
class DeviceSpeech(private val context: Context): Speech {
    private var engine: TextToSpeech? = null
    private var ready: CompletableDeferred<Boolean>? = null
    @Volatile private var pending: Pair<String, CompletableDeferred<Unit>>? = null
    private var sessionInterruption: (() -> Unit)? = null
    private val audio = context.getSystemService(AudioManager::class.java)
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        .setOnAudioFocusChangeListener { change ->
            if(change < 0) {
                pending?.second?.completeExceptionally(IllegalStateException("Audio was interrupted. Tap Play to restart this card."))
                engine?.stop()
                sessionInterruption?.invoke()
            }
        }.build()
    private suspend fun initialize(): TextToSpeech {
        if (ready == null) {
            val initialized = CompletableDeferred<Boolean>()
            ready = initialized
            engine = TextToSpeech(context.applicationContext) { initialized.complete(it == TextToSpeech.SUCCESS) }
            engine!!.setOnUtteranceProgressListener(object: UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) { pending?.takeIf { it.first == id }?.second?.complete(Unit) }
                @Deprecated("Android callback")
                override fun onError(id: String?) { pending?.takeIf { it.first == id }?.second?.completeExceptionally(IllegalStateException("Speech failed. Check installed voices, or use silent playback.")) }
            })
        }
        check(withTimeout(10_000) { ready!!.await() }) { "Speech is unavailable. Install an offline Swedish voice, or turn off audio." }
        return engine!!
    }
    override suspend fun say(text: String, language: String, rate: Float) {
        val tts = initialize()
        stop()
        val locale = Locale.forLanguageTag(language)
        val voice = tts.voices?.firstOrNull { it.locale.language == locale.language && !it.isNetworkConnectionRequired }
        check(voice != null) { "Install an offline ${locale.displayLanguage} speech voice in Android settings, or turn off audio." }
        check(tts.setVoice(voice) == TextToSpeech.SUCCESS)
        tts.setSpeechRate(rate)
        val id = UUID.randomUUID().toString()
        val done = CompletableDeferred<Unit>()
        pending = id to done
        try {
            check(audio.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio is busy. Try again or use silent playback." }
            check(tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) == TextToSpeech.SUCCESS) { "Speech could not start." }
            withTimeout(90_000) { done.await() }
        } finally {
            if(pending?.first == id) { pending = null; tts.stop(); if(sessionInterruption == null) audio.abandonAudioFocusRequest(focus) }
        }
    }
    override fun beginSession(onInterruption: () -> Unit) {
        sessionInterruption=onInterruption
        check(audio.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio is busy. Try again." }
    }
    override fun endSession() { sessionInterruption=null; audio.abandonAudioFocusRequest(focus) }
    override fun stop() { pending?.second?.cancel(); pending = null; engine?.stop(); if(sessionInterruption == null) audio.abandonAudioFocusRequest(focus) }
    override fun close() { stop(); engine?.shutdown(); engine = null; ready = null }
}
