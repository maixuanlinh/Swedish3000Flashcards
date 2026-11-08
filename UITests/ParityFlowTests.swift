import XCTest
import StoreKitTest

@MainActor
final class CommercialReleaseTests: XCTestCase {
    func testCommercialScreensHelpAndStoreOffer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        // Use the real StoreKit product lookup, without a local purchase fixture.
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        capture(app, "commercial-study")
        app.buttons["Words"].firstMatch.tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
        capture(app, "commercial-library")
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("apple")
        app.textFields["words.search"].typeText("\n")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 5))
        let illustration = app.buttons["detail.image"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: illustration)
        waitForExpectations(timeout: 15)
        capture(app, "commercial-free-complete-lesson")
        app.buttons["detail.done"].tap()
        app.buttons["Progress"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Currently learning"].waitForExistence(timeout: 5))
        capture(app, "commercial-progress")
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["settings.offlineStudy"].tap()
        XCTAssertTrue(app.buttons["offline.download"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["offline.wifiOnly"].exists || app.staticTexts["Your Free lessons download automatically over Wi-Fi or mobile data. You can pause at any time."].exists)
        capture(app, "commercial-offline-study")
        app.buttons["Done"].tap()
        let privacy = app.descendants(matching: .any)["settings.privacy"].firstMatch
        for _ in 0..<4 { if privacy.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["settings.website"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.report"].firstMatch.exists)
        capture(app, "commercial-inline-help-and-privacy")
        for _ in 0..<4 { if app.buttons["settings.premium"].isHittable { break }; app.swipeDown() }
        app.buttons["settings.premium"].tap()
        let buy = app.buttons["premium.buy"]
        let loaded = buy.waitForExistence(timeout: 30)
        capture(app, "commercial-premium-offer")
        let result = XCTAttachment(string: loaded ? "Live StoreKit offer: \(buy.label)" : "Live StoreKit price unavailable.\n\(app.debugDescription)")
        result.name = "live-store-offer-result"; result.lifetime = .keepAlways; add(result)
        // Store availability can lag product configuration. Record it separately
        // while enforcing that free study and Help work without a store response.
        XCTAssertTrue(app.buttons["premium.restore"].exists)
        XCTAssertFalse(app.staticTexts["premium.personalMode"].exists)
        app.buttons["premium.done"].tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let result = XCTAttachment(screenshot: app.screenshot())
        result.name = name; result.lifetime = .keepAlways; add(result)
    }
}

@MainActor
final class VocabularyTopicFlowTests: XCTestCase {
    func testMobileTopicBrowserSearchFiltersAndPractice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        openWords(app)
        let home = app.buttons["topic.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(home.isHittable)
        XCTAssertGreaterThanOrEqual(home.frame.minX, 0)
        XCTAssertLessThanOrEqual(home.frame.maxX, app.frame.maxX)
        capture(app, "topics-mobile-library")
        home.tap()
        XCTAssertTrue(app.staticTexts["Hem och boende"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["words.practice"].exists)
        capture(app, "topics-home-vocabulary")
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("house\n")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["words.practice"].tap()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 5))
        openWords(app)
        app.buttons["words.backToTopics"].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["words.filters"].tap()
        XCTAssertTrue(app.buttons["filter.apply"].waitForExistence(timeout: 5))
        app.buttons["filter.scope.known"].tap()
        app.buttons["filter.apply"].tap()
        XCTAssertTrue(app.staticTexts["No matching words"].waitForExistence(timeout: 5))
        app.buttons["Clear filters"].tap()
        XCTAssertTrue(app.buttons["words.practice"].waitForExistence(timeout: 5))
        app.buttons["words.backToTopics"].tap()
        app.segmentedControls["words.collections"].buttons["Word groups"].tap()
        let verbs = app.buttons["topic.commonVerbs"]
        XCTAssertTrue(verbs.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(verbs.isHittable)
        capture(app, "topics-core-word-groups")
        verbs.tap()
        XCTAssertTrue(app.staticTexts["Vardagsverb"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["words.filteredCount"].label, "247 shown")
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("eat\n")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "topics-common-verbs-search")
        app.buttons["words.practice"].tap()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 5))
    }

    private func openWords(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Words"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), app.debugDescription)
        tab.tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5), app.debugDescription)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
