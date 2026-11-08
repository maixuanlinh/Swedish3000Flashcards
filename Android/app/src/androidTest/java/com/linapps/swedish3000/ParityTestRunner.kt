package com.linapps.swedish3000

import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.test.runner.AndroidJUnitRunner
import com.linapps.swedish3000.data.EntitlementRepository
import com.linapps.swedish3000.domain.Entitlement
import kotlinx.coroutines.flow.MutableStateFlow

class ParityTestRunner: AndroidJUnitRunner() {
    companion object {var premiumFixture=false;var resetPrompt=false}
    override fun onCreate(arguments:Bundle) {premiumFixture=arguments.getString("premium")=="true";resetPrompt=arguments.getString("resetPrompt")=="true";super.onCreate(arguments)}
    override fun newApplication(cl:ClassLoader,className:String,context:Context):Application = super.newApplication(cl,ParityTestApplication::class.java.name,context)
}
class ParityTestApplication: SwedishApplication() {
    override fun onCreate() {if(ParityTestRunner.resetPrompt) getSharedPreferences("offline-lessons",MODE_PRIVATE).edit().remove("premiumPromptHandled").apply();super.onCreate()}
    override val entitlements:EntitlementRepository by lazy {
        if(ParityTestRunner.premiumFixture) object:EntitlementRepository {
            override val access=MutableStateFlow(Entitlement.COMPLETE)
            override suspend fun refresh() {}
        } else super.entitlements
    }
}
