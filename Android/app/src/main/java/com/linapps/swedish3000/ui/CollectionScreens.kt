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

@Composable internal fun Words(s: StudyUiState,vm: StudyViewModel,filters: ()->Unit,import: ()->Unit) {
    Column(Modifier.widthIn(max=700.dp).fillMaxSize().padding(horizontal=18.dp)) {
        Row(Modifier.padding(top=12.dp,bottom=8.dp),verticalAlignment=Alignment.CenterVertically) {
            Text("Words",fontFamily=FontFamily.Serif,fontSize=26.sp,fontWeight=FontWeight.SemiBold,modifier=Modifier.weight(1f))
            Text("${s.words.size} words",color=Muted,fontSize=14.sp)
            var menu by remember { mutableStateOf(false) }
            Box { IconAction("more","Word collection options",{ menu=true },modifier=Modifier.testTag("words.options"));DropdownMenu(menu,{ menu=false }) { DropdownMenuItem(text={ Text("Import artwork pack") },onClick={ menu=false;import() }) } }
        }
        OutlinedTextField(value=s.search,onValueChange=vm::search,placeholder={ Text("Search English or Swedish",fontSize=14.sp) },leadingIcon={ Symbol("search",color=Muted) },trailingIcon=if(s.search.isEmpty()) null else ({ IconAction("close","Clear search",{ vm.search("") }) }),singleLine=true,shape=RoundedCornerShape(15.dp),colors=OutlinedTextFieldDefaults.colors(unfocusedContainerColor=Color.White,focusedContainerColor=Color.White,unfocusedBorderColor=Color.Transparent),modifier=Modifier.fillMaxWidth().testTag("words.search"))
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
            TextButton(onClick=filters,modifier=Modifier.weight(1f).testTag("words.filters")) { Symbol("filter");Spacer(Modifier.width(6.dp));Text(listOfNotNull(s.filter.scope.title,s.filter.letter,s.filter.topic).joinToString(" · "),maxLines=1) }
            Text("${s.matches.size} shown",fontSize=12.sp,color=Muted,modifier=Modifier.testTag("words.filteredCount"))
        }
        if(s.matches.isEmpty()) {
            Column(Modifier.weight(1f).fillMaxWidth(),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                Symbol("search",Modifier.size(40.dp),Muted);Spacer(Modifier.height(16.dp));SectionTitle("No matching words")
                Text("Try another word or change your filters.",color=Muted,textAlign=TextAlign.Center)
                TextButton(onClick={ vm.search("");vm.filter(WordFilter(scope=Scope.ALL)) }) { Text("Clear filters") }
            }
        } else {
            LazyColumn(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(9.dp),contentPadding=PaddingValues(bottom=12.dp)) {
                items(s.matches,key={ it.id }) { word ->
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White).clickable { vm.detail(word.id) }.padding(14.dp).testTag("word.${word.id}"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
                        Box(Modifier.size(width=51.dp,height=55.dp).background(Cream,RoundedCornerShape(15.dp)),contentAlignment=Alignment.Center) {
                            if(AccessPolicy.hasLesson(word,s.access)) Artwork(word,Modifier.fillMaxSize(),thumbnail=true) else Symbol("lock")
                        }
                        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(5.dp)) { Text(word.swedish,fontFamily=FontFamily.Serif,fontSize=20.sp,fontWeight=FontWeight.Medium);Text(word.english,fontSize=14.sp,color=Muted) }
                        StatusBadge(s.ratings[word.id]?.status ?: LearningStatus.NEW)
                    }
                }
            }
            FilledAction(if(s.matches.size==1) "Practise this word" else "Practise these ${s.matches.size} words",vm::practice,Modifier.padding(vertical=10.dp).testTag("words.practice"))
        }
    }
}
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
    val app=LocalApp.current
    val billing=app.entitlements as? com.linapps.swedish3000.data.PlayEntitlementRepository
    val purchaseMessage=billing?.message?.collectAsStateWithLifecycle()?.value
    val purchaseBusy=billing?.busy?.collectAsStateWithLifecycle()?.value ?: false
    val known=s.ratings.values.count { it.status==LearningStatus.KNOWN };val learning=s.ratings.values.count { it.status==LearningStatus.LEARNING }
    val today=LocalDate.now();val zone=ZoneId.systemDefault()
    val byDay=remember(s.events,today,zone) { s.events.groupingBy { Instant.ofEpochMilli(it.at).atZone(zone).toLocalDate() }.eachCount() }
    val days=(6L downTo 0L).map { today.minusDays(it) }
    val reminders=remember(reminderVersion) { app.reminders.settings }
    val next=remember(reminderVersion) { app.reminders.nextDate }
    Column(Modifier.widthIn(max=624.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(22.dp),verticalArrangement=Arrangement.spacedBy(23.dp)) {
        Row(verticalAlignment=Alignment.Top) {
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(6.dp)) { Eyebrow("Your Swedish, growing");Text("Your progress",fontFamily=FontFamily.Serif,fontSize=31.sp,fontWeight=FontWeight.SemiBold) }
            TextButton(onClick={ open("support") },modifier=Modifier.testTag("progress.support")) { Symbol("help",Modifier.size(18.dp));Spacer(Modifier.width(5.dp));Text("Help") }
        }
        SectionCard {
            Row(Modifier.fillMaxWidth().clickable { vm.premium(true) }.testTag("progress.premium"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
                Symbol(if(s.access==Entitlement.COMPLETE) "check" else "sparkle",Modifier.size(44.dp).background(Sage,RoundedCornerShape(50)).padding(10.dp))
                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) { Text(if(s.access==Entitlement.COMPLETE) "3000 Swedish Words Premium" else "3000 Swedish Words Free",fontWeight=FontWeight.SemiBold,color=Forest,fontSize=16.sp);Text(if(s.access==Entitlement.COMPLETE) "Available Swedish lessons unlocked" else "211 A-set words; artwork in progress",fontSize=12.sp,color=Muted) }
                Symbol("chevron",Modifier.size(16.dp))
            }
            Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                if(s.access!=Entitlement.COMPLETE) TextButton(onClick={ vm.premium(true) }) { Text("Explore Premium") }
                Spacer(Modifier.weight(1f))
                TextButton(onClick={ billing?.restore() },enabled=!purchaseBusy) { Text("Restore Purchases",fontSize=12.sp) }
            }
            purchaseMessage?.let { Text(it,fontSize=12.sp,color=Muted) }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(23.dp)).background(Color.White).clickable { open("reminders") }.padding(16.dp).testTag("progress.reminders"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
            Symbol("bell",Modifier.size(44.dp).background(Sage,RoundedCornerShape(50)).padding(10.dp))
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                Text("Word reminders",fontWeight=FontWeight.SemiBold,color=Forest)
                Text(if(reminders.enabled && next!=null) "Next: "+Instant.ofEpochMilli(next).atZone(zone).format(DateTimeFormatter.ofPattern("d MMM, HH:mm")) else if(reminders.enabled) "Check notification settings" else "A little Swedish, throughout your day",fontSize=12.sp,color=Muted)
            }
            Symbol("chevron",Modifier.size(16.dp))
        }
        Row(Modifier.fillMaxWidth().background(Forest,RoundedCornerShape(27.dp)).padding(25.dp),verticalAlignment=Alignment.CenterVertically) {
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(11.dp)) {
                Text("WORDS YOU KNOW",fontSize=10.sp,fontWeight=FontWeight.Bold,letterSpacing=1.5.sp,color=Color.White.copy(alpha=.7f))
                Text("$known",fontSize=58.sp,fontFamily=FontFamily.Serif,color=Color.White,modifier=Modifier.testTag("progress.known"))
                Text("of ${s.words.size} words",color=Color.White.copy(alpha=.8f),fontSize=14.sp)
            }
            Box(Modifier.size(105.dp),contentAlignment=Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) { drawArc(Color.White.copy(alpha=.15f),-90f,360f,false,style=androidx.compose.ui.graphics.drawscope.Stroke(9.dp.toPx()));drawArc(Color(0xFFD4E8A8),-90f,360f*known/s.words.size.coerceAtLeast(1),false,style=androidx.compose.ui.graphics.drawscope.Stroke(9.dp.toPx(),cap=androidx.compose.ui.graphics.StrokeCap.Round)) }
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
    val words=remember(s.words,s.tab,s.search) { if(s.tab==1) s.words.filter { it.searchText.contains(s.search.trim().lowercase(Locale.ROOT)) } else s.words }
    val counts=remember(filter,s.ratings,words) { words.filter { filter.copy(query="",letter=null).matches(it,s.ratings[it.id]?.status ?: LearningStatus.NEW) }.groupingBy { it.initial }.eachCount() }
    Panel("Filters",onDismiss,action={ TextButton(onClick={ filter=WordFilter(scope=Scope.ALL) }) { Text("Reset") } }) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
            Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                Eyebrow("Learning status")
                Scope.entries.forEach { scope ->
                    Row(Modifier.fillMaxWidth().background(if(filter.scope==scope) Sage else Color.White,RoundedCornerShape(12.dp)).clickable { filter=filter.copy(scope=scope) }.padding(13.dp).testTag("filter.scope.${scope.name.lowercase()}"),verticalAlignment=Alignment.CenterVertically) { Text(scope.title,color=Forest,modifier=Modifier.weight(1f));if(filter.scope==scope) Symbol("check") else Text("○",color=Forest) }
                }
            }
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
            Eyebrow("Topic")
            var topics by remember { mutableStateOf(false) }
            Box { TextButton(onClick={ topics=true }) { Text(filter.topic ?: "All topics");Symbol("chevron") };DropdownMenu(topics,{ topics=false }) {
                DropdownMenuItem(text={ Text("All topics") },onClick={ filter=filter.copy(topic=null);topics=false })
                s.words.map { it.topic }.distinct().sorted().forEach { topic -> DropdownMenuItem(text={ Text(topic) },onClick={ filter=filter.copy(topic=topic);topics=false }) }
            } }
        }
        FilledAction("Show ${if(filter.letter==null) counts.values.sum() else counts[filter.letter] ?: 0} words",{ onApply(filter) },Modifier.padding(20.dp).testTag("filter.apply"))
    }
}
@Composable internal fun PlaybackOptions(initial: PlaybackSettings,onDismiss: ()->Unit,onChange: (PlaybackSettings)->Unit,onStart: ()->Unit) {
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
                Text("Uses your device’s speech voices. Install a Swedish voice for offline pronunciation.",fontSize=12.sp,color=Muted)
            }
        }
        FilledAction("Start automatic study",onStart,Modifier.padding(16.dp))
    }
}
@Composable private fun Stepper(label: String,value: Int,change: (Int)->Unit) { Column { Text("$label: $value seconds",fontSize=14.sp);Row(verticalAlignment=Alignment.CenterVertically) { TextButton(onClick={ change((value-1).coerceAtLeast(1)) },enabled=value>1,modifier=Modifier.testTag("$label.minus")) { Text("−",fontSize=24.sp) };Text("$value",modifier=Modifier.padding(horizontal=8.dp));TextButton(onClick={ change((value+1).coerceAtMost(15)) },enabled=value<15) { Text("+",fontSize=24.sp) } } } }
@Composable internal fun Toggle(label: String,value: Boolean,change: (Boolean)->Unit) { Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) { Text(label,Modifier.weight(1f),fontSize=14.sp);Switch(checked=value,onCheckedChange=change,modifier=Modifier.testTag("toggle.$label")) } }
