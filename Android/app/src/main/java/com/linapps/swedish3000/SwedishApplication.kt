package com.linapps.swedish3000

import android.app.Application
import com.linapps.swedish3000.data.*
import kotlinx.coroutines.*

class SwedishApplication: Application() {
    val repository by lazy { LocalStudyRepository(this) }
    val entitlements: EntitlementRepository by lazy { PlayEntitlementRepository(this) }
    val preferences: Preferences by lazy { LocalPreferences(this) }
    val artwork by lazy { ArtworkRepository(this) }
    val reminders by lazy { Reminders(this,repository,artwork) }
    val background = CoroutineScope(SupervisorJob()+Dispatchers.IO)
}
