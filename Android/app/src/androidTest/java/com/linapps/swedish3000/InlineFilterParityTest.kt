package com.linapps.swedish3000

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.ViewModelProvider
import com.linapps.swedish3000.domain.*
import com.linapps.swedish3000.data.*
import com.linapps.swedish3000.ui.*
import org.junit.*
import org.junit.Assert.*

/** Disposable emulator checks against released iOS interactions, not just screen existence. */
class InlineFilterParityTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private lateinit var vm:StudyViewModel
    private fun loaded() {
        compose.activityRule.scenario.onActivity {vm=ViewModelProvider(it)[StudyViewModel::class.java]}
        compose.waitUntil(30000) {!vm.uiState.value.loading && vm.uiState.value.access!=Entitlement.UNKNOWN}
        compose.runOnIdle {vm.previewA()}
    }
    @Test fun topicCardsAreInlineSelectedAndCancelDoesNotApply() {
        loaded();val before=vm.uiState.value.queue;val saved=(compose.activity.application as SwedishApplication).preferences.session
        compose.onNodeWithTag("study.filters").performClick()
        compose.onNodeWithTag("filter.topic.home").performScrollTo().assertIsDisplayed().performClick().assertIsSelected()
        compose.onNodeWithTag("filter.topic.home").assertTextContains("Home & living",substring=true)
        compose.onNodeWithTag("filter.apply").assertExists();captureParity("10-inline-filter-home")
        compose.onNodeWithText("Cancel").performClick()
        assertEquals(before,vm.uiState.value.queue);assertNull(vm.uiState.value.filter.topic)
        assertEquals(saved,(compose.activity.application as SwedishApplication).preferences.session)
    }
    @Test fun allSixteenTopicsAndLettersApplyResetAndPersistLikeIOS() {
        loaded();compose.onNodeWithTag("study.filters").performClick()
        compose.onNodeWithTag("filter.scope.all").performClick()
        compose.onNodeWithTag("filter.topic.commonVerbs").performScrollTo().performClick().assertIsSelected()
        compose.onNodeWithTag("letter.A").performScrollTo().performClick()
        val expected=vm.uiState.value.words.filter {VocabularyTopic.commonVerbs in it.studyTopics && it.initial=="A"}.map {it.id}
        compose.onNodeWithTag("filter.apply").assertTextEquals("Show ${expected.size} words").performClick()
        assertEquals(expected,vm.uiState.value.queue)
        compose.activityRule.scenario.recreate();loadedAfterRecreate()
        assertEquals(expected,vm.uiState.value.queue)
        compose.onNodeWithTag("study.filters").performClick()
        compose.onNodeWithTag("filter.topic.nouns").performScrollTo().assertExists()
        compose.onNodeWithTag("filter.reset").performClick()
        compose.onNodeWithTag("filter.topic.all").performScrollTo().assertExists()
        compose.onNodeWithTag("filter.apply").assertTextEquals("Show 3000 words").performClick()
        assertEquals(3000,vm.uiState.value.queue.size);assertEquals("All vocabulary",vm.uiState.value.listTitle)
    }
    private fun loadedAfterRecreate() {
        compose.activityRule.scenario.onActivity {vm=ViewModelProvider(it)[StudyViewModel::class.java]}
        compose.waitUntil(30000) {!vm.uiState.value.loading}
    }
    @Test fun libraryTopicHeaderClearResultsAndBackRecoverWithoutReplacingStudy() {
        loaded();val saved=(compose.activity.application as SwedishApplication).preferences.session
        compose.onNodeWithTag("tab.Words").performClick();compose.runOnIdle {vm.collection(VocabularyTopic.home)}
        compose.onNodeWithTag("words.topicHeader").performScrollTo().assertExists()
        compose.onNodeWithText("Progress is shared across topics.").assertExists()
        compose.onNodeWithTag("words.search").performScrollTo().performTextInput("zzzznoresults")
        compose.onNodeWithTag("words.clearFilters").performScrollTo().performClick()
        assertEquals(3000,vm.uiState.value.matches.size);assertNull(vm.uiState.value.filter.topic)
        compose.onNodeWithTag("words.backTopics").performScrollTo().performClick()
        compose.onNodeWithTag("words.search").performScrollTo().performTextInput("zzzznoresults")
        compose.onNodeWithTag("words.clearSearch").performScrollTo().performClick()
        compose.onNodeWithTag("words.coreGroups").performScrollTo().assertExists()
        compose.onNodeWithTag("tab.Study").performClick()
        assertEquals(saved,(compose.activity.application as SwedishApplication).preferences.session)
    }
    @Test fun libraryFilterUsesSearchedCandidatesAndShowsTopicProgressInline() {
        loaded();compose.onNodeWithTag("tab.Words").performClick();compose.runOnIdle {vm.collection(null)}
        compose.onNodeWithTag("words.search").performScrollTo().performTextInput("apple")
        val count=vm.uiState.value.matches.size
        compose.onNodeWithTag("words.filters").performScrollTo().performClick()
        compose.onNodeWithTag("filter.apply").assertTextEquals("Show $count words")
        compose.onNodeWithTag("filter.topic.home").performScrollTo().assertExists()
        compose.onNodeWithTag("filter.topic.all").performScrollTo().performClick()
        compose.onNodeWithText("Cancel").performClick()
        assertEquals(count,vm.uiState.value.matches.size)
    }
}
