package com.linapps.swedish3000.data

import android.content.Context
import androidx.core.content.edit
import com.linapps.swedish3000.domain.*
import org.json.JSONObject
import org.json.JSONArray

interface Preferences {
    var englishFirst: Boolean
    var playback: PlaybackSettings
    var session: SavedStudySession?
        get() = null
        set(value) {}
}
class LocalPreferences(context: Context): Preferences {
    private val prefs = context.getSharedPreferences("study-settings",Context.MODE_PRIVATE)
    override var englishFirst: Boolean
        get() = prefs.getBoolean("englishFirst",true)
        set(value) { prefs.edit { putBoolean("englishFirst",value) } }
    override var playback: PlaybackSettings
        get() = PlaybackSettings(prefs.getInt("recall",3),prefs.getInt("answer",2),prefs.getBoolean("promptAudio",true),prefs.getBoolean("answerAudio",true),prefs.getBoolean("sentenceAudio",true),prefs.getFloat("rate",1f))
        set(value) { prefs.edit { putInt("recall",value.recallSeconds); putInt("answer",value.answerSeconds); putBoolean("promptAudio",value.readPrompt); putBoolean("answerAudio",value.readAnswer); putBoolean("sentenceAudio",value.readSentence); putFloat("rate",value.rate) } }
    override var session: SavedStudySession?
        get() = runCatching {
            val j=JSONObject(prefs.getString("saved-session-v1",null) ?: return null)
            val a=j.getJSONArray("ids")
            require(a.length()<=3000)
            val ids=(0 until a.length()).map { a.getString(it) };require(ids.size==ids.toSet().size)
            val filter=WordFilter(scope=Scope.valueOf(j.getString("scope")),letter=j.optString("letter").takeIf { it.isNotBlank() },topic=j.optString("topic").takeIf { it.isNotBlank() })
            SavedStudySession(filter,ids,j.getInt("initialCount").coerceIn(ids.size,3000),j.optBoolean("selected"),if(j.has("prompt")) j.getBoolean("prompt") else null)
        }.getOrNull()
        set(value) {
            prefs.edit {
                if(value==null) remove("saved-session-v1")
                else putString("saved-session-v1",JSONObject().put("ids",JSONArray(value.ids)).put("initialCount",value.initialCount)
                    .put("scope",value.filter.scope.name).put("letter",value.filter.letter ?: "").put("topic",value.filter.topic ?: "")
                    .put("selected",value.selectedWords).apply { value.promptOverride?.let { put("prompt",it) } }.toString())
            }
        }

}
