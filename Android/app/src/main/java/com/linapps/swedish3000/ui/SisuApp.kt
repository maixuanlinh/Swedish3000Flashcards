@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.linapps.swedish3000.ui

import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.linapps.swedish3000.SwedishApplication
import com.linapps.swedish3000.domain.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable fun SisuApp(vm: StudyViewModel) {
    val s by vm.uiState.collectAsStateWithLifecycle()
    val app=LocalContext.current.applicationContext as SwedishApplication
    var panel by rememberSaveable { mutableStateOf<String?>(null) }
    var zoom by rememberSaveable { mutableStateOf<String?>(null) }
    var artWord by rememberSaveable { mutableStateOf<String?>(null) }
    var artworkVersion by remember { mutableIntStateOf(0) }
    var reminderVersion by remember { mutableIntStateOf(0) }
    val owner=LocalLifecycleOwner.current
    val latestAccess by rememberUpdatedState(s.access)
    LaunchedEffect(s.navigationRequest) { panel=null;artWord=null;zoom=null }
    DisposableEffect(owner) {
        val observer=LifecycleEventObserver { _, event ->
            if(event==Lifecycle.Event.ON_PAUSE) vm.pause()
            if(event==Lifecycle.Event.ON_RESUME) { vm.refreshAccess();reminderVersion++ }
        }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(s.access,s.loading,reminderVersion) {
        if(!s.loading && latestAccess!=Entitlement.UNKNOWN) runCatching { app.reminders.refresh(latestAccess,force=true) }.onFailure { vm.message(it.message ?: "Reminders could not be refreshed.") }
    }
    LaunchedEffect(s.access) { if(s.access!=Entitlement.COMPLETE) { artWord=artWord?.takeIf { id -> s.byId[id]?.let { AccessPolicy.hasLesson(it,s.access) }==true };zoom=zoom?.takeIf { id -> s.byId[id]?.let { AccessPolicy.hasLesson(it,s.access) }==true } } }
    LaunchedEffect(s.reminderSettingsRequested) { if(s.reminderSettingsRequested) { panel="reminders";vm.consumeReminderSettings() } }
    MaterialTheme(colorScheme=lightColorScheme(primary=Forest,secondary=Forest,background=Cream,surface=Color.White,onBackground=Ink,onSurface=Ink,onSurfaceVariant=Muted,outline=Color(0xFFDCE0D6))) {
        CompositionLocalProvider(LocalApp provides app,LocalArtworkVersion provides artworkVersion) {
            BackHandler(s.detail!=null) { vm.detail(null) }
            Scaffold(containerColor=Cream,bottomBar={
                Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal=44.dp).padding(top=4.dp,bottom=2.dp),contentAlignment=Alignment.Center) {
                    Row(Modifier.widthIn(max=400.dp).fillMaxWidth().background(Color.White.copy(alpha=.85f),RoundedCornerShape(50)).padding(3.dp)) {
                        listOf("Study","Words","Progress").forEachIndexed { index,label ->
                            Column(Modifier.weight(1f).heightIn(min=48.dp).clip(RoundedCornerShape(50)).background(if(s.tab==index) Sage.copy(alpha=.7f) else Color.Transparent).selectable(selected=s.tab==index,role=Role.Tab,onClick={ vm.tab(index) }).padding(vertical=4.dp).testTag("tab.$label"),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(1.dp)) {
                                Symbol(listOf("study","words","progress")[index],color=if(s.tab==index) Forest else Ink)
                                Text(label,fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.SemiBold,color=if(s.tab==index) Forest else Ink)
                            }
                        }
                    }
                }
            }) { padding ->
                Box(Modifier.fillMaxSize().padding(padding),contentAlignment=Alignment.TopCenter) {
                    if(s.loading) CircularProgressIndicator(Modifier.align(Alignment.Center))
                    else if(s.loadFailed) Column(Modifier.align(Alignment.Center).padding(24.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) { Text("Vocabulary could not be loaded.");FilledAction("Retry",vm::load) }
                    else when(s.tab) {
                        0 -> Study(s,vm,{ vm.pause();panel="filters" },{ vm.pause();panel="playback" })
                        1 -> Words(s,vm,{ vm.pause();panel="filters" },{ if(s.access==Entitlement.COMPLETE) panel="pack" else vm.premium(true) })
                        else -> Progress(s,vm,{ panel=it },reminderVersion)
                    }
                }
            }
            s.detail?.let { id -> s.byId[id]?.let { word ->
                Panel("Word detail",{ vm.detail(null) },action={ TextButton(onClick={ if(AccessPolicy.hasLesson(word,s.access)) artWord=id else vm.premium(true) }) { Text("Artwork") } }) {
                    Detail(word,s,vm,{ zoom=id })
                }
            } }
            when(panel) {
                "filters" -> Filters(s,onDismiss={ panel=null },onApply={ vm.filter(it);panel=null })
                "playback" -> PlaybackOptions(s.settings,onDismiss={ panel=null },onChange=vm::settings,onStart={ panel=null;vm.play() })
                "reminders" -> ReminderOptions(s,vm,onClose={ panel=null;reminderVersion++ })
                "support" -> Support { panel=null }
                "pack" -> ArtworkPackImporter(s,vm,onClose={ panel=null },onChanged={ artworkVersion++ })
            }
            artWord?.let { id -> s.byId[id]?.let { word -> ArtworkEditor(word,vm,onClose={ artWord=null },onChanged={ artworkVersion++ },onPreview={ zoom=id }) } }
            zoom?.let { id -> s.byId[id]?.takeIf { AccessPolicy.hasLesson(it,s.access) }?.let { ZoomArtwork(it) { zoom=null } } }
            if(s.premiumRequested) Premium(s,vm) { vm.premium(false) }
            s.message?.let { AlertDialog(onDismissRequest=vm::clearMessage,title={ Text("Couldn’t complete that action") },text={ Text(it) },confirmButton={ TextButton(onClick=vm::clearMessage) { Text("OK") } }) }
        }
    }
}
@Composable private fun Study(s: StudyUiState,vm: StudyViewModel,filters: ()->Unit,settings: ()->Unit) {
    var menu by remember { mutableStateOf(false) }
    Column(Modifier.widthIn(max=520.dp).fillMaxSize().padding(horizontal=18.dp).padding(top=8.dp,bottom=8.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Row(Modifier.fillMaxWidth().heightIn(min=44.dp),verticalAlignment=Alignment.CenterVertically) {
            Row(Modifier.weight(1f).heightIn(min=44.dp).clickable(onClick=filters).testTag("study.filters"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                Symbol("filter");Text(s.filterTitle,fontSize=14.sp,fontWeight=FontWeight.Medium,color=Forest,maxLines=1,overflow=TextOverflow.Ellipsis)
            }
            Text(if(s.playback!=PlaybackState.IDLE) "${s.completed.size} / ${s.playIds.size}" else "${s.initialCount-s.queue.size} / ${s.initialCount}",fontSize=11.sp,fontFamily=FontFamily.Monospace,color=Muted,modifier=Modifier.testTag("session.count"))
            IconAction("undo","Undo last swipe",vm::undo,enabled=s.undo!=null && !s.busy,modifier=Modifier.size(40.dp).testTag("review.undo"))
            Box {
                IconAction(if(s.playback==PlaybackState.PLAYING) "pause" else "play",if(s.playback==PlaybackState.PLAYING) "Pause automatic study" else "Play automatic study",vm::play,enabled=s.current!=null && !s.busy,modifier=Modifier.size(40.dp).testTag("study.autoplay"))
                if(s.access!=Entitlement.COMPLETE && s.queue.any { s.byId[it]?.initial!="A" }) Symbol("lock",Modifier.size(12.dp).align(Alignment.TopEnd))
            }
            Box {
                IconAction("more","Study options",{ menu=true },modifier=Modifier.size(36.dp).testTag("study.options"))
                DropdownMenu(expanded=menu,onDismissRequest={ menu=false }) {
                    DropdownMenuItem(text={ Text("Playback settings") },onClick={ menu=false;settings() })
                    DropdownMenuItem(text={ Text(if(s.showsEnglishFirst) "Show Swedish first" else "Show English first") },onClick={ menu=false;vm.direction() })
                    DropdownMenuItem(text={ Text("Shuffle this session") },onClick={ menu=false;vm.shuffle() })
                }
            }
        }
        val word=s.current
        if(word==null) {
            Column(Modifier.weight(1f).fillMaxWidth().background(Color.White,RoundedCornerShape(27.dp)).padding(24.dp).verticalScroll(rememberScrollState()),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(20.dp)) {
                Spacer(Modifier.height(60.dp));Symbol("check",Modifier.size(50.dp))
                Text(if(s.history.isEmpty()) "No words in this group" else "Practice complete",fontFamily=FontFamily.Serif,fontSize=27.sp,textAlign=TextAlign.Center)
                Text(if(s.history.isEmpty()) "Change your filters to start practising." else "You reviewed ${s.history.size} words. Your progress is saved.",textAlign=TextAlign.Center,color=Muted)
                FilledAction("Filters",filters)
                TextButton(onClick=vm::studyAll) { Text("Study all ${s.words.size} words") }
            }
        } else {
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                val height=maxHeight
                var drag by remember(word.id) { mutableFloatStateOf(0f) }
                val dragX by animateFloatAsState(drag,label="Card drag")
                val compact=height<450.dp
                val scrollAnswer=height<320.dp || LocalDensity.current.fontScale>1.3f
                Box(Modifier.matchParentSize().padding(horizontal=10.dp).offset(y=7.dp).background(Sage,RoundedCornerShape(27.dp)))
                Column(Modifier.fillMaxSize().graphicsLayer { translationX=dragX;rotationZ=dragX/35 }.clip(RoundedCornerShape(27.dp)).background(Color.White).pointerInput(word.id,s.busy) {
                    detectHorizontalDragGestures(onDragStart={ vm.pause();drag=0f },onHorizontalDrag={ change,amount -> change.consume();drag+=amount },onDragCancel={ drag=0f },onDragEnd={ if(!s.busy && kotlin.math.abs(drag)>75.dp.toPx()) vm.rate(word.id,if(drag>0) LearningStatus.KNOWN else LearningStatus.LEARNING);drag=0f })
                }.testTag("study.card")) {
                    if(!s.revealed) {
                        Column(Modifier.weight(1f).fillMaxWidth().clickable(enabled=!s.busy,onClick=vm::flip).padding(24.dp).testTag("card.reveal"),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                            Eyebrow(if(s.showsEnglishFirst) "English" else "Swedish");Spacer(Modifier.height(16.dp))
                            Text(if(s.showsEnglishFirst) word.english else word.swedish,fontSize=42.sp,fontWeight=FontWeight.Medium,fontFamily=FontFamily.Serif,textAlign=TextAlign.Center,color=Ink,modifier=Modifier.testTag("card.prompt"))
                        }
                    } else {
                        Column(Modifier.weight(1f).fillMaxWidth().then(if(scrollAnswer) Modifier.verticalScroll(rememberScrollState()) else Modifier).padding(horizontal=20.dp).padding(top=if(compact) 14.dp else 20.dp,bottom=10.dp),verticalArrangement=Arrangement.spacedBy(if(compact) 8.dp else 12.dp)) {
                            Row(verticalAlignment=Alignment.CenterVertically) {
                                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                                    Eyebrow(if(s.showsEnglishFirst) "Swedish" else "English")
                                    Text(if(s.showsEnglishFirst) word.swedish else word.english,fontFamily=FontFamily.Serif,fontSize=if(compact) 28.sp else 34.sp,color=Ink,modifier=Modifier.testTag("card.answer"))
                                }
                                IconAction("sound","Play Swedish pronunciation",{ vm.speak(word) },modifier=Modifier.background(Sage,RoundedCornerShape(50)))
                                Spacer(Modifier.width(8.dp))
                                IconAction("detail","Open word details",{ vm.detail(word.id) },modifier=Modifier.background(Sage,RoundedCornerShape(50)).testTag("card.detail"))
                            }
                            if(AccessPolicy.hasLesson(word,s.access)) {
                                Text(word.sentence,fontSize=if(compact) 16.sp else 18.sp,fontWeight=FontWeight.Medium,color=Ink,modifier=Modifier.testTag("card.sentence"))
                                Text(word.sentenceEnglish,fontSize=if(compact) 13.sp else 15.sp,color=Muted,modifier=Modifier.testTag("card.translation"))
                                Artwork(word,Modifier.fillMaxWidth().then(if(scrollAnswer) Modifier.height(240.dp) else Modifier.weight(1f)).testTag("card.artwork"))
                            } else LockedLesson(compact=true) { vm.premium(true) }
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(54.dp).background(Sage.copy(alpha=.45f)).clickable(enabled=!s.busy,onClick=vm::flip).semantics { contentDescription=if(s.revealed) "Show prompt" else "Flip card" }.testTag("card.flip"),contentAlignment=Alignment.Center) { Symbol("flip",Modifier.size(25.dp)) }
                }
                if(kotlin.math.abs(drag)>24) Text(if(drag>0) "KNOWN" else "LEARNING",fontWeight=FontWeight.Bold,color=if(drag>0) Forest else Clay,modifier=Modifier.padding(18.dp).background(Color.White,RoundedCornerShape(12.dp)).padding(12.dp))
            }
            Spacer(Modifier.height(1.dp))
            if(s.playback==PlaybackState.IDLE) Ratings(s.busy) { vm.rate(word.id,it) }
            else Row(Modifier.fillMaxWidth().background(Sage,RoundedCornerShape(17.dp)),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.SpaceEvenly) {
                IconAction("prev","Previous card",{ vm.step(-1) },enabled=s.playIndex>0)
                IconAction(if(s.playback==PlaybackState.PLAYING) "pause" else "play",if(s.playback==PlaybackState.FINISHED) "Replay automatic study" else "Pause or resume automatic study",vm::play,modifier=Modifier.weight(1f))
                IconAction("next","Next card",{ vm.step(1) },enabled=s.playIndex<s.playIds.lastIndex)
                IconAction("stop","Return to manual study",vm::stop)
            }
        }
    }
}
@Composable internal fun Ratings(busy: Boolean,onRate: (LearningStatus)->Unit) {
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(12.dp)) {
        Button(onClick={ onRate(LearningStatus.LEARNING) },enabled=!busy,colors=ButtonDefaults.buttonColors(containerColor=Peach,contentColor=Clay),shape=RoundedCornerShape(17.dp),contentPadding=PaddingValues(horizontal=10.dp,vertical=14.dp),modifier=Modifier.weight(1f).heightIn(min=54.dp).testTag("review.learning")) { Symbol("left",Modifier.size(18.dp),Clay);Spacer(Modifier.width(5.dp));Text("Still learning",fontSize=14.sp) }
        Button(onClick={ onRate(LearningStatus.KNOWN) },enabled=!busy,colors=ButtonDefaults.buttonColors(containerColor=Forest,contentColor=Color.White),shape=RoundedCornerShape(17.dp),contentPadding=PaddingValues(horizontal=10.dp,vertical=14.dp),modifier=Modifier.weight(1f).heightIn(min=54.dp).testTag("review.known")) { Text("I know it",fontSize=14.sp);Spacer(Modifier.width(7.dp));Symbol("check",Modifier.size(18.dp),Color.White) }
    }
}
@Composable internal fun LockedLesson(compact: Boolean=false,open: ()->Unit) {
    Column(Modifier.fillMaxWidth().background(Sage.copy(alpha=.5f),RoundedCornerShape(20.dp)).clickable(onClick=open).padding(if(compact) 18.dp else 28.dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Symbol("lock",Modifier.size(28.dp));Text("Unlock the complete lesson",fontWeight=FontWeight.SemiBold,color=Forest)
        Text("Illustration, memory hook and example sentence",fontSize=14.sp,color=Muted,textAlign=TextAlign.Center)
        Text("Explore Premium",color=Forest,fontWeight=FontWeight.SemiBold)
    }
}
private val imageCache=object: LruCache<String,ImageBitmap>(24*1024*1024) { override fun sizeOf(key: String,value: ImageBitmap)=value.width*value.height*4 }
@Composable internal fun Artwork(word: Word,modifier: Modifier=Modifier,thumbnail: Boolean=false) {
    val app=LocalApp.current;val revision=remember(word.id,LocalArtworkVersion.current) { app.artwork.active(word.id) }
    val personal=revision?.let { if(thumbnail) it.thumbnail else it.filename }
    val bundled=if(thumbnail) word.thumbnail else word.image
    val key=personal ?: bundled
    val bitmap by produceState<ImageBitmap?>(null,key) {
        value=withContext(Dispatchers.IO) { imageCache.get(key) ?: runCatching {
            personal?.let { BitmapFactory.decodeFile(app.artwork.file(it).path)?.asImageBitmap() }
                ?: app.assets.open("BundledArtwork/$bundled").use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
        }.getOrNull()?.also { imageCache.put(key,it) } }
    }
    Box(modifier.clip(RoundedCornerShape(16.dp)).background(Cream),contentAlignment=Alignment.Center) {
        bitmap?.let { Image(it,contentDescription="Illustration for ${word.swedish}",contentScale=ContentScale.Fit,modifier=Modifier.fillMaxSize()) } ?: Symbol("photo",Modifier.size(30.dp))
    }
}
@Composable private fun ZoomArtwork(word: Word,onDismiss: ()->Unit) {
    var scale by remember { mutableFloatStateOf(1f) };var offset by remember { mutableStateOf(Offset.Zero) }
    Panel(word.swedish,onDismiss) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(1.dp)),contentAlignment=Alignment.Center) {
            val density=LocalDensity.current
            val width=with(density) { maxWidth.toPx() };val height=with(density) { maxHeight.toPx() }
            val side=minOf(width,height)
            val transform=rememberTransformableState { zoom,pan,_ ->
                scale=(scale*zoom).coerceIn(1f,4f)
                val maxX=((side*scale-width)/2).coerceAtLeast(0f);val maxY=((side*scale-height)/2).coerceAtLeast(0f)
                offset=Offset((offset.x+pan.x).coerceIn(-maxX,maxX),(offset.y+pan.y).coerceIn(-maxY,maxY))
            }
            Artwork(word,Modifier.size(with(density) { side.toDp() }).graphicsLayer(scaleX=scale,scaleY=scale,translationX=offset.x,translationY=offset.y).transformable(transform).pointerInput(Unit) { detectTapGestures(onDoubleTap={ scale=if(scale>1) 1f else 2.5f;offset=Offset.Zero }) })
        }
        Text("Pinch or double-tap to zoom",color=Muted,modifier=Modifier.padding(16.dp))
    }
}
