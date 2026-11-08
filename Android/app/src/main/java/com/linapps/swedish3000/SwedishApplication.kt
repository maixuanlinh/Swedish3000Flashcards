package com.linapps.swedish3000

import android.app.Application
import com.linapps.swedish3000.data.*
import kotlinx.coroutines.*

open class SwedishApplication: Application() {
    val repository by lazy { LocalStudyRepository(this) }
    open val entitlements: EntitlementRepository by lazy { PlayEntitlementRepository(this) }
    val preferences: Preferences by lazy { LocalPreferences(this) }
    val artwork by lazy { ArtworkRepository(this) }
    val media by lazy { LessonMedia(this) }
    val offline by lazy { OfflineDownloads(this,media,repository,entitlements,background) }
    val reminders by lazy { Reminders(this,repository,artwork,media) }
    val background = CoroutineScope(SupervisorJob()+Dispatchers.IO)
    override fun onCreate() { super.onCreate();offline }
}
