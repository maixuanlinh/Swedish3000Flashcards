import XCTest
import StoreKitTest

@MainActor
final class PremiumFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var purchases: SKTestSession!
    private let productID = "com.linapps.swedish3000.complete"

    override func setUp() async throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SwedishCards", withExtension: "storekit"))
        purchases = try SKTestSession(contentsOf: url)
        purchases.resetToDefaultState(); purchases.clearTransactions(); purchases.disableDialogs = true
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        app.launchEnvironment["SWEDISHCARDS_STOREKIT_TESTING"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["review.known"].waitForExistence(timeout: 30))
    }

    private func openBook() {
        app.tabBars.buttons["Words"].tap()
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("book")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["detail.swedish"].waitForExistence(timeout: 5))
    }

    func testFreeBWordKeepsTranslationAndRatingButLocksCompleteLesson() {
        openBook()
        XCTAssertTrue(app.buttons["lesson.locked"].exists)
        XCTAssertFalse(app.staticTexts["detail.sentence"].exists)
        XCTAssertFalse(app.otherElements["detail.artworkImage"].exists)
        capture("41-free-word-detail")
        app.buttons["lesson.locked"].tap()
        XCTAssertTrue(app.buttons["premium.buy"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["premium.restore"].isHittable)
        capture("42-premium-offer")
        app.buttons["premium.done"].tap()
        app.buttons["detail.status.known"].tap()
        app.buttons["detail.done"].tap()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "1")
        XCTAssertEqual(app.staticTexts["progress.membership"].label, "3000 Swedish Words Free")
        capture("43-free-status-and-restore")
    }

    func testPurchaseUnlocksImmediatelySurvivesRelaunchAndRefundRelocks() async throws {
        openBook(); app.buttons["lesson.locked"].tap()
        XCTAssertTrue(app.buttons["premium.buy"].waitForExistence(timeout: 15))
        app.buttons["premium.buy"].tap()
        XCTAssertTrue(app.staticTexts["premium.unlocked"].waitForExistence(timeout: 15), app.debugDescription)
        capture("44-premium-purchase-success")
        app.buttons["premium.done"].tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lesson.locked"].exists)
        capture("45-unlocked-word-detail")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["review.known"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["progress.membership"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["progress.membership"].label, "3000 Swedish Words Premium")
        let transaction = try XCTUnwrap(purchases.allTransactions().first)
        try purchases.refundTransaction(identifier: transaction.identifier)
        let free = NSPredicate(format: "label == %@", "3000 Swedish Words Free")
        let revoked = expectation(for: free, evaluatedWith: app.staticTexts["progress.membership"])
        await fulfillment(of: [revoked], timeout: 10)
        openBook()
        XCTAssertTrue(app.buttons["lesson.locked"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["detail.sentence"].exists)
    }

    func testMixedAutoplayOffersFreeASetAndAPlaybackWorks() {
        app.buttons["study.autoplay"].tap()
        XCTAssertTrue(app.buttons["premium.buy"].waitForExistence(timeout: 15))
        let preview = app.buttons["premium.preview"]
        for _ in 0..<6 { if preview.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(preview.isHittable)
        preview.tap()
        XCTAssertTrue(app.buttons["study.autoplay"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["session.count"].label, "0 / 211")
        app.buttons["study.autoplay"].tap()
        XCTAssertTrue(app.buttons["playback.stop"].waitForExistence(timeout: 5))
        app.buttons["playback.stop"].tap()
        app.buttons["card.reveal"].tap()
        XCTAssertTrue(app.staticTexts["card.sentence"].exists)
        XCTAssertFalse(app.buttons["lesson.locked"].exists)
        capture("46-free-A-complete-lesson")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

@MainActor
final class PersonalAccessFlowTests: XCTestCase {
    func testPersonalAccessWithoutStoreConfigurationSurvivesRelaunch() throws {
        #if DEBUG && SWEDISHCARDS_PERSONAL
        continueAfterFailure = false
        let app = XCUIApplication()
        // No launch environment, no StoreKit file or transaction, no unlock preference.
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Progress"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Progress"].tap()
        let knownBefore = app.staticTexts["progress.known"].label
        XCTAssertEqual(app.staticTexts["progress.membership"].label, "3000 Swedish Words Personal")
        XCTAssertFalse(app.buttons["progress.restore"].exists)
        app.buttons["progress.premium"].tap()
        XCTAssertTrue(app.staticTexts["premium.unlocked"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["premium.personalMode"].exists)
        XCTAssertFalse(app.buttons["premium.price"].exists)
        XCTAssertFalse(app.buttons["premium.buy"].exists)
        XCTAssertFalse(app.buttons["premium.restore"].exists)
        app.buttons["premium.done"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Progress"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, knownBefore)
        app.tabBars.buttons["Words"].tap()
        app.buttons["words.filters"].tap()
        app.buttons["filter.reset"].tap()
        app.buttons["filter.apply"].tap()
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("book")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lesson.locked"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "personal-unlocked-book"; attachment.lifetime = .keepAlways; add(attachment)
        #else
        throw XCTSkip("Run with the Personal build configuration to verify personal UI.")
        #endif
    }
}
