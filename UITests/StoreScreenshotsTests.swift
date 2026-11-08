import XCTest

@MainActor
final class StoreScreenshotsTests: XCTestCase {
    func testCaptureCustomerScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-englishFirst", "YES", "-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["card.flip"].waitForExistence(timeout: 30))
        app.buttons["card.reveal"].tap()
        XCTAssertTrue(app.staticTexts["card.sentence"].waitForExistence(timeout: 10))
        try capture(app, "01-illustrated-study")
        app.buttons["Words"].tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
        try capture(app, "02-word-library")
        app.textFields["words.search"].tap()
        app.textFields["words.search"].typeText("apple\n")
        XCTAssertTrue(app.buttons["word.sv-0136"].waitForExistence(timeout: 10))
        app.buttons["word.sv-0136"].tap()
        XCTAssertTrue(app.staticTexts["detail.sentence"].waitForExistence(timeout: 10))
        let artwork = app.descendants(matching: .any).matching(identifier: "detail.artworkImage").firstMatch
        let ready = NSPredicate(format: "value == %@", "Ready")
        expectation(for: ready, evaluatedWith: artwork)
        waitForExpectations(timeout: 20)
        try capture(app, "03-example-and-audio")
        app.buttons["detail.done"].tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Currently learning"].waitForExistence(timeout: 10))
        try capture(app, "04-learning-progress")
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["settings.offlineStudy"].tap()
        XCTAssertTrue(app.buttons["offline.download"].waitForExistence(timeout: 10))
        try capture(app, "05-offline-study")
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let folder = URL.documentsDirectory.appending(path: "StoreScreenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: name + ".png"))
        print("STORE_SCREENSHOTS: \(folder.path)")
    }
}
