package com.linapps.swedish3000

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import org.junit.Rule
import org.junit.Test

class SwedishSmokeTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun nativeStudyLoadsSwedishAndNavigates() {
        compose.waitUntil(30000) {
            compose.onAllNodesWithTag("card.reveal").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("card.reveal").performClick()
        compose.onNodeWithTag("card.answer").assertTextEquals("en / ett")
        compose.onNodeWithTag("card.sentence").assertTextEquals("Jag ser en katt och ett äpple.")
        compose.onNodeWithTag("tab.Words").performClick()
        compose.onNodeWithTag("words.search").performTextInput("äpple")
        compose.onNodeWithTag("word.sv-0136").assertExists()
        compose.onNodeWithTag("tab.Progress").performClick()
        compose.onNodeWithText("Your progress").assertExists()
    }
}
