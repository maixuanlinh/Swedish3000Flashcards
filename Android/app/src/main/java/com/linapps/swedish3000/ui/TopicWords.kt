@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.linapps.swedish3000.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.linapps.swedish3000.domain.*

@Composable internal fun TopicWords(s: StudyUiState,vm: StudyViewModel,filters: ()->Unit,import: ()->Unit) {
    var core by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    val topics=if(core) VocabularyTopic.coreCollections else VocabularyTopic.themes
    val known=s.words.count {s.ratings[it.id]?.status==LearningStatus.KNOWN}
    val selected=VocabularyTopic.fromTitle(s.filter.topic)
    val showsTopics=s.browsingTopics && s.search.isBlank() && selected==null
    Column(Modifier.widthIn(max=700.dp).fillMaxSize().padding(horizontal=18.dp)) {
        LazyColumn(Modifier.weight(1f).testTag("words.content"),contentPadding=PaddingValues(top=12.dp,bottom=18.dp),verticalArrangement=Arrangement.spacedBy(18.dp)) {
            item("header") { Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                if(showsTopics) Text("Words",fontFamily=FontFamily.Serif,fontSize=26.sp,fontWeight=FontWeight.SemiBold,modifier=Modifier.weight(1f))
                else TextButton(onClick=vm::browseTopics,modifier=Modifier.weight(1f).testTag("words.backTopics")) {Text("‹ Topics")}
                Text("${s.words.size} words",color=Muted,fontSize=14.sp,modifier=Modifier.testTag("words.total"))
                Box {IconAction("more","Word collection options",{menu=true},modifier=Modifier.testTag("words.options"));DropdownMenu(menu,{menu=false}) {DropdownMenuItem(text={Text("Import artwork pack")},onClick={menu=false;import()})}}
            } }
            selected?.let {topic -> item("topic-header") { TopicHeader(topic,s) } }
            item("search") {OutlinedTextField(value=s.search,onValueChange=vm::search,placeholder={Text("Search English or Swedish",fontSize=14.sp)},leadingIcon={Symbol("search",color=Muted)},trailingIcon=if(s.search.isEmpty()) null else ({IconAction("close","Clear search",{vm.search("")},modifier=Modifier.testTag("words.clearSearch"))}),singleLine=true,shape=RoundedCornerShape(18.dp),colors=OutlinedTextFieldDefaults.colors(unfocusedContainerColor=Color.White,focusedContainerColor=Color.White,unfocusedBorderColor=Color.Transparent),modifier=Modifier.fillMaxWidth().testTag("words.search"))}
            if(showsTopics) {
                item("overall") {SectionCard {
                    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text("Your vocabulary",fontWeight=FontWeight.SemiBold);Text("$known / ${s.words.size} known",fontSize=13.sp)}
                    TopicProgressBar(known,s.words.size)
                    Text("Choose a topic for your next practice.",color=Muted,fontSize=14.sp)
                }}
                item("collections") {Row(Modifier.fillMaxWidth().background(Sage,RoundedCornerShape(30.dp)).padding(4.dp)) {
                    listOf("Everyday topics","Word groups").forEachIndexed {i,label -> TextButton(onClick={core=i==1},modifier=Modifier.weight(1f).background(if(core==(i==1)) Color.White else Color.Transparent,RoundedCornerShape(30.dp)).testTag(if(i==0) "words.themes" else "words.coreGroups")) {Text(label,maxLines=1)}}
                }}
                item("heading") {Column(verticalArrangement=Arrangement.spacedBy(5.dp)) {SectionTitle(if(core) "Everyday word groups" else "Explore by topic");Text(if(core) "7 focused collections · up to 300 words each" else "9 themes for everyday situations",fontSize=13.sp,color=Muted)}}
                item("browse-actions") {Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                    TextButton(onClick={vm.collection(null)},modifier=Modifier.weight(1f).testTag("words.allVocabulary")) {Symbol("words");Spacer(Modifier.width(7.dp));Text("All vocabulary")}
                    TextButton(onClick=filters,modifier=Modifier.testTag("words.filters")) {Symbol("filter");Text("Filters")}
                }}
                item("topic-grid") {TopicCardGrid(topics,s.words,s.ratings,onSelect={vm.collection(it)})}
                item("shared-progress") {Text("Words can appear in several topics. Your overall progress counts each word once.",fontSize=12.sp,color=Muted)}
            } else {
                item("filter-summary") {Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {
                    TextButton(onClick=filters,modifier=Modifier.weight(1f).testTag("words.filters")) {Symbol("filter");Spacer(Modifier.width(6.dp));Text(s.filterTitle)}
                    Text("${s.matches.size} shown",fontSize=12.sp,color=Muted,modifier=Modifier.testTag("words.filteredCount"))
                }}
                if(s.matches.isEmpty()) item("empty") {SectionCard {
                    SectionTitle("No matching words")
                    Text("Try another word or change your filters.",color=Muted)
                    TextButton(onClick=vm::clearLibraryFilters,modifier=Modifier.testTag("words.clearFilters")) {Text("Clear filters")}
                }}
                else items(s.matches,key={it.id}) {word ->
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White).clickable {vm.detail(word.id)}.padding(14.dp).testTag("word.${word.id}"),verticalAlignment=Alignment.Top,horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(51.dp,55.dp).background(Cream,RoundedCornerShape(15.dp)),contentAlignment=Alignment.Center) {if(AccessPolicy.hasLesson(word,s.access)) Artwork(word,Modifier.fillMaxSize(),thumbnail=true) else Symbol("lock")}
                        Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(7.dp)) {
                            Text(word.swedish,fontFamily=FontFamily.Serif,fontSize=20.sp);Text(word.english,fontSize=14.sp,color=Muted)
                            FlowRow(horizontalArrangement=Arrangement.spacedBy(6.dp),verticalArrangement=Arrangement.spacedBy(4.dp)) {StatusBadge(s.ratings[word.id]?.status ?: LearningStatus.NEW);VocabularyTopic.entries.firstOrNull {it in word.studyTopics && it!=selected}?.let {Text(it.title,fontSize=11.sp,color=Muted)}}
                        }
                        Symbol("chevron",Modifier.padding(top=8.dp).size(15.dp),Muted)
                    }
                }
            }
        }
        if(!showsTopics && s.matches.isNotEmpty()) FilledAction(if(s.matches.size==1) "Practise this word" else "Practise these ${s.matches.size} words",vm::practice,Modifier.padding(vertical=10.dp).testTag("words.practice"))
    }
}
@Composable private fun TopicHeader(topic:VocabularyTopic,s:StudyUiState) {
    val words=remember(topic,s.words) {s.words.filter {topic in it.studyTopics}}
    val known=words.count {s.ratings[it.id]?.status==LearningStatus.KNOWN}
    val learning=words.count {s.ratings[it.id]?.status==LearningStatus.LEARNING}
    Column(Modifier.fillMaxWidth().background(Color.White,RoundedCornerShape(22.dp)).padding(18.dp).testTag("words.topicHeader"),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(13.dp)) {Symbol(topic.icon,Modifier.size(52.dp).background(Sage,RoundedCornerShape(16.dp)).padding(12.dp));Column(Modifier.weight(1f)) {Text(topic.swedish,fontFamily=FontFamily.Serif,fontSize=25.sp,fontWeight=FontWeight.SemiBold);Text(topic.title,fontSize=14.sp,color=Muted)}}
        Text(topic.detail,fontSize=14.sp,color=Muted)
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text("$known / ${words.size} known",fontSize=12.sp,color=Muted);Text("$learning learning",fontSize=12.sp,color=Muted)}
        TopicProgressBar(known,words.size)
        Text("Progress is shared across topics.",fontSize=12.sp,color=Muted)
    }
}
@Composable internal fun TopicProgressBar(known:Int,total:Int) {
    LinearProgressIndicator(progress={known.toFloat()/total.coerceAtLeast(1)},color=Forest,trackColor=Sage,drawStopIndicator={},modifier=Modifier.fillMaxWidth())
}
@Composable internal fun TopicCardGrid(topics:List<VocabularyTopic>,words:List<Word>,ratings:Map<String,Rating>,selected:String?=null,tagPrefix:String="topic",onSelect:(VocabularyTopic)->Unit) {
    val fontScale=LocalDensity.current.fontScale
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns=if(fontScale>1.3f) 1 else ((maxWidth.value+12)/167).toInt().coerceAtLeast(1)
        Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
            topics.chunked(columns).forEach {row -> Row(Modifier.height(IntrinsicSize.Min),horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                row.forEach {topic -> TopicCard(topic,words,ratings,selected==topic.title,Modifier.weight(1f),"$tagPrefix.${topic.name}") {onSelect(topic)}}
                repeat(columns-row.size) {Spacer(Modifier.weight(1f))}
            }}
        }
    }
}
@Composable private fun TopicCard(topic:VocabularyTopic,allWords:List<Word>,ratings:Map<String,Rating>,selected:Boolean,modifier:Modifier,tag:String,onClick:()->Unit) {
    val words=remember(topic,allWords) {allWords.filter {topic in it.studyTopics}}
    val known=words.count {ratings[it.id]?.status==LearningStatus.KNOWN}
    Column(modifier.heightIn(min=194.dp).fillMaxHeight().clip(RoundedCornerShape(21.dp)).background(if(selected) Sage.copy(alpha=.4f) else Color.White).border(if(selected) 2.dp else 1.dp,if(selected) Forest else Sage,RoundedCornerShape(21.dp)).selectable(selected=selected,role=Role.Button,onClick=onClick).padding(15.dp).testTag(tag),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically) {Symbol(topic.icon,Modifier.size(42.dp).background(if(topic.ordinal%3==0) Peach else Sage,RoundedCornerShape(14.dp)).padding(9.dp));Spacer(Modifier.weight(1f));Symbol(if(selected) "check" else "detail",Modifier.size(17.dp),if(selected) Forest else Muted)}
        Text(topic.swedish,fontFamily=FontFamily.Serif,fontSize=19.sp,fontWeight=FontWeight.SemiBold,color=Ink)
        Text(topic.title,fontSize=12.sp,color=Muted)
        Spacer(Modifier.weight(1f))
        TopicProgressBar(known,words.size)
        Text("$known / ${words.size} known",fontSize=12.sp,color=Muted)
    }
}
