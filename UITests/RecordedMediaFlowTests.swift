import XCTest

@MainActor
final class RecordedMediaFlowTests: XCTestCase {
    /// Physical-device App Review demonstration using Apple's sandbox StoreKit.
    /// A hardware purchase confirmation, if shown, is performed by the owner.
    func testPhysicalDeviceReviewWalkthrough() throws {
        continueAfterFailure = false
        XCTAssertFalse(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil,
                       "App Review requires a physical device recording")
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["card.reveal"].waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 3)
        app.buttons["card.reveal"].tap()
        XCTAssertTrue(app.staticTexts["card.sentence"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 4)
        app.otherElements["study.card"].swipeRight()
        app.tabBars.buttons["Words"].tap()
        if app.buttons["words.allVocabulary"].exists { app.buttons["words.allVocabulary"].tap() }
        let search = app.textFields["words.search"]
        search.tap(); search.typeText("apple\n")
        app.buttons["word.sv-0136"].tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 10))
        app.buttons["detail.playWord"].tap()
        Thread.sleep(forTimeInterval: 3)
        app.buttons["detail.playSentence"].tap()
        Thread.sleep(forTimeInterval: 5)
        app.buttons["detail.done"].tap()
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "book\n")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.tap()
        if app.buttons["lesson.locked"].waitForExistence(timeout: 5) {
            app.buttons["lesson.locked"].tap()
            XCTAssertTrue(app.buttons["premium.buy"].waitForExistence(timeout: 20))
            Thread.sleep(forTimeInterval: 5)
            app.buttons["premium.buy"].tap()
            XCTAssertTrue(app.staticTexts["premium.unlocked"].waitForExistence(timeout: 240), app.debugDescription)
            Thread.sleep(forTimeInterval: 3)
            app.buttons["premium.done"].tap()
        }
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 15))
        let illustration = app.descendants(matching: .any).matching(identifier: "detail.artworkImage").firstMatch
        expectation(for: NSPredicate(format: "value == %@", "Ready"), evaluatedWith: illustration)
        waitForExpectations(timeout: 30)
        app.buttons["detail.playSentence"].tap()
        Thread.sleep(forTimeInterval: 5)
        capture(app, "physical-device-unlocked-lesson")
        app.buttons["detail.done"].tap()
        app.tabBars.buttons["Progress"].tap()
        Thread.sleep(forTimeInterval: 3)
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["settings.offlineStudy"].tap()
        XCTAssertTrue(app.buttons["offline.download"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 4)
        capture(app, "physical-device-offline-controls")
    }

    func testStarterPronunciationAndOptionalOfflineDownloadControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-readPrompt", "NO", "-readAnswer", "NO",
                               "-readSentence", "NO", "-offlineDownloadWiFiOnly", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Words"].tap()
        if app.buttons["words.allVocabulary"].exists { app.buttons["words.allVocabulary"].tap() }
        app.buttons["word.sv-0001"].tap()
        XCTAssertTrue(app.buttons["detail.playWord"].waitForExistence(timeout: 10))
        let illustration = app.descendants(matching: .any).matching(identifier: "detail.artworkImage").firstMatch
        let ready = NSPredicate(format: "value == %@", "Ready")
        expectation(for: ready, evaluatedWith: illustration)
        waitForExpectations(timeout: 15)
        app.buttons["detail.playWord"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.buttons["detail.playSentence"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        capture(app, "swedish-recorded-starter-lesson")
        app.buttons["detail.done"].tap()
        app.tabBars.buttons["Progress"].tap()
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["settings.offlineStudy"].tap()
        XCTAssertTrue(app.buttons["offline.download"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["offline.download"].isEnabled)
        XCTAssertTrue(app.staticTexts["Free A-set lessons"].exists || app.switches["offline.wifiOnly"].exists)
        capture(app, "swedish-optional-offline-download")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
