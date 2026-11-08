package com.linapps.swedish3000.ui

import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.*

internal fun mediaSize(bytes: Long) = if(bytes>=1_000_000_000) String.format(java.util.Locale.ENGLISH,"%.1f GB",bytes/1e9) else "${(bytes+999_999)/1_000_000} MB"

@Composable internal fun OfflineOptions(vm: StudyViewModel,onClose: ()->Unit) {
    val app=LocalApp.current
    val status by app.offline.status.collectAsStateWithLifecycle()
    val study by vm.uiState.collectAsStateWithLifecycle()
    val premium=study.access==com.linapps.swedish3000.domain.Entitlement.COMPLETE
    val full by app.media.status.collectAsStateWithLifecycle()
    val free by app.media.previewStatus.collectAsStateWithLifecycle()
    val media=if(premium) full else free
    val activeDownload=status.active && (!premium || !status.previewOnly)
    val scope=rememberCoroutineScope()
    var wifiOnly by remember { mutableStateOf(app.offline.wifiOnlyPreference) }
    var busy by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf(false) }
    fun action(block: suspend ()->Unit) {
        busy=true
        scope.launch {
            try { block() }
            catch(e: CancellationException) { throw e }
            catch(e: Exception) { vm.message(e.message ?: "The download could not be completed.") }
            finally { busy=false }
        }
    }
    Panel("Offline study",onClose) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            SectionTitle("Learn wherever you are")
            Text("Download images and audio to study without an internet connection. Downloads are optional and occupy storage space on your phone.",color=Muted)
            SectionCard {
                Text("Images and pronunciation",fontWeight=FontWeight.SemiBold)
                if(media.loading) CircularProgressIndicator()
                else {
                    Text("${if(premium) "Complete collection" else "Free A-set lessons"}: ${mediaSize(media.totalBytes)}",modifier=Modifier.testTag("offline.total"))
                    Text("${mediaSize(media.installedBytes)} included with the app · ${mediaSize(media.storageUsedBytes)} downloaded",fontSize=12.sp,color=Muted)
                    if(media.ready) Text("Available offline",color=Forest,modifier=Modifier.testTag("offline.ready"))
                    else {
                        LinearProgressIndicator(progress={ if(media.totalBytes==0L) 0f else (media.storageUsedBytes+media.installedBytes).toFloat()/media.totalBytes },modifier=Modifier.fillMaxWidth())
                        Text(if(activeDownload) { if(status.waiting) "Waiting to download${if(status.wifiOnly) " over Wi-Fi" else ""}…" else "Downloading lessons…" } else "${mediaSize(media.remainingBytes)} left to download",fontSize=12.sp,color=Muted)
                    }
                    media.error?.let { Text(it,color=Muted) }
                    status.error?.let { Text(it,color=Muted) }
                }
                Text("Swedish and English recordings are included. There is no need to install a speech voice on your phone.",fontSize=12.sp,color=Muted)
                Text("Downloading keeps your current lesson access. Premium lessons still require Premium.",fontSize=12.sp,color=Muted)
            }
            if(premium && status.active && status.previewOnly) Text("Your Free lessons are downloading in the background. You can start the complete collection at any time.",fontSize=12.sp,color=Muted)
            if(!media.ready) {
                if(premium) Toggle("Download over Wi-Fi only",wifiOnly,enabled=!activeDownload && !busy) {wifiOnly=it;app.offline.wifiOnlyPreference=it}
                else Text("Your 211 Free A-set lessons download automatically over Wi-Fi or mobile data. You can pause at any time.",fontSize=12.sp,color=Muted)
                Text("Keep the app installed to retain downloaded lessons. You can pause and continue later; completed downloads are kept.",fontSize=12.sp,color=Muted)
                FilledAction(if(activeDownload) "Pause download" else if(media.storageUsedBytes>0) "Continue download" else if(premium) "Download complete collection" else "Download free A set",
                    { action { if(activeDownload) app.offline.pause() else app.offline.start(if(premium) wifiOnly else false) } },
                    Modifier.testTag("offline.download"),enabled=!busy && !media.loading && media.error==null)
            }
            if(media.storageUsedBytes>0) TextButton(onClick={ confirmRemove=true },enabled=!busy,modifier=Modifier.testTag("offline.remove")) { Text("Remove offline downloads · ${mediaSize(media.storageUsedBytes)}") }
            Text("Keep studying while downloads continue in the background. Android manages background timing.",fontSize=12.sp,color=Muted)
            Text("Removing downloads keeps your learning progress, personal artwork and the lessons included with the app. Online lessons may use mobile data and recently used media may be cached temporarily.",fontSize=12.sp,color=Muted)
        }
    }
    if(confirmRemove) AlertDialog(onDismissRequest={ confirmRemove=false },title={ Text("Remove offline downloads?") },
        text={ Text("This frees ${mediaSize(media.storageUsedBytes)}. Your learning progress and personal artwork will stay on this phone.") },
        confirmButton={ TextButton(onClick={ confirmRemove=false;action { app.offline.remove() } }) { Text("Remove downloads") } },
        dismissButton={ TextButton(onClick={ confirmRemove=false }) { Text("Keep downloads") } })
}

@Composable internal fun PremiumDownloadChoice(vm: StudyViewModel) {
    val app=LocalApp.current
    val status by app.offline.status.collectAsStateWithLifecycle()
    val scope=rememberCoroutineScope()
    val fullCollection by app.media.status.collectAsStateWithLifecycle()
    var busy by remember {mutableStateOf(false)}
    fun choose(wifiOnly:Boolean?) {if(busy) return;busy=true;scope.launch {try {app.offline.choosePremium(wifiOnly)} catch(e:Exception) {if(e is CancellationException) throw e;vm.message(e.message ?: "Could not start the download.")} finally {busy=false}}}
    Panel("Offline lessons",{choose(null)}) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            Symbol("download",Modifier.size(48.dp))
            SectionTitle("Learn anywhere, even offline")
            Text("Save images and audio for all 3,000 lessons. You can keep studying while they download.",color=Muted)
            Text("About ${mediaSize(fullCollection.remainingBytes)} to download · uses device storage",color=Muted,fontSize=13.sp)
            FilledAction("Download on Wi-Fi",{choose(true)},Modifier.testTag("offlinePrompt.wifi"),enabled=!busy)
            FilledAction("Download now",{choose(false)},Modifier.testTag("offlinePrompt.now"),enabled=!busy)
            Text("Download now uses your current connection, including mobile data.",fontSize=13.sp,color=Muted)
            TextButton(onClick={choose(null)},enabled=!busy,modifier=Modifier.fillMaxWidth().testTag("offlinePrompt.later")) {Text("Later")}
            Text("You can manage downloads anytime in Settings.",fontSize=13.sp,color=Muted)
        }
    }
}
