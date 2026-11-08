@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.linapps.swedish3000.ui

import android.Manifest
import android.app.Activity
import android.app.TimePickerDialog
import android.content.*
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.linapps.swedish3000.BuildConfig
import com.linapps.swedish3000.data.PlayEntitlementRepository
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private const val Privacy="https://yki.essaykingapp.com/swedish3000/privacy.html"
private const val SupportURL="https://yki.essaykingapp.com/swedish3000/support.html"
private fun openURL(context: Context,url: String) { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(url))) } }
private tailrec fun Context.activity(): Activity?=when(this) { is Activity -> this;is ContextWrapper -> baseContext.activity();else -> null }
@Composable internal fun Support(onClose: ()->Unit) {
    val context=LocalContext.current
    Panel("Help and privacy",onClose) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            SectionCard {
                Eyebrow("Help")
                TextButton(onClick={ openURL(context,SupportURL) }) { Text("Support and frequently asked questions") }
                TextButton(onClick={ openURL(context,"mailto:support@essaykingapp.com?subject=3000%20Swedish%20Words%20support") }) { Text("Email support") }
                Text("support@essaykingapp.com",fontSize=12.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Privacy")
                TextButton(onClick={ openURL(context,Privacy) }) { Text("Privacy policy") }
                Text("Study progress and imported artwork are stored in this app on your device. Restoring Premium restores purchase access, not your learning history.",fontSize=14.sp,color=Muted)
                Text("Lesson images and audio load from our hosting when needed. Offline downloads stay on this phone. Your learning history and personal artwork are not uploaded when lessons load.",fontSize=14.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Pronunciation")
                Text("Swedish and English use prepared computer-generated recordings. No speech voice installation is needed. If a pronunciation sounds wrong, please email the word and sentence to support.",fontSize=14.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("About 3000 Swedish Words")
                Text("An independent Swedish vocabulary learning app from Linapps.",fontSize=14.sp,color=Muted)
                Text("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",fontSize=12.sp,color=Muted)
            }
        }
    }
}
@Composable internal fun Premium(s: StudyUiState,vm: StudyViewModel,onClose: ()->Unit) {
    val context=LocalContext.current;val billing=LocalApp.current.entitlements as? PlayEntitlementRepository
    val price=billing?.price?.collectAsStateWithLifecycle()?.value;val message=billing?.message?.collectAsStateWithLifecycle()?.value;val busy=billing?.busy?.collectAsStateWithLifecycle()?.value ?: false
    Panel("Premium",onClose) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(22.dp)) {
            Text(if(s.access==Entitlement.COMPLETE) "Your complete Swedish collection" else "Remember Swedish with the full picture",fontFamily=FontFamily.Serif,fontSize=31.sp,fontWeight=FontWeight.Medium)
            Text("One purchase. All 3,000 complete lessons. No subscription or ads.",color=Muted)
            s.words.firstOrNull { it.english=="apple" }?.let { Artwork(it,Modifier.fillMaxWidth().height(210.dp)) }
            PremiumFeature("photo","A memory cue for every word","All 3,000 illustrations and English–Swedish memory links.")
            PremiumFeature("words","Examples you understand","Every Swedish example, English translation, and sentence pronunciation.")
            PremiumFeature("play","Study without tapping","Automatic playback for any letter or word selection.")
            Text("The 211-word A set includes complete illustrated lessons for free. Basic cards, word pronunciation and learning progress stay free across all 3,000 words. Premium also includes word reminders.",fontSize=14.sp,color=Muted)
            Text("Restore on Android using the same purchasing Google Account. Apple purchases are separate. Learning progress stays on this device and isn’t restored with the purchase.",fontSize=12.sp,color=Muted)
            TextButton(onClick={ openURL(context,Privacy) }) { Text("Privacy policy") }
            message?.let { Text(it,fontSize=14.sp,color=Forest) }
            if(billing?.configured!=true) Text("Purchases are not available in this installation. Explore all 211 complete A-set lessons for free.",fontSize=14.sp,color=Muted)
        }
        Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            if(s.access==Entitlement.COMPLETE) FilledAction("Premium is unlocked",onClose)
            else if(price!=null) FilledAction("Unlock Premium · $price",{ context.activity()?.let {billing?.purchase(it)} },enabled=!busy)
            TextButton(onClick={billing?.restore()},enabled=!busy && billing!=null,modifier=Modifier.fillMaxWidth()) { Text(if(busy) "Checking purchases…" else "Restore Purchases") }
            TextButton(onClick={ vm.previewA();onClose() },modifier=Modifier.fillMaxWidth()) { Text("Try the complete A set free") }
        }
    }
}
@Composable private fun PremiumFeature(icon: String,title: String,body: String) {
    Row(horizontalArrangement=Arrangement.spacedBy(14.dp)) { Symbol(icon,Modifier.size(40.dp).background(Sage,RoundedCornerShape(12.dp)).padding(8.dp));Column(verticalArrangement=Arrangement.spacedBy(5.dp)) { Text(title,fontWeight=FontWeight.SemiBold);Text(body,fontSize=14.sp,color=Muted) } }
}
@Composable internal fun ReminderOptions(s: StudyUiState,vm: StudyViewModel,onClose: ()->Unit) {
    if(s.access!=Entitlement.COMPLETE) { LaunchedEffect(Unit) {onClose();vm.premium(true)};return }
    val app=LocalApp.current;val context=LocalContext.current;val scope=rememberCoroutineScope()
    var draft by remember { mutableStateOf(app.reminders.settings) }
    var busy by remember {mutableStateOf(false)};var message by remember {mutableStateOf<String?>(null)}
    val words=remember(draft,s.words,s.ratings) {ReminderPlan.eligible(s.words,s.ratings,draft)}
    fun save() {scope.launch {busy=true;try {if(app.reminders.save(draft,s.access)) onClose() else message="Notifications are disabled. Allow them in Android settings, then save again."} catch(e:Exception) {if(e is CancellationException) throw e;message=e.message} finally {busy=false}}}
    fun sample() {message="Sample scheduled in 5 seconds.";app.background.launch {runCatching {app.reminders.sample(draft,s.access)}.onFailure {withContext(Dispatchers.Main) {message=it.message}}}}
    var permissionAction by remember {mutableStateOf("save")}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {granted -> if(granted) {if(permissionAction=="save") save() else sample()} else message="Notifications were not allowed. You can enable them in Android settings."}
    fun authorize(action:String) {if(Build.VERSION.SDK_INT>=33 && !app.reminders.allowed()) {permissionAction=action;permission.launch(Manifest.permission.POST_NOTIFICATIONS)} else if(action=="save") save() else sample()}
    Panel("Word reminders",onClose) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            SectionCard {
                Toggle("Word reminders",draft.enabled) {draft=draft.copy(enabled=it)}
                Text("A little Swedish throughout your day. Works offline, even when 3000 Swedish Words is closed.",fontSize=12.sp,color=Muted)
                if(!app.reminders.allowed()) TextButton(onClick={context.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,context.packageName))}) {Text("Open notification settings")}
            }
            SectionCard {
                Eyebrow("Your schedule")
                var frequencies by remember {mutableStateOf(false)}
                Box {TextButton(onClick={frequencies=true},modifier=Modifier.testTag("reminders.frequency")) {Text(draft.frequency.title)};DropdownMenu(frequencies,{frequencies=false}) {ReminderFrequency.entries.forEach {frequency -> DropdownMenuItem(text={Text(frequency.title)},onClick={draft=draft.copy(frequency=frequency,times=frequency.presetTimes ?: draft.times);frequencies=false})}} }
                if(draft.frequency.interval==null) {
                    draft.times.forEachIndexed {index,minute -> Row(verticalAlignment=Alignment.CenterVertically) {
                        Text("Reminder ${index+1}",Modifier.weight(1f),fontSize=14.sp)
                        ReminderTime(minute,"reminders.time.$index") {changed -> draft=draft.copy(frequency=ReminderFrequency.CUSTOM,times=draft.times.toMutableList().also {it[index]=changed})}
                        if(draft.times.size>1) IconAction("close","Remove reminder ${index+1}",{draft=draft.copy(frequency=ReminderFrequency.CUSTOM,times=draft.times.filterIndexed {i,_ -> i!=index})})
                    } }
                }
                Text("${draft.dailyMinutes.size} reminders per day · repeats daily",fontSize=13.sp,color=Muted,modifier=Modifier.testTag("reminders.dailyCount"))
                Text("Reminders repeat with no end date. Words reshuffle automatically.",fontSize=12.sp,color=Muted)
                if(draft.frequency.interval==null && draft.times.size<48) TextButton(onClick={var minute=((draft.times.maxOrNull() ?: 300)+240)%1440;while(minute in draft.times) minute=(minute+30)%1440;draft=draft.copy(frequency=ReminderFrequency.CUSTOM,times=draft.times+minute)}) {Text("Add time")}
            }
            SectionCard {
                Eyebrow("Sleep hours")
                Toggle("Pause while sleeping",draft.sleepEnabled) {draft=draft.copy(sleepEnabled=it)}
                if(draft.sleepEnabled) {
                    Row(verticalAlignment=Alignment.CenterVertically) {Text("Sleep from",Modifier.weight(1f));ReminderTime(draft.sleepStart,"reminders.sleepStart") {draft=draft.copy(sleepStart=it)}}
                    Row(verticalAlignment=Alignment.CenterVertically) {Text("Wake at",Modifier.weight(1f));ReminderTime(draft.sleepEnd,"reminders.sleepEnd") {draft=draft.copy(sleepEnd=it)}}
                }
                Text("No word reminders are sent during these hours. Times follow your device’s local time zone.",fontSize=12.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Word selection")
                ReminderPool.entries.forEach {pool -> FilterChip(selected=draft.pool==pool,onClick={draft=draft.copy(pool=pool)},label={Text(pool.title)})}
                var letters by remember {mutableStateOf(false)}
                Box {TextButton(onClick={letters=true}) {Text("Starting letter: ${draft.letter ?: "All letters"}")};DropdownMenu(letters,{letters=false}) {
                    DropdownMenuItem(text={Text("All letters")},onClick={draft=draft.copy(letter=null);letters=false})
                    ('A'..'Z').forEach {char -> DropdownMenuItem(text={Text(char.toString())},onClick={draft=draft.copy(letter=char.toString());letters=false})}
                }}
                Text("${words.size} words · shuffled without immediate repeats",fontSize=12.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Notification")
                ReminderPrompt.entries.forEach {prompt -> FilterChip(selected=draft.prompt==prompt,onClick={draft=draft.copy(prompt=prompt)},label={Text(prompt.title)})}
                Toggle("Artwork thumbnail",draft.showArtwork) {draft=draft.copy(showArtwork=it)}
                Toggle("Notification sound",draft.sound) {draft=draft.copy(sound=it)}
                Text("Artwork may include the answer. Turn it off for a recall challenge. Notifications use a short chime, not spoken audio.",fontSize=12.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Preview")
                val word=words.firstOrNull {it.english=="apple"} ?: words.firstOrNull()
                if(word!=null) {val text=ReminderPlan.text(word,draft.prompt);Text(text.first,fontWeight=FontWeight.SemiBold);Text(text.second,fontSize=14.sp);if(draft.showArtwork) Artwork(word,Modifier.size(64.dp),thumbnail=true)}
                else Text("No words match. Try another group or letter.",color=Muted)
                TextButton(onClick={authorize("sample")},enabled=!busy && words.isNotEmpty()) {Text("Send sample in 5 seconds")}
            }
            Text("Android may delay reminders to save battery. Your notification and Do Not Disturb settings control alerts. Opening a reminder never marks a word as Known.",fontSize=12.sp,color=Muted)
        }
        Column(Modifier.padding(16.dp)) {message?.let {Text(it,color=Forest,fontSize=12.sp)};FilledAction(if(busy) "Updating…" else "Save reminders",{if(draft.enabled) authorize("save") else save()},Modifier.testTag("reminders.save"),enabled=!busy && (!draft.enabled || words.isNotEmpty() && draft.dailyMinutes.isNotEmpty()))}
    }
}
@Composable private fun ReminderTime(minute:Int,tag:String,onChange:(Int)->Unit) {
    val context=LocalContext.current
    TextButton(onClick={TimePickerDialog(context,{_,hour,min -> onChange(hour*60+min)},minute/60,minute%60,android.text.format.DateFormat.is24HourFormat(context)).show()},modifier=Modifier.testTag(tag)) {Text("%02d:%02d".format(minute/60,minute%60))}
}
@Composable internal fun ArtworkEditor(word: Word,vm: StudyViewModel,onClose: ()->Unit,onChanged: ()->Unit,onPreview: ()->Unit) {
    val app=LocalApp.current;val context=LocalContext.current;val scope=rememberCoroutineScope()
    val version=LocalArtworkVersion.current
    val history=remember(word.id,version) { app.artwork.history(word.id) }
    var prompt by remember(word.id) { mutableStateOf(history.prompts.firstOrNull()?.text ?: word.editorPrompt) }
    var hook by remember(word.id) { mutableStateOf(history.prompts.firstOrNull()?.memoryHook ?: app.artwork.active(word.id)?.memoryHook ?: word.editorMemoryHook) }
    var busy by remember { mutableStateOf(false) };var message by remember { mutableStateOf<String?>(null) }
    fun action(block: suspend ()->Unit) { scope.launch { busy=true;try { block();onChanged() } catch(e: Exception) { if(e is CancellationException) throw e;vm.message(e.message ?: "Artwork could not be saved.") } finally { busy=false } } }
    fun import(uri: Uri,source: String) { action { app.artwork.importImage(word,uri,prompt,hook,source);message="Your image is now on this card." } }
    val photo=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { it?.let { uri -> import(uri,"Photos") } }
    val file=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { it?.let { uri -> import(uri,"Files") } }
    val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri -> if(uri!=null) action { val bytes=app.artwork.export(word);withContext(Dispatchers.IO) { context.contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: error("The export could not be saved.") };message="Word artwork exported." } }
    Panel("Artwork · ${word.swedish}",onClose) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            Artwork(word,Modifier.fillMaxWidth().height(190.dp).clickable(enabled=!busy,onClick=onPreview))
            SectionCard {
                Eyebrow("Create in ChatGPT")
                OutlinedTextField(value=prompt,onValueChange={ prompt=it },label={ Text("Image prompt") },modifier=Modifier.fillMaxWidth().heightIn(min=190.dp).testTag("artwork.prompt"),enabled=!busy)
                TextButton(onClick={ action { app.artwork.savePrompt(word.id,prompt,hook);context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("Artwork prompt",prompt));message="Prompt copied." } },enabled=!busy && prompt.isNotBlank()) { Text("Copy prompt") }
                TextButton(onClick={ action { app.artwork.savePrompt(word.id,prompt,hook);context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,prompt),"Share prompt")) } },enabled=!busy && prompt.isNotBlank()) { Text("Share prompt") }
                TextButton(onClick={ openURL(context,"https://chatgpt.com/") }) { Text("Open ChatGPT") }
                Text("Copy the prompt, generate your image in ChatGPT, then save it to Photos or Files.",fontSize=12.sp,color=Muted)
            }
            SectionCard {
                Eyebrow("Add your image")
                OutlinedTextField(value=hook,onValueChange={ hook=it },label={ Text("Memory hook (optional)") },modifier=Modifier.fillMaxWidth(),enabled=!busy)
                TextButton(onClick={ photo.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },enabled=!busy) { Text("Choose from Photos") }
                TextButton(onClick={ file.launch(arrayOf("image/*")) },enabled=!busy) { Text("Choose from Files") }
                if(busy) Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)) { CircularProgressIndicator(Modifier.size(20.dp));Text("Saving…") }
                message?.let { Text(it,fontSize=12.sp,color=Forest) }
            }
            if(history.images.isNotEmpty()) SectionCard {
                Eyebrow("Image history")
                history.images.forEach { revision ->
                    TextButton(onClick={ action { app.artwork.activate(word.id,revision.id);prompt=revision.prompt;hook=revision.memoryHook;message="Earlier image restored." } },enabled=!busy,modifier=Modifier.fillMaxWidth()) {
                        Column(Modifier.weight(1f)) { Text(Instant.parse(revision.createdAt).atZone(ZoneId.systemDefault()).format(DateTimeFormatter.ofPattern("d MMM, HH:mm")));Text("${revision.bytes/1024} KB · ${revision.source}",fontSize=12.sp,color=Muted) };if(revision.active) Symbol("check")
                    }
                }
                TextButton(onClick={ export.launch("${word.id}-artwork.json") },enabled=!busy) { Text("Export word artwork") }
                TextButton(onClick={ action { app.artwork.activate(word.id,null);message="Original card restored. Images kept in history." } },enabled=!busy) { Text("Use original card") }
            }
            if(history.prompts.isNotEmpty()) SectionCard {
                Eyebrow("Prompt history")
                history.prompts.forEach { saved -> TextButton(onClick={ prompt=saved.text;hook=saved.memoryHook;message="Saved prompt restored." },enabled=!busy) { Column { Text(saved.createdAt.take(16).replace('T',' '),fontSize=12.sp);Text(saved.text,maxLines=2,fontSize=14.sp) } } }
            }
        }
    }
}
@Composable internal fun ArtworkPackImporter(s: StudyUiState,vm: StudyViewModel,onClose: ()->Unit,onChanged: ()->Unit) {
    val app=LocalApp.current;val scope=rememberCoroutineScope();var busy by remember { mutableStateOf(false) };var message by remember { mutableStateOf<String?>(null) }
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if(uri!=null) scope.launch {
        busy=true
        try { check(s.access==Entitlement.COMPLETE);val (imported,skipped)=app.artwork.importPack(uri,s.words);onChanged();message="$imported images imported · $skipped already in your collection." }
        catch(e: Exception) { if(e is CancellationException) throw e;vm.message(e.message ?: "The artwork pack could not be imported.") }
        finally { busy=false }
    } }
    Panel("Import artwork pack",onClose) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            SectionTitle("Add prepared illustrations")
            Text("Choose a prepared artwork pack with up to 500 words, smaller than 150 MB. Previous images stay in your history.",color=Muted)
            FilledAction(if(busy) "Importing…" else "Choose artwork pack",{ picker.launch(arrayOf("application/json","application/octet-stream")) },enabled=!busy)
            message?.let { Text(it,color=Forest) }
        }
    }
}
