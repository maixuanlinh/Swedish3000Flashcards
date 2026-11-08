@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.linapps.swedish3000.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.linapps.swedish3000.domain.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.time.*
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

@Composable internal fun Words(s: StudyUiState,vm: StudyViewModel,filters: ()->Unit,import: ()->Unit) = TopicWords(s,vm,filters,import)
@Composable internal fun Detail(word: Word,s: StudyUiState,vm: StudyViewModel,onZoom: ()->Unit) {
    val app=LocalApp.current
    val hook=remember(word.id,LocalArtworkVersion.current) { app.artwork.active(word.id)?.memoryHook ?: word.memoryHook }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
        Box(Modifier.fillMaxWidth(),contentAlignment=Alignment.CenterEnd) { StatusBadge(s.ratings[word.id]?.status ?: LearningStatus.NEW) }
        Row(verticalAlignment=Alignment.CenterVertically) {
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(7.dp)) { Text(word.swedish,fontSize=39.sp,fontFamily=FontFamily.Serif,modifier=Modifier.testTag("detail.swedish"));Text(word.english,fontSize=20.sp,color=Muted) }
            IconAction("sound","Play Swedish word",{ vm.speak(word) },modifier=Modifier.background(Sage,RoundedCornerShape(50)))
        }
        if(AccessPolicy.hasLesson(word,s.access)) {
            Column(horizontalAlignment=Alignment.CenterHorizontally) {
                Artwork(word,Modifier.fillMaxWidth().height(340.dp).testTag("detail.artworkImage"))
                IconAction("detail","Open full-screen illustration",onZoom,modifier=Modifier.background(Sage,RoundedCornerShape(50)).testTag("detail.image"))
            }
            if(hook.isNotBlank()) Column(verticalArrangement=Arrangement.spacedBy(8.dp)) { Eyebrow("Memory hook");Text(hook,color=Ink,modifier=Modifier.testTag("detail.memoryHook")) }
            SectionCard {
                Row(verticalAlignment=Alignment.CenterVertically) { Box(Modifier.weight(1f)) { Eyebrow("In a sentence") };IconAction("sound","Play Swedish sentence",{ vm.speak(word,true) }) }
                Text(word.sentence,fontFamily=FontFamily.Serif,fontSize=25.sp,modifier=Modifier.testTag("detail.sentence"))
                Text(word.sentenceEnglish,color=Muted,fontSize=14.sp,modifier=Modifier.testTag("detail.translation"))
            }
        } else LockedLesson { vm.premium(true) }
        Eyebrow("Your learning")
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            LearningStatus.entries.forEach { status ->
                val selected=(s.ratings[word.id]?.status ?: LearningStatus.NEW)==status
                Button(onClick={ vm.rate(word.id,status) },enabled=!s.busy,shape=RoundedCornerShape(14.dp),colors=ButtonDefaults.buttonColors(containerColor=if(selected) Forest else Sage,contentColor=if(selected) Color.White else Forest),contentPadding=PaddingValues(horizontal=5.dp,vertical=14.dp),modifier=Modifier.weight(1f).testTag("detail.status.${status.name.lowercase()}")) { Text(when(status) { LearningStatus.NEW->"New";LearningStatus.LEARNING->"Learning";LearningStatus.KNOWN->"Known" },fontSize=13.sp) }
            }
        }
    }
}
@Composable internal fun Progress(s: StudyUiState,vm: StudyViewModel,open: (String)->Unit,reminderVersion: Int) {
    val known=s.ratings.values.count { it.status==LearningStatus.KNOWN };val learning=s.ratings.values.count { it.status==LearningStatus.LEARNING }
    val today=LocalDate.now();val zone=ZoneId.systemDefault()
    val byDay=remember(s.events,today,zone) { s.events.groupingBy { Instant.ofEpochMilli(it.at).atZone(zone).toLocalDate() }.eachCount() }
    val days=(6L downTo 0L).map { today.minusDays(it) }
    Column(Modifier.widthIn(max=624.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(22.dp),verticalArrangement=Arrangement.spacedBy(23.dp)) {
        Row(verticalAlignment=Alignment.Top) {
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(6.dp)) { Eyebrow("Your Swedish, growing");Text("Your progress",fontFamily=FontFamily.Serif,fontSize=31.sp,fontWeight=FontWeight.SemiBold) }
        }
        s.savedSession?.takeIf {it.ids.isNotEmpty()}?.let { saved ->
            SectionCard {
                Text("Continue your last session",fontWeight=FontWeight.SemiBold,color=Forest)
                Text(saved.title,fontFamily=FontFamily.Serif,fontSize=22.sp)
                Text("${saved.ids.size} words remaining · your place is saved",fontSize=13.sp,color=Muted)
                FilledAction("Resume studying",vm::resumeSession,Modifier.testTag("progress.resume"))
            }
        }
        val learningWords=s.words.filter {s.ratings[it.id]?.status==LearningStatus.LEARNING}
        SectionCard {
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {SectionTitle("Currently learning");Text("${learningWords.size}",fontSize=24.sp,fontWeight=FontWeight.SemiBold)}
            Text("Saved on this device, ready next time.",fontSize=13.sp,color=Muted)
            learningWords.take(5).forEach { word ->
                Row(Modifier.fillMaxWidth().clickable {vm.detail(word.id)}.padding(vertical=7.dp).testTag("learning.${word.id}"),verticalAlignment=Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {Text(word.swedish,fontSize=18.sp,fontWeight=FontWeight.SemiBold);Text(word.english,fontSize=13.sp,color=Muted)};Symbol("chevron")
                }
            }
            if(learningWords.isEmpty()) Text("Swipe a study card left to add a word here.",fontSize=13.sp,color=Muted)
            else FilledAction(if(learningWords.size==1) "Practise this learning word" else "Practise all ${learningWords.size} learning words",vm::learningWords,Modifier.testTag("progress.learningWords"))
        }
        Row(Modifier.fillMaxWidth().background(Forest,RoundedCornerShape(27.dp)).padding(25.dp),verticalAlignment=Alignment.CenterVertically) {
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(11.dp)) {
                Text("WORDS YOU KNOW",fontSize=10.sp,fontWeight=FontWeight.Bold,letterSpacing=1.5.sp,color=Color.White.copy(alpha=.7f))
                Text("$known",fontSize=58.sp,fontFamily=FontFamily.Serif,color=Color.White,modifier=Modifier.testTag("progress.known"))
                Text("of ${s.words.size} words",color=Color.White.copy(alpha=.8f),fontSize=14.sp)
            }
            Box(Modifier.size(105.dp),contentAlignment=Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) { drawArc(Color.White.copy(alpha=.15f),-90f,360f,false,style=androidx.compose.ui.graphics.drawscope.Stroke(9.dp.toPx()));drawArc(Color(0xFFFECC00),-90f,360f*known/s.words.size.coerceAtLeast(1),false,style=androidx.compose.ui.graphics.drawscope.Stroke(9.dp.toPx(),cap=androidx.compose.ui.graphics.StrokeCap.Round)) }
                Column(horizontalAlignment=Alignment.CenterHorizontally) { Text("${known*100/s.words.size.coerceAtLeast(1)}%",fontSize=26.sp,fontWeight=FontWeight.SemiBold,color=Color.White);Text("familiar",fontSize=11.sp,color=Color.White.copy(alpha=.7f)) }
            }
        }
        Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
            Metric("Learning",learning,"flip",Clay,Peach,Modifier.weight(1f));Metric("New words",s.words.size-known-learning,"sparkle",Forest,Sage,Modifier.weight(1f))
        }
        SectionCard {
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) { Text("Your week",fontWeight=FontWeight.SemiBold);Text("${days.sumOf { byDay[it] ?: 0 }} reviews",fontSize=12.sp,color=Muted) }
            val maximum=days.maxOf { byDay[it] ?: 0 }.coerceAtLeast(1)
            Row(Modifier.fillMaxWidth().height(127.dp),verticalAlignment=Alignment.Bottom,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
                days.forEach { day -> val count=byDay[day] ?: 0
                    Column(Modifier.weight(1f).semantics { contentDescription="$day: $count reviews" },horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(8.dp)) {
                        Text("$count",fontSize=10.sp,color=Muted)
                        Box(Modifier.fillMaxWidth().height((count.toFloat()/maximum*90).coerceAtLeast(5f).dp).background(if(day==today) Forest else Sage,RoundedCornerShape(7.dp)))
                        Text(day.dayOfWeek.getDisplayName(TextStyle.NARROW,Locale.getDefault()),fontSize=12.sp,color=Muted)
                    }
                }
            }
        }
        SectionCard { Text("Today’s practice",fontWeight=FontWeight.SemiBold);Text("${byDay[today] ?: 0} reviews · goal: 10",color=Muted,fontSize=14.sp) }
        FilledAction("Keep practising →",vm::keepPractising)
    }
}
@Composable private fun Metric(title: String,value: Int,icon: String,color: Color,background: Color,modifier: Modifier) {
    Column(modifier.background(background,RoundedCornerShape(22.dp)).padding(18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) { Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) { Symbol(icon,color=color);Text("$value",fontSize=24.sp,fontWeight=FontWeight.SemiBold,color=color) };Text(title,color=color,fontSize=14.sp) }
}
@Composable internal fun Filters(s: StudyUiState,onDismiss: ()->Unit,onApply: (WordFilter)->Unit) {
    var filter by remember { mutableStateOf(s.filter) }
    val words=remember(s.words,s.tab,s.search) { if(s.tab==1) s.words.filter { it.searchText.contains(searchKey(s.search.trim())) } else s.words }
    val counts=remember(filter,s.ratings,words) { words.filter { filter.copy(query="",letter=null).matches(it,s.ratings[it.id]?.status ?: LearningStatus.NEW) }.groupingBy { it.initial }.eachCount() }
    Panel("Filters",onDismiss,closeLabel="Cancel",action={ TextButton(onClick={ filter=WordFilter(scope=Scope.ALL) },modifier=Modifier.testTag("filter.reset")) { Text("Reset") } }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                Eyebrow("Learning status")
                Scope.entries.forEach { scope ->
                    Row(Modifier.fillMaxWidth().background(if(filter.scope==scope) Sage else Color.White,RoundedCornerShape(12.dp)).clickable { filter=filter.copy(scope=scope) }.padding(13.dp).testTag("filter.scope.${scope.name.lowercase()}"),verticalAlignment=Alignment.CenterVertically) { Text(scope.title,color=Forest,modifier=Modifier.weight(1f));if(filter.scope==scope) Symbol("check") else Text("○",color=Forest) }
                }
            }
            Eyebrow("Topic")
            Row(Modifier.fillMaxWidth().background(if(filter.topic==null) Sage else Color.White,RoundedCornerShape(14.dp)).clickable {filter=filter.copy(topic=null)}.padding(14.dp).testTag("filter.topic.all"),verticalAlignment=Alignment.CenterVertically) {Text("All topics",color=Forest,modifier=Modifier.weight(1f));if(filter.topic==null) Symbol("check")}
            TopicCardGrid(VocabularyTopic.entries,words,s.ratings,filter.topic,"filter.topic") {topic -> filter=filter.copy(topic=topic.title)}
            Text("A word can belong to several topics. Its progress is shared everywhere.",fontSize=12.sp,color=Muted)
            Eyebrow("English starts with")
            Row(Modifier.fillMaxWidth().background(if(filter.letter==null) Sage else Color.White,RoundedCornerShape(12.dp)).clickable { filter=filter.copy(letter=null) }.padding(13.dp).testTag("letter.all"),verticalAlignment=Alignment.CenterVertically) { Text("All letters",color=Forest,modifier=Modifier.weight(1f));Text("${counts.values.sum()}",color=Muted);if(filter.letter==null) Symbol("check",Modifier.padding(start=8.dp)) }
            Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                ('A'..'Z').toList().chunked(6).forEach { row ->
                    Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                        row.forEach { char -> val letter=char.toString();val selected=filter.letter==letter
                            Column(Modifier.weight(1f).heightIn(min=52.dp).background(if(selected) Forest else Color.White,RoundedCornerShape(12.dp)).clickable { filter=filter.copy(letter=letter) }.padding(vertical=7.dp).semantics { contentDescription="$letter, ${counts[letter] ?: 0} words" }.testTag("letter.$letter"),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy(3.dp)) { Text(letter,fontWeight=FontWeight.SemiBold,color=if(selected) Color.White else Forest);Text("${counts[letter] ?: 0}",fontSize=11.sp,color=if(selected) Color.White else Muted) }
                        }
                        repeat(6-row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }

        }
        FilledAction("Show ${if(filter.letter==null) counts.values.sum() else counts[filter.letter] ?: 0} words",{ onApply(filter) },Modifier.padding(20.dp).testTag("filter.apply"))
    }
}
@Composable internal fun PlaybackOptions(initial: PlaybackSettings,onDismiss: ()->Unit,onChange: (PlaybackSettings)->Unit,onStart: ()->Unit,active: Boolean=false,onStop: ()->Unit={}) {
    var settings by remember { mutableStateOf(initial) }
    fun update(value: PlaybackSettings) { settings=value;onChange(value) }
    Panel("Automatic study",onDismiss) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
            Text("Recall the word, hear the answer, then move on automatically.")
            Text("Listening does not mark words as Known. Use manual study when you want to rate them.",fontSize=14.sp,color=Muted)
            SectionCard {
                Eyebrow("Pace")
                Stepper("Recall pause",settings.recallSeconds) { update(settings.copy(recallSeconds=it)) }
                Stepper("Pause after audio",settings.answerSeconds) { update(settings.copy(answerSeconds=it)) }
            }
            SectionCard {
                Eyebrow("Pronunciation")
                Toggle("Read the prompt",settings.readPrompt) { update(settings.copy(readPrompt=it)) }
                Toggle("Read the answer",settings.readAnswer) { update(settings.copy(readAnswer=it)) }
                Toggle("Read the Swedish sentence",settings.readSentence) { update(settings.copy(readSentence=it)) }
                Text("Voice speed",fontWeight=FontWeight.Medium)
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) { listOf("Slow" to .76f,"Natural" to 1f,"Brisk" to 1.19f).forEach { (label,rate) -> FilterChip(selected=kotlin.math.abs(settings.rate-rate)<.03,onClick={ update(settings.copy(rate=rate)) },label={ Text(label) }) } }
                Text("Ready-made Swedish and English recordings. No phone voice setup is needed. Lessons use the internet unless they are downloaded for offline study.",fontSize=12.sp,color=Muted)
                Text("For silent automatic study, turn off all three reading switches above.",fontSize=12.sp,color=Muted)
            }
        }
        if(active) TextButton(onClick=onStop,modifier=Modifier.fillMaxWidth().testTag("playback.stop")) {Text("Return to manual study")}
        FilledAction("Start automatic study",onStart,Modifier.padding(16.dp).testTag("playback.start"))
    }
}
@Composable private fun Stepper(label: String,value: Int,change: (Int)->Unit) { Column { Text("$label: $value seconds",fontSize=14.sp);Row(verticalAlignment=Alignment.CenterVertically) { TextButton(onClick={ change((value-1).coerceAtLeast(1)) },enabled=value>1,modifier=Modifier.testTag("$label.minus")) { Text("−",fontSize=24.sp) };Text("$value",modifier=Modifier.padding(horizontal=8.dp));TextButton(onClick={ change((value+1).coerceAtMost(15)) },enabled=value<15) { Text("+",fontSize=24.sp) } } } }
@Composable internal fun Toggle(label: String,value: Boolean,enabled: Boolean=true,change: (Boolean)->Unit) { Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) { Text(label,Modifier.weight(1f),fontSize=14.sp);Switch(checked=value,onCheckedChange=change,enabled=enabled,modifier=Modifier.testTag("toggle.$label")) } }
