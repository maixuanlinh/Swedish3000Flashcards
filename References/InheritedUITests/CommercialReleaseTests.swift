import XCTest

@MainActor
final class CommercialReleaseTests: XCTestCase {
    func testCommercialScreensHelpAndStoreOffer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        // Use the real StoreKit product lookup, without a local purchase fixture.
        app.launch()
        XCTAssertTrue(app.buttons["review.known"].waitForExistence(timeout: 30))
        capture(app, "commercial-study")
        app.buttons["Words"].firstMatch.tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
        capture(app, "commercial-library")
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("apple")
        app.textFields["words.search"].typeText("\n")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "word.sv-")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 5))
        capture(app, "commercial-free-complete-lesson")
        app.buttons["detail.done"].tap()
        app.buttons["Progress"].firstMatch.tap()
        XCTAssertTrue(app.buttons["progress.support"].waitForExistence(timeout: 5))
        capture(app, "commercial-progress")
        app.buttons["progress.support"].tap()
        XCTAssertTrue(app.buttons["support.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["support.privacy"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["support.website"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["support.email"].exists)
        capture(app, "commercial-help-and-privacy")
        app.buttons["support.done"].tap()
        app.buttons["progress.premium"].tap()
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
