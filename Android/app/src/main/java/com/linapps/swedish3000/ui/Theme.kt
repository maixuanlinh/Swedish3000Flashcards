package com.linapps.swedish3000.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.linapps.swedish3000.SwedishApplication
import com.linapps.swedish3000.domain.LearningStatus

internal val Forest=Color(0xFF30644F)
internal val Cream=Color(0xFFF6F4EE)
internal val Sage=Color(0xFFE0EBDB)
internal val Ink=Color(0xFF1F332E)
internal val Muted=Color(0xFF6E786E)
internal val Clay=Color(0xFFBA5C40)
internal val Peach=Color(0xFFFAE6D6)
internal val LocalApp=staticCompositionLocalOf<SwedishApplication> { error("Missing app") }
internal val LocalArtworkVersion=compositionLocalOf { 0 }
internal val paths=mapOf(
    "study" to "M5 5L16 3L19 16 M8 7H21V21H8Z M3 9V18H5",
    "words" to "M5 3H19V21H5Z M8 3V21 M11 7H16 M11 11H16 M11 15H16",
    "progress" to "M3 21H22 M5 17V10H8V17Z M11 17V4H14V17Z M17 17V7H20V17Z",
    "filter" to "M3 6H21 M6 12H18 M9 18H15",
    "undo" to "M8 4L3 9L8 14 M3 9H14C23 9 23 21 14 21H10",
    "play" to "M7 4L21 12L7 20Z",
    "pause" to "M7 4V20 M17 4V20",
    "more" to "M4 12H4.2 M12 12H12.2 M20 12H20.2",
    "sound" to "M3 9H7L12 4V20L7 15H3Z M16 8C19 10 19 14 16 16 M19 4C24 8 24 16 19 20",
    "detail" to "M6 18L18 6 M7 6H18V17",
    "flip" to "M3 9C5 1 18 1 21 9 M21 4V9H16 M21 15C19 23 6 23 3 15 M3 20V15H8",
    "left" to "M20 12H4 M10 6L4 12L10 18",
    "check" to "M4 12L9 18L21 5",
    "lock" to "M5 10H19V21H5Z M8 10V6C8 1 16 1 16 6V10 M12 14V17",
    "close" to "M5 5L19 19 M19 5L5 19",
    "next" to "M5 5L17 12L5 19Z M20 5V19",
    "prev" to "M19 5L7 12L19 19Z M4 5V19",
    "stop" to "M5 5H19V19H5Z",
    "help" to "M12 22A10 10 0 1 0 12 2A10 10 0 1 0 12 22 M9 8C9 3 18 5 15 10L12 13 M12 17H12.1",
    "bell" to "M5 17H19L17 14V8C17 1 7 1 7 8V14Z M10 21H14",
    "photo" to "M3 4H21V20H3Z M3 17L9 11L14 16L17 13L21 17 M15 8H15.1",
    "search" to "M17 10A7 7 0 1 0 3 10A7 7 0 1 0 17 10 M15 15L22 22",
    "shuffle" to "M3 5H6C12 5 12 19 18 19H21 M17 15L21 19L17 23 M3 19H6C12 19 12 5 18 5H21 M17 1L21 5L17 9",
    "chevron" to "M9 5L16 12L9 19",
    "sparkle" to "M12 2L15 9L22 12L15 15L12 22L9 15L2 12L9 9Z"
)
@Composable internal fun Symbol(name: String, modifier: Modifier=Modifier, color: Color=Forest) {
    val vector=remember(name) { ImageVector.Builder(name,24.dp,24.dp,24f,24f).addPath(PathParser().parsePathString(paths[name] ?: paths.getValue("detail")).toNodes(),fill=null,stroke=SolidColor(Color.Black),strokeLineWidth=1.9f,strokeLineCap=StrokeCap.Round,strokeLineJoin=StrokeJoin.Round).build() }
    Icon(vector,contentDescription=null,tint=color,modifier=modifier.size(22.dp))
}
@Composable internal fun IconAction(name: String,label: String,onClick: ()->Unit,enabled: Boolean=true,modifier: Modifier=Modifier) {
    IconButton(onClick=onClick,enabled=enabled,modifier=modifier.semantics { contentDescription=label }) { Symbol(name,color=if(enabled) Forest else Muted.copy(alpha=.4f)) }
}
@Composable internal fun Eyebrow(text: String) { Text(text.uppercase(),fontSize=11.sp,fontWeight=FontWeight.Bold,letterSpacing=2.sp,color=Muted) }
@Composable internal fun StatusBadge(status: LearningStatus) {
    val color=if(status==LearningStatus.KNOWN) Forest else if(status==LearningStatus.LEARNING) Clay else Muted
    val background=if(status==LearningStatus.KNOWN) Sage else if(status==LearningStatus.LEARNING) Peach else Cream
    Text(when(status) { LearningStatus.NEW->"New";LearningStatus.LEARNING->"Learning";LearningStatus.KNOWN->"Known" },fontSize=12.sp,fontWeight=FontWeight.SemiBold,color=color,modifier=Modifier.background(background,RoundedCornerShape(50)).padding(horizontal=10.dp,vertical=5.dp))
}
@Composable internal fun FilledAction(text: String,onClick: ()->Unit,modifier: Modifier=Modifier,enabled: Boolean=true) {
    Button(onClick=onClick,enabled=enabled,shape=RoundedCornerShape(18.dp),colors=ButtonDefaults.buttonColors(containerColor=Forest),contentPadding=PaddingValues(16.dp),modifier=modifier.fillMaxWidth().heightIn(min=54.dp)) { Text(text,fontSize=16.sp,fontWeight=FontWeight.SemiBold) }
}
@Composable internal fun Panel(title: String,onClose: ()->Unit,action: (@Composable ()->Unit)?=null,content: @Composable ColumnScope.()->Unit) {
    Dialog(onDismissRequest=onClose,properties=DialogProperties(usePlatformDefaultWidth=false,decorFitsSystemWindows=false)) {
        Surface(color=Cream,modifier=Modifier.fillMaxSize()) {
            Column(Modifier.safeDrawingPadding().fillMaxSize()) {
                Row(Modifier.fillMaxWidth().heightIn(min=56.dp).padding(horizontal=12.dp),verticalAlignment=Alignment.CenterVertically) {
                    Text(title,fontWeight=FontWeight.SemiBold,fontSize=17.sp,modifier=Modifier.weight(1f))
                    action?.invoke()
                    TextButton(onClick=onClose) { Text("Done") }
                }
                content()
            }
        }
    }
}
@Composable internal fun SectionCard(modifier: Modifier=Modifier,content: @Composable ColumnScope.()->Unit) {
    Column(modifier.fillMaxWidth().background(Color.White,RoundedCornerShape(23.dp)).padding(20.dp),verticalArrangement=Arrangement.spacedBy(14.dp),content=content)
}
@Composable internal fun SectionTitle(text: String) { Text(text,fontFamily=FontFamily.Serif,fontWeight=FontWeight.SemiBold,fontSize=23.sp,color=Ink) }
