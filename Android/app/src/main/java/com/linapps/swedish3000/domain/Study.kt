package com.linapps.swedish3000.domain

import java.text.Normalizer
import java.util.Locale

enum class LearningStatus { NEW, LEARNING, KNOWN }
enum class Scope(val title: String) {
    REMAINING("New & learning"), NEW("New words"), LEARNING("Still learning"), KNOWN("Known words"), ALL("All words");
    fun includes(status: LearningStatus) = when (this) {
        ALL -> true
        NEW -> status == LearningStatus.NEW
        REMAINING -> status != LearningStatus.KNOWN
        LEARNING -> status == LearningStatus.LEARNING
        KNOWN -> status == LearningStatus.KNOWN
    }
}
data class Word(
    val id: String, val sourceId: Int, val english: String, val swedish: String,
    val sentence: String, val sentenceEnglish: String, val topic: String,
    val image: String, val thumbnail: String, val memoryHook: String, val prompt: String,
    val editorPrompt: String = prompt, val editorMemoryHook: String = memoryHook
) {
    val sortKey = dictionaryKey(english)
    val initial = sortKey.take(1).uppercase(Locale.ROOT)
    val searchText = "$english\n$swedish\n$sentence\n$sentenceEnglish".lowercase(Locale.ROOT)
}
fun dictionaryKey(text: String): String = Normalizer.normalize(
    text.substringBefore('(').substringBefore(" / "), Normalizer.Form.NFD
).filter { Character.getType(it) != Character.NON_SPACING_MARK.toInt() }
    .lowercase(Locale.ROOT).filter { it.isLetterOrDigit() }

data class WordFilter(val query: String = "", val scope: Scope = Scope.REMAINING, val letter: String? = null, val topic: String? = null) {
    fun matches(word: Word, status: LearningStatus) = scope.includes(status) &&
        (letter == null || word.initial == letter) && (topic == null || word.topic == topic) &&
        word.searchText.contains(query.trim().lowercase(Locale.ROOT))
}
data class Rating(val status: LearningStatus = LearningStatus.NEW, val count: Int = 0, val lastReviewed: Long? = null)
data class ReviewEvent(val id: Long, val wordId: String, val status: LearningStatus, val at: Long)
data class UndoRating(val wordId: String, val previous: Rating, val event: ReviewEvent)

/** Store adapter publishes verified access; content/UI never depends on BillingClient. */
enum class Entitlement { UNKNOWN, FREE, COMPLETE }
object AccessPolicy {
    fun hasLesson(word: Word, entitlement: Entitlement) = entitlement == Entitlement.COMPLETE || word.initial == "A"
    fun canPlay(words: List<Word>, entitlement: Entitlement) = words.all { hasLesson(it, entitlement) }
}
