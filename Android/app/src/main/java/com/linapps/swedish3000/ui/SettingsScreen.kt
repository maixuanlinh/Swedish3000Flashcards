package com.linapps.swedish3000.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.linapps.swedish3000.BuildConfig
import com.linapps.swedish3000.domain.*
import java.time.*
import java.time.format.DateTimeFormatter

@Composable internal fun SettingsScreen(s: StudyUiState,vm: StudyViewModel,open: (String)->Unit,reminderVersion: Int) {
    val app=LocalApp.current
    val billing=app.entitlements as? com.linapps.swedish3000.data.PlayEntitlementRepository
    val purchaseMessage=billing?.message?.collectAsStateWithLifecycle()?.value
    val purchaseBusy=billing?.busy?.collectAsStateWithLifecycle()?.value ?: false
    val reminders=remember(reminderVersion) {app.reminders.settings}
    val next=remember(reminderVersion) {app.reminders.nextDate}
    val zone=ZoneId.systemDefault()
    Column(Modifier.widthIn(max=624.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(22.dp).testTag("settings.content"),verticalArrangement=Arrangement.spacedBy(22.dp)) {
        Eyebrow("Make it yours")
        Text("Settings",fontFamily=FontFamily.Serif,fontSize=32.sp,fontWeight=FontWeight.SemiBold)
        SectionCard {
            Row(Modifier.fillMaxWidth().clickable { vm.premium(true) }.testTag("progress.premium"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
                Symbol(if(s.access==Entitlement.COMPLETE) "check" else "sparkle",Modifier.size(44.dp).background(Sage,RoundedCornerShape(50)).padding(10.dp))
                Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) { Text(if(s.access==Entitlement.COMPLETE) "3000 Swedish Words Premium" else "3000 Swedish Words Free",fontWeight=FontWeight.SemiBold,color=Forest,fontSize=16.sp,modifier=Modifier.testTag("settings.membership"));Text(if(s.access==Entitlement.COMPLETE) "All 3,000 complete lessons unlocked" else "211 complete A-set lessons included",fontSize=12.sp,color=Muted) }
                Symbol("chevron",Modifier.size(16.dp))
            }
            if(s.access!=Entitlement.COMPLETE) FilledAction("Go Premium",{ vm.premium(true) },Modifier.testTag("settings.goPremium"),enabled=!purchaseBusy)
            TextButton(onClick={ billing?.restore() },enabled=!purchaseBusy,modifier=Modifier.fillMaxWidth().testTag("settings.restore")) { Text(if(purchaseBusy) "Checking purchases…" else "Restore Purchases",fontSize=12.sp) }
            purchaseMessage?.let { Text(it,fontSize=12.sp,color=Muted) }
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(23.dp)).background(Color.White).clickable { vm.pause();open("offline") }.padding(16.dp).testTag("settings.offline"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
            Symbol("words",Modifier.size(44.dp).background(Sage,RoundedCornerShape(50)).padding(10.dp))
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                Text("Download for offline study",fontWeight=FontWeight.SemiBold,color=Forest)
                Text("Learn without internet. Downloaded images and audio use space on your phone.",fontSize=12.sp,color=Muted)
            }
            Symbol("chevron",Modifier.size(16.dp))
        }

        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(23.dp)).background(Color.White).clickable { if(s.access==Entitlement.COMPLETE) open("reminders") else vm.premium(true) }.padding(16.dp).testTag("settings.reminders"),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(14.dp)) {
            Symbol("bell",Modifier.size(44.dp).background(Sage,RoundedCornerShape(50)).padding(10.dp))
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                Row(horizontalArrangement=Arrangement.spacedBy(7.dp),verticalAlignment=Alignment.CenterVertically) {Text("Word reminders",fontWeight=FontWeight.SemiBold,color=Forest);if(s.access!=Entitlement.COMPLETE) Text("Premium",fontSize=12.sp,color=Forest,modifier=Modifier.testTag("settings.remindersPremium"))}
                Text(if(reminders.enabled && next!=null) "Next: "+Instant.ofEpochMilli(next).atZone(zone).format(DateTimeFormatter.ofPattern("d MMM, HH:mm")) else if(reminders.enabled) "Check notification settings" else "A little Swedish, throughout your day",fontSize=12.sp,color=Muted)
            }
            Symbol("chevron",Modifier.size(16.dp))
        }

        SettingsSupport(vm)
    }
}
@Composable private fun SettingsSupport(vm: StudyViewModel) {
    val context=LocalContext.current
    fun open(url: String) { runCatching {context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(url)))}.onFailure {vm.message("No app could open this link. Contact support@essaykingapp.com.")} }
    SectionCard {TextButton(onClick={open("https://yki.essaykingapp.com/?language=sv")},modifier=Modifier.testTag("settings.website")) {Symbol("globe");Spacer(Modifier.width(12.dp));Text("Visit our website")};Text("yki.essaykingapp.com",fontSize=12.sp,color=Muted)}
    SectionCard {
        Text("Help & support",fontWeight=FontWeight.SemiBold)
        TextButton(onClick={open("mailto:support@essaykingapp.com?subject="+Uri.encode("3000 Swedish Words: Report or feedback")+"&body="+Uri.encode("Tell us about a problem or share your feedback:\n\nVersion ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"))},modifier=Modifier.testTag("settings.report")) {Symbol("mail");Spacer(Modifier.width(12.dp));Text("Report a problem")}
        Text("Found a bug or have an idea? Send us an email.",fontSize=13.sp,color=Muted)
        androidx.compose.foundation.text.selection.SelectionContainer {Text("support@essaykingapp.com",fontSize=13.sp,color=Muted)}
    }
    SectionCard {
        Text("Privacy & about",fontWeight=FontWeight.SemiBold)
        TextButton(onClick={open("https://yki.essaykingapp.com/swedish3000/privacy.html")},modifier=Modifier.testTag("settings.privacy")) {Text("Privacy policy")}
        Text("Study progress and imported artwork are stored on this device. Restoring Premium restores purchase access, not your learning history.",fontSize=13.sp,color=Muted)
        Text("An independent Swedish vocabulary learning app from Linapps. Not affiliated with an official examination provider.",fontSize=13.sp,color=Muted)
        Text("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",fontSize=12.sp,color=Muted)
    }
}
