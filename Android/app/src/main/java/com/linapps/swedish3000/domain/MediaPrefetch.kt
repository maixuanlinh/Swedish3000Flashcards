package com.linapps.swedish3000.domain

/** Prepare only the active lesson and next three cards; never the full library. */
internal fun prefetchLessons(words: List<Word>, access: Entitlement): List<Pair<String,String>> = buildList {
    words.take(4).forEach { word ->
        add("audio/sv-SE" to word.swedish)
        if(AccessPolicy.hasLesson(word,access)) {
            add("audio/en-US" to word.english)
            add("audio/sv-SE" to word.sentence)
            add("image" to word.image)
            add("image" to word.thumbnail)
        }
    }
}.distinct()
