import XCTest

final class SwedishFlowTests: XCTestCase {
    @MainActor
    func testNativeStudyRevealsSwedishAndOpensWordsAndProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let reveal = app.buttons["card.reveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 20))
        reveal.tap()
        XCTAssertTrue(app.staticTexts["card.answer"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["card.answer"].label, "en / ett")
        XCTAssertEqual(app.staticTexts["card.sentence"].label, "Jag ser en katt och ett äpple.")
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.buttons["word.sv-0001"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Your progress"].waitForExistence(timeout: 5))
    }
}
