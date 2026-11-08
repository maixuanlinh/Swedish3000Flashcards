package com.linapps.swedish3000.data

import android.content.Context
import androidx.work.*
import com.linapps.swedish3000.SwedishApplication
import com.linapps.swedish3000.domain.Entitlement
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.IOException
import java.util.UUID

data class OfflineStatus(val media: MediaStatus=MediaStatus(),val active: Boolean=false,val waiting: Boolean=false,
    val wifiOnly: Boolean=true,val error: String?=null,val previewOnly: Boolean=true)

class OfflineDownloads(context: Context,private val media: LessonMedia,private val repository: StudyRepository,
    private val entitlements: EntitlementRepository,scope: CoroutineScope) {
    private val manager=WorkManager.getInstance(context)
    private val preferences=context.getSharedPreferences("offline-lessons",Context.MODE_PRIVATE)
    private val lock=Mutex()
    private val initialized=CompletableDeferred<Unit>()
    private val state=MutableStateFlow(OfflineStatus())
    val status=state.asStateFlow()
    private val prompt=MutableStateFlow(false)
    val premiumPrompt=prompt.asStateFlow()
    var wifiOnlyPreference:Boolean
        get()=preferences.getBoolean("wifiOnly",true)
        set(value) {preferences.edit().putBoolean("wifiOnly",value).apply()}
    suspend fun ensureInitialized() { initialized.await() }
    init {
        scope.launch {
            try { media.configurePreview(repository.loadWords()); initialized.complete(Unit) }
            catch(e: Exception) { initialized.completeExceptionally(e);state.value=OfflineStatus(error="Lesson downloads could not be loaded.") }
        }
        scope.launch {
            combine(media.status,media.previewStatus,manager.getWorkInfosForUniqueWorkFlow(NAME),entitlements.access) { full,free,work,access ->
                val active=work.any { !it.state.isFinished }
                val preview=if(active) preferences.getBoolean("previewOnly",true) else access!=Entitlement.COMPLETE
                OfflineStatus(if(preview) free else full,active,active && work.none { it.state==WorkInfo.State.RUNNING },
                    if(preview) false else preferences.getBoolean("wifiOnly",true),
                    work.firstOrNull { it.state==WorkInfo.State.FAILED && preferences.getString("attempt",null) in it.tags }?.outputData?.getString("error"),preview)
            }.collect { state.value=it }
        }
        scope.launch { entitlements.access.collect { access ->
            if(access!=Entitlement.UNKNOWN) {
                try { ensureInitialized();activate(access) }
                catch(e: CancellationException) { throw e }
                catch(e: Exception) { state.value=state.value.copy(error=e.message) }
            }
        } }
    }
    private suspend fun activate(access: Entitlement) {
        if(access!=Entitlement.COMPLETE) {
            prompt.value=false
            if(!preferences.getBoolean("previewOnly",true)) pause(userInitiated=false)
            media.refresh()
            if(preferences.getBoolean("automaticFree",true) && !media.previewStatus.value.ready && !preferences.getBoolean("paused",false)) start(false,true)
        } else {
            media.refresh()
            if(!preferences.getBoolean("premiumPromptHandled",false) && !media.status.value.ready) prompt.value=true
        }
    }
    suspend fun choosePremium(wifiOnly: Boolean?) {
        check(entitlements.access.value==Entitlement.COMPLETE)
        preferences.edit().putBoolean("premiumPromptHandled",true).apply();prompt.value=false
        if(wifiOnly!=null) start(wifiOnly,false)
    }
    suspend fun start(wifiOnly: Boolean,previewOnly: Boolean=entitlements.access.value!=Entitlement.COMPLETE) = withContext(Dispatchers.IO) { lock.withLock {
        ensureInitialized()
        check(previewOnly || entitlements.access.value==Entitlement.COMPLETE) { "Premium is required to download the complete collection." }
        manager.cancelUniqueWork(NAME).result.get()
        val attempt=UUID.randomUUID().toString()
        preferences.edit().putBoolean("wifiOnly",if(previewOnly) wifiOnlyPreference else wifiOnly).putBoolean("previewOnly",previewOnly)
            .putBoolean("paused",false).putBoolean("automaticFree",true).putString("attempt",attempt).apply()
        if(!previewOnly) preferences.edit().putBoolean("premiumPromptHandled",true).apply()
        media.refresh();media.checkSpace(previewOnly)
        val packs=if(previewOnly) media.previewKeys.map { media.catalog.items.getValue(it).pack }.distinct().map { media.catalog.packs.getValue(it) } else media.missingPacks()
        val requests=packs.map { pack -> OneTimeWorkRequestBuilder<LessonDownloadWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(if(wifiOnly && !previewOnly) NetworkType.UNMETERED else NetworkType.CONNECTED).setRequiresStorageNotLow(true).build())
            .setInputData(workDataOf("pack" to pack.file,"version" to media.catalog.version,"previewOnly" to previewOnly,"attempt" to attempt))
            .addTag(attempt).build() }
        if(requests.isNotEmpty()) {
            var chain=manager.beginUniqueWork(NAME,ExistingWorkPolicy.REPLACE,requests.first())
            requests.drop(1).forEach { chain=chain.then(it) }
            chain.enqueue().result.get()
        }
    } }
    suspend fun pause(userInitiated: Boolean=true) = withContext(Dispatchers.IO) { lock.withLock {
        if(userInitiated) preferences.edit().putBoolean("automaticFree",false).putBoolean("paused",true).apply()
        preferences.edit().putString("attempt",UUID.randomUUID().toString()).apply()
        manager.cancelUniqueWork(NAME).result.get();media.refresh()
    } }
    suspend fun remove() { pause();preferences.edit().putBoolean("premiumPromptHandled",true).apply();prompt.value=false;media.removeDownloads() }
    fun isCurrentAttempt(attempt: String?) = preferences.getString("attempt",null)==attempt
    companion object { const val NAME="offline-lesson-media" }
}

class LessonDownloadWorker(context: Context,parameters: WorkerParameters): CoroutineWorker(context,parameters) {
    override suspend fun doWork(): Result {
        val app=applicationContext as SwedishApplication
        val media=app.media
        return try {
            app.offline.ensureInitialized()
            if(inputData.getString("attempt")!=null && !app.offline.isCurrentAttempt(inputData.getString("attempt"))) return Result.success()
            check(inputData.getString("version")==media.catalog.version) { "Lessons were updated. Please start the download again." }
            val pack=media.catalog.packs.getValue(inputData.getString("pack").orEmpty())
            if(inputData.getBoolean("previewOnly",false)) {
                for(key in media.previewKeys.filter { media.catalog.items.getValue(it).pack==pack.file }) { currentCoroutineContext().ensureActive();media.downloadPreview(key) }
            } else {
                check(app.entitlements.access.value==Entitlement.COMPLETE) { "Premium is required to download the complete collection." }
                media.download(pack)
            }
            Result.success()
        } catch(e: CancellationException) { throw e }
        catch(e: IOException) { if(runAttemptCount<5) Result.retry() else Result.failure(workDataOf("error" to "The connection was interrupted. Tap Download to continue.")) }
        catch(e: Exception) { Result.failure(workDataOf("error" to (e.message ?: "The download could not be completed."))) }
    }
}
