package com.linapps.swedish3000

import android.os.Bundle
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.linapps.swedish3000.data.DeviceSpeech
import com.linapps.swedish3000.ui.*

class MainActivity: ComponentActivity() {
    private lateinit var study: StudyViewModel
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as SwedishApplication
        val vm = ViewModelProvider(this, object: ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T: ViewModel> create(modelClass: Class<T>): T =
                StudyViewModel(app.repository,app.entitlements,app.preferences,DeviceSpeech(app)) as T
        })[StudyViewModel::class.java]
        study=vm
        route(intent)
        setContent { SisuApp(vm) }
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent);setIntent(intent);route(intent) }
    private fun route(intent: Intent) {
        intent.getStringExtra("reminderWord")?.let { study.openReminder(it,intent.getBooleanExtra("reminderEnglish",false)) }
        if(intent.getBooleanExtra("reminderSettings",false)) study.openReminderSettings()
        intent.removeExtra("reminderWord");intent.removeExtra("reminderSettings")
    }
}
