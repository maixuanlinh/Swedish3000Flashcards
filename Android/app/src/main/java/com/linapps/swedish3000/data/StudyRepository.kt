package com.linapps.swedish3000.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

interface StudyRepository {
    suspend fun loadWords(): List<Word>
    suspend fun ratings(): Map<String, Rating>
    suspend fun events(): List<ReviewEvent>
    suspend fun rate(wordId: String, status: LearningStatus): UndoRating
    suspend fun undo(snapshot: UndoRating)
}

class LocalStudyRepository(context: Context) : StudyRepository {
    private val assets = context.applicationContext.assets
    private val db = ProgressDatabase(context.applicationContext)
    override suspend fun loadWords(): List<Word> = withContext(Dispatchers.IO) {
        fun array(name: String) = JSONArray(assets.open(name).bufferedReader().use { it.readText() })
        fun JSONArray.rows() = (0 until length()).map { getJSONObject(it) }
        val catalog = JSONObject(assets.open("catalog3000.json").bufferedReader().use { it.readText() })
        val seeds = array("starter100.json").rows().associateBy { it.getString("id") }
        val examples = array("examples3000.json").rows().associateBy { it.getString("id") }
        val art = array("BundledArtwork/manifest.json").rows().associateBy { it.getString("wordID") }
        val briefs = JSONObject(assets.open("artworkBriefs.json").bufferedReader().use { it.readText() })
        val rows = catalog.getJSONArray("entries").rows()
        val ids = rows.map { it.getString("id") }.toSet()
        val count = catalog.getInt("entryCount")
        require(count in 1..3000 && rows.size == count && ids.size == count)
        require(examples.keys == ids && art.keys.all { it in ids } && seeds.keys.all { it in ids })
        rows.map { row ->
            val id = row.getString("id")
            val seed = seeds[id]
            val example = examples.getValue(id)
            val image = art[id]
            Word(id, row.getInt("sourceID"), seed?.getString("english") ?: row.getString("english"),
                seed?.getString("swedish") ?: row.getString("swedish"), example.getString("sentence"),
                example.getString("sentenceEnglish"), seed?.getString("topic") ?: "Vocabulary",
                image?.getString("filename") ?: "", image?.getString("thumbnailFilename") ?: "",
                image?.getString("memoryHook") ?: briefs.getJSONObject(id).getString("memoryHook"), image?.getString("prompt") ?: briefs.getJSONObject(id).getString("prompt"),
                briefs.getJSONObject(id).getString("prompt")+"\nWord ID (metadata): $id\nSource dictionary alternatives (context only; do not print): ${seed?.getString("swedish") ?: row.getString("swedish")}\nSwedish example: ${example.getString("sentence")}",
                briefs.getJSONObject(id).getString("memoryHook"))
                .also { require(it.sentence.isNotBlank() && it.sentenceEnglish.isNotBlank()) }
        }.sortedWith(compareBy<Word> { it.sortKey }.thenBy { it.sourceId })
    }
    override suspend fun ratings(): Map<String, Rating> = withContext(Dispatchers.IO) {
        buildMap {
            db.readableDatabase.rawQuery("SELECT word_id,status,count,last_reviewed FROM ratings", null).use { c ->
                while (c.moveToNext()) put(c.getString(0), Rating(LearningStatus.valueOf(c.getString(1)), c.getInt(2), if(c.isNull(3)) null else c.getLong(3)))
            }
        }
    }
    override suspend fun events(): List<ReviewEvent> = withContext(Dispatchers.IO) {
        buildList {
            db.readableDatabase.rawQuery("SELECT id,word_id,status,at FROM events ORDER BY at,id", null).use { c ->
                while(c.moveToNext()) add(ReviewEvent(c.getLong(0), c.getString(1), LearningStatus.valueOf(c.getString(2)), c.getLong(3)))
            }
        }
    }
    override suspend fun rate(wordId: String, status: LearningStatus): UndoRating = withContext(Dispatchers.IO) {
        val sql = db.writableDatabase
        sql.beginTransaction()
        try {
            val previous = readRating(sql, wordId)
            val at = System.currentTimeMillis()
            val values = android.content.ContentValues().apply { put("word_id",wordId);put("status",status.name);put("at",at) }
            val eventId = sql.insertOrThrow("events", null, values)
            sql.execSQL("INSERT OR REPLACE INTO ratings(word_id,status,count,last_reviewed) VALUES(?,?,?,?)", arrayOf(wordId,status.name,previous.count+1,at))
            sql.setTransactionSuccessful()
            UndoRating(wordId, previous, ReviewEvent(eventId,wordId,status,at))
        } finally { sql.endTransaction() }
    }
    override suspend fun undo(snapshot: UndoRating) = withContext(Dispatchers.IO) {
        val sql = db.writableDatabase
        sql.beginTransaction()
        try {
            val current = readRating(sql, snapshot.wordId)
            val latest = sql.rawQuery("SELECT id FROM events WHERE word_id=? ORDER BY id DESC LIMIT 1", arrayOf(snapshot.wordId)).use { if(it.moveToFirst()) it.getLong(0) else null }
            check(latest == snapshot.event.id && current.count == snapshot.previous.count+1 && current.lastReviewed == snapshot.event.at) {
                "This word was rated again. Its newer progress has been kept."
            }
            sql.execSQL("INSERT OR REPLACE INTO ratings(word_id,status,count,last_reviewed) VALUES(?,?,?,?)", arrayOf(snapshot.wordId,snapshot.previous.status.name,snapshot.previous.count,snapshot.previous.lastReviewed))
            sql.delete("events", "id=?", arrayOf(snapshot.event.id.toString()))
            sql.setTransactionSuccessful()
        } finally { sql.endTransaction() }
    }
    private fun readRating(sql: SQLiteDatabase, id: String) = sql.rawQuery("SELECT status,count,last_reviewed FROM ratings WHERE word_id=?", arrayOf(id)).use {
        if (it.moveToFirst()) Rating(LearningStatus.valueOf(it.getString(0)),it.getInt(1),if(it.isNull(2)) null else it.getLong(2)) else Rating()
    }
}
private class ProgressDatabase(context: Context): SQLiteOpenHelper(context, "swedish-progress.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE ratings(word_id TEXT PRIMARY KEY,status TEXT NOT NULL,count INTEGER NOT NULL,last_reviewed INTEGER)")
        db.execSQL("CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT,word_id TEXT NOT NULL,status TEXT NOT NULL,at INTEGER NOT NULL)")
        db.execSQL("CREATE INDEX events_word ON events(word_id,id)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { error("Add a non-destructive migration before raising the database version") }
}