final class SettingsAndResumeFlowTests: XCTestCase {
    private func openTab(_ name: String, in app: XCUIApplication) {
        let target: XCUIElement
        switch name {
        case "Words": target = app.textFields["words.search"]
        case "Progress": target = app.staticTexts["progress.known"]
        default: target = app.staticTexts["settings.membership"]
        }
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<3 {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if target.waitForExistence(timeout: 3) { return }
        }
        XCTFail("The \(name) screen did not open: \(app.debugDescription)")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func launch(_ arguments: [String] = ["-ui-testing"]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30), app.debugDescription)
        return app
    }

    func testStudyMenuAndInlineSettingsSupport() {
        let app = launch()
        app.buttons["study.options"].tap()
        XCTAssertTrue(app.buttons["Shuffle this session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review.known"].exists)
        XCTAssertFalse(app.buttons["review.learning"].exists)
        XCTAssertFalse(app.staticTexts["Mark this word"].exists)
        XCTAssertTrue(app.buttons["study.playbackSettings"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Playback settings")).count, 1)
        XCTAssertTrue(app.buttons["Show Swedish first"].exists)
        capture(app, "study-menu-without-rating-actions")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        openTab("Settings", in: app)
        let scroll = app.scrollViews["settings.content"]
        let website = app.descendants(matching: .any)["settings.website"].firstMatch
        let report = app.descendants(matching: .any)["settings.report"].firstMatch
        let privacy = app.descendants(matching: .any)["settings.privacy"].firstMatch
        for _ in 0..<4 { if report.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(website.exists)
        XCTAssertTrue(report.isHittable)
        XCTAssertFalse(app.buttons["settings.support"].exists)
        XCTAssertFalse(app.staticTexts["Suggest a feature"].exists)
        capture(app, "settings-website-and-report")
        for _ in 0..<4 { if privacy.isHittable { break }; scroll.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        XCTAssertFalse(app.buttons["support.done"].exists)
        scroll.swipeUp()
        capture(app, "settings-inline-privacy")
    }

    func testAutomaticFreeDownloadLeavesStudyUsableAndRemembersPause() throws {
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SwedishCards", withExtension: "storekit"))
        let purchases = try SKTestSession(contentsOf: config)
        purchases.resetToDefaultState(); purchases.clearTransactions()
        defer { purchases.clearTransactions() }
        let id = UUID().uuidString
        let app = launch(["-ui-testing", "-test-download-onboarding", "-offline-test-id", id])
        let notice = app.buttons["study.downloadProgress"]
        XCTAssertTrue(notice.waitForExistence(timeout: 25), app.debugDescription)
        XCTAssertFalse(app.buttons["offlinePrompt.later"].exists)
        app.buttons["card.flip"].tap()
        XCTAssertTrue(app.staticTexts["card.answer"].exists || app.staticTexts["card.swedish"].exists || app.staticTexts["card.sentence"].exists)
        capture(app, "offline-auto-free-while-studying")
        notice.tap()
        XCTAssertTrue(app.buttons["offline.pause"].waitForExistence(timeout: 10))
        capture(app, "offline-free-download-progress")
        app.buttons["offline.pause"].tap()
        app.buttons["Done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        XCTAssertFalse(notice.waitForExistence(timeout: 3))
    }

    func testProgressAndSettingsAreSeparateAndSleepScheduleIsEditable() throws {
        let app = launch()
        openTab("Progress", in: app)
        XCTAssertTrue(app.staticTexts["Currently learning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["progress.resume"].exists)
        XCTAssertFalse(app.buttons["settings.reminders"].isHittable)
        capture(app, "progress-learning-and-resume")
        openTab("Settings", in: app)
        XCTAssertTrue(app.buttons["settings.reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.offlineStudy"].exists)
        capture(app, "settings-fourth-tab")
        let membership = app.staticTexts["settings.membership"].label
        guard membership.contains("Personal") || membership.contains("Premium") else { throw XCTSkip("Requires the personal or purchased build") }
        app.buttons["settings.reminders"].tap()
        XCTAssertTrue(app.buttons["reminders.save"].waitForExistence(timeout: 5))
        app.buttons["reminders.frequency"].tap()
        app.buttons["Every 30 minutes"].tap()
        XCTAssertTrue(app.datePickers["reminders.sleepStart"].exists)
        XCTAssertTrue(app.datePickers["reminders.sleepEnd"].exists)
        XCTAssertEqual(app.staticTexts["reminders.dailyCount"].label, "28 reminders per day · repeats daily")
        capture(app, "reminders-half-hourly-sleep-hours")
        app.buttons["Cancel"].tap()
    }

    func testSelectedStudyListAndLearningWordsSurviveRelaunch() {
        let app = launch(["-test-store", "resume-ui-" + UUID().uuidString])
        openTab("Words", in: app)
        let search = app.textFields["words.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        app.buttons["words.allVocabulary"].tap()
        search.tap(); search.typeText("ab\n")
        app.buttons["words.practice"].tap()
        XCTAssertTrue(app.staticTexts["card.prompt"].waitForExistence(timeout: 5))
        let first = app.staticTexts["card.prompt"].label
        app.otherElements["study.card"].swipeLeft()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", first), object: app.staticTexts["card.prompt"])
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        let next = app.staticTexts["card.prompt"].label
        let count = app.staticTexts["session.count"].label
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["card.prompt"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["card.prompt"].label, next)
        XCTAssertEqual(app.staticTexts["session.count"].label, count)
        openTab("Progress", in: app)
        XCTAssertTrue(app.buttons["progress.resume"].waitForExistence(timeout: 5))
        let learning = app.buttons["progress.learningWords"]
        for _ in 0..<3 { if learning.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(learning.isHittable)
        capture(app, "progress-saved-learning-list")
        learning.tap()
        XCTAssertTrue(app.staticTexts["card.prompt"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["card.prompt"].label, first)
    }

    func testFreeSettingsLocksRemindersAndOffersOnlyASetOffline() throws {
        let app = launch()
        openTab("Settings", in: app)
        XCTAssertTrue(app.staticTexts["settings.membership"].waitForExistence(timeout: 5))
        guard app.staticTexts["settings.membership"].label.contains("Free") else { throw XCTSkip("Requires the customer build without a purchase") }
        app.buttons["settings.reminders"].tap()
        XCTAssertTrue(app.buttons["premium.done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reminders.save"].exists)
        capture(app, "free-reminders-premium-upgrade")
        app.buttons["premium.done"].tap()
        app.buttons["settings.offlineStudy"].tap()
        XCTAssertTrue(app.buttons["offline.download"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["offline.download"].label.contains("free A set"))
        XCTAssertTrue(app.staticTexts["Free A-set lessons"].exists)
        capture(app, "free-a-set-offline-download")
        app.buttons["Done"].tap()
    }
}

@MainActor
final class StudyToolbarPrototypeTests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO", "-recallSeconds", "3", "-answerSeconds", "2", "-showStudySubtitles", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30), app.debugDescription)
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func assertNoOverlap(_ app: XCUIApplication) {
        let card = app.otherElements["study.card"]
        let header = app.otherElements["study.header"]
        let toolbar = app.otherElements["study.toolbar"]
        XCTAssertTrue(header.exists && toolbar.exists, app.debugDescription)
        XCTAssertLessThanOrEqual(header.frame.maxY, card.frame.minY)
        XCTAssertLessThanOrEqual(card.frame.maxY, toolbar.frame.minY)
        XCTAssertLessThanOrEqual(toolbar.frame.maxY, app.tabBars.firstMatch.frame.minY)
        for id in ["study.autoplay", "study.playbackSettings", "study.options"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable, id)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, id)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, id)
        }
    }

    func testHeaderFooterSwipeAndUndo() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["study.listTitle"].exists)
        XCTAssertFalse(app.buttons["review.known"].exists)
        XCTAssertFalse(app.buttons["review.learning"].exists)
        assertNoOverlap(app)
        capture(app, "study-toolbar-prototype-prompt")
        let first = app.staticTexts["card.prompt"].label
        app.otherElements["study.card"].swipeRight()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", first), object: app.staticTexts["card.prompt"])
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        let undo = app.buttons["review.undo"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        undo.tap()
        XCTAssertEqual(app.staticTexts["card.prompt"].label, first)
        app.buttons["study.playbackSettings"].tap()
        XCTAssertTrue(app.buttons["playback.start"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 5))
        app.buttons["study.filters"].tap()
        XCTAssertTrue(app.buttons["filter.apply"].waitForExistence(timeout: 5))
        let topic = app.staticTexts["TOPIC"]
        let letters = app.staticTexts["ENGLISH STARTS WITH"]
        XCTAssertTrue(topic.exists && letters.exists, app.debugDescription)
        XCTAssertLessThan(topic.frame.minY, letters.frame.minY)
        capture(app, "filters-topic-before-letter")
        app.buttons["Cancel"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func testAlwaysVisibleTranslationAndAutomaticToolbar() {
        let app = launch()
        XCTAssertFalse(app.buttons["study.subtitles"].exists)
        app.buttons["card.flip"].tap()
        XCTAssertTrue(app.staticTexts["card.translation"].waitForExistence(timeout: 5))
        assertNoOverlap(app)
        capture(app, "study-toolbar-always-english")
        app.buttons["study.autoplay"].tap()
        // The customer build keeps mixed-list autoplay behind Premium.
        // Exercise its real Free A-set route when no purchase is installed.
        if app.buttons["premium.buy"].waitForExistence(timeout: 3) {
            let preview = app.buttons["premium.preview"]
            for _ in 0..<6 { if preview.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(preview.isHittable)
            preview.tap()
            XCTAssertTrue(app.buttons["study.autoplay"].waitForExistence(timeout: 5))
            app.buttons["study.autoplay"].tap()
        }
        XCTAssertTrue(app.buttons["playback.next"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playback.previous"].isHittable)
        app.buttons["study.autoplay"].tap()
        XCTAssertEqual(app.buttons["study.autoplay"].label, "Play automatic study")
        assertNoOverlap(app)
        capture(app, "study-toolbar-prototype-playback")
        app.buttons["playback.next"].tap()
        app.buttons["playback.previous"].tap()
        app.buttons["study.playbackSettings"].tap()
        app.buttons["playback.stop"].tap()
        XCTAssertTrue(app.buttons["review.undo"].exists)
        XCTAssertFalse(app.buttons["playback.next"].exists)
    }
}

// Run explicitly on the owner's phone. Uses real downloaded media but never rates a word
// or resets the learning store. Other UI checks use isolated test data and sessions.
@MainActor
final class LiveOfflineDownloadTests: XCTestCase {
    func testCustomerDownloadSurvivesLeavingTheApp() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        let notice = app.buttons["study.downloadProgress"]
        guard notice.waitForExistence(timeout: 20) else {
            throw XCTSkip("No active automatic download: it may already be saved, paused by the owner, or awaiting a Premium choice.")
        }
        let before = notice.label
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(12))
        app.activate()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 20))
        let evidence = XCTAttachment(string: "Before leaving: \(before)\nAfter returning: \(notice.exists ? notice.label : "download finished")")
        evidence.name = "live-background-transfer-progress"; evidence.lifetime = .keepAlways; add(evidence)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "offline-live-after-background"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertTrue(app.buttons["study.playbackSettings"].isHittable)
        if notice.exists {
            notice.tap()
            XCTAssertTrue(app.buttons["offline.pause"].waitForExistence(timeout: 10))
            app.buttons["Done"].tap()
        }
    }
}
