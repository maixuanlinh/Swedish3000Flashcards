package com.linapps.swedish3000.data

import android.content.Context
import androidx.core.content.edit
import com.linapps.swedish3000.domain.PlaybackSettings

interface Preferences {
    var englishFirst: Boolean
    var playback: PlaybackSettings
}
class LocalPreferences(context: Context): Preferences {
    private val prefs = context.getSharedPreferences("study-settings",Context.MODE_PRIVATE)
    override var englishFirst: Boolean
        get() = prefs.getBoolean("englishFirst",true)
        set(value) { prefs.edit { putBoolean("englishFirst",value) } }
    override var playback: PlaybackSettings
        get() = PlaybackSettings(prefs.getInt("recall",3),prefs.getInt("answer",2),prefs.getBoolean("promptAudio",true),prefs.getBoolean("answerAudio",true),prefs.getBoolean("sentenceAudio",true),prefs.getFloat("rate",1f))
        set(value) { prefs.edit { putInt("recall",value.recallSeconds); putInt("answer",value.answerSeconds); putBoolean("promptAudio",value.readPrompt); putBoolean("answerAudio",value.readAnswer); putBoolean("sentenceAudio",value.readSentence); putFloat("rate",value.rate) } }
}
