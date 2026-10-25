import XCTest
import StoreKitTest

@MainActor
final class FlashcardFlowTests: XCTestCase {
    private var app: XCUIApplication!

    private var purchases: SKTestSession!

    override func setUp() async throws {
        let config = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SwedishCards", withExtension: "storekit"))
        purchases = try SKTestSession(contentsOf: config)
        purchases.resetToDefaultState(); purchases.clearTransactions(); purchases.disableDialogs = true
        _ = try await purchases.buyProduct(identifier: "com.linapps.swedish3000.complete")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if name.contains("testAutomaticPlayback") {
            app.launchArguments += ["-readPrompt", "NO", "-readAnswer", "NO", "-readSentence", "NO", "-recallSeconds", "3", "-answerSeconds", "2"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["review.known"].waitForExistence(timeout: 30), app.debugDescription)
    }

    private func startSilentPlayback(captureOptions: Bool = false) {
        app.buttons["study.options"].tap()
        app.buttons["Playback settings"].tap()
        XCTAssertTrue(app.buttons["playback.start"].waitForExistence(timeout: 5))
        let start = app.buttons["playback.start"]
        if captureOptions { capture("31-automatic-study-options") }
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.buttons["playback.pause"].waitForExistence(timeout: 5))
    }

    func testWordReminderSettingsPreviewAndSaveWithoutEnabling() {
        app.tabBars.buttons["Progress"].tap()
        let reminders = app.buttons["progress.reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 5))
        reminders.tap()
        let save = app.buttons["reminders.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable)
        capture("36-word-reminder-schedule")
        app.buttons["reminders.frequency"].tap()
        app.buttons["Twice a day"].tap()
        XCTAssertTrue(app.datePickers["reminders.time.1"].exists)
        XCTAssertFalse(app.datePickers["reminders.time.2"].exists)
        let form = app.descendants(matching: .any).matching(identifier: "reminders.form").firstMatch
        for _ in 0..<12 {
            if app.buttons["reminders.sample"].exists, app.buttons["reminders.sample"].isHittable,
               app.buttons["reminders.sample"].frame.maxY < app.buttons["reminders.save"].frame.minY - 8 { break }
            form.swipeUp()
        }
        XCTAssertTrue(app.buttons["reminders.sample"].isHittable)
        XCTAssertTrue(app.staticTexts["Do you remember this word?"].exists)
        capture("37-word-reminder-preview")
        save.tap()
        XCTAssertTrue(reminders.waitForExistence(timeout: 5))
        reminders.tap()
        XCTAssertTrue(app.buttons["reminders.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["reminders.time.1"].exists)
        XCTAssertFalse(app.datePickers["reminders.time.2"].exists)
        app.buttons["Cancel"].tap()
    }

    func testLocalArtworkNotificationOpensExactWordAfterAppTerminates() {
        // Notification launches do not inherit XCTest launch arguments. Use the
        // persistent store on both sides and preserve any existing simulator progress.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["review.known"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Progress"].tap()
        let knownBefore = app.staticTexts["progress.known"].label
        app.buttons["progress.reminders"].tap()
        XCTAssertTrue(app.buttons["reminders.save"].waitForExistence(timeout: 5))
        let form = app.descendants(matching: .any).matching(identifier: "reminders.form").firstMatch
        for _ in 0..<12 {
            if app.buttons["reminders.sample"].exists, app.buttons["reminders.sample"].isHittable,
               app.buttons["reminders.sample"].frame.maxY < app.buttons["reminders.save"].frame.minY - 8 { break }
            form.swipeUp()
        }
        app.buttons["reminders.sample"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permission = springboard.alerts.firstMatch
        if permission.waitForExistence(timeout: 3), permission.buttons["Allow"].exists {
            permission.buttons["Allow"].tap()
        }
        let scheduled = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sample scheduled in 5 seconds")).firstMatch
        XCTAssertTrue(scheduled.waitForExistence(timeout: 8), app.debugDescription)
        app.terminate()
        let title = springboard.staticTexts["Do you remember this word?"].firstMatch
        if !title.waitForExistence(timeout: 10) {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        }
        XCTAssertTrue(title.waitForExistence(timeout: 5), springboard.debugDescription)
        let attachment = XCTAttachment(screenshot: springboard.screenshot())
        attachment.name = "38-local-notification-banner"; attachment.lifetime = .keepAlways; add(attachment)
        title.press(forDuration: 1)
        let practise = springboard.buttons["Practise word"].firstMatch
        XCTAssertTrue(practise.waitForExistence(timeout: 5), springboard.debugDescription)
        let expanded = XCTAttachment(screenshot: springboard.screenshot())
        expanded.name = "40-expanded-notification-artwork"; expanded.lifetime = .keepAlways; add(expanded)
        practise.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        waitForPrompt("ett äpple")
        XCTAssertEqual(app.staticTexts["session.count"].label, "0 / 1")
        capture("39-notification-opens-swedish-card")
        app.buttons["card.flip"].tap()
        XCTAssertEqual(app.staticTexts["card.answer"].label, "apple")
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, knownBefore)
    }

    func testPlaybackAudioSettingsCanBeChangedWithoutStartingPlayback() {
        app.buttons["study.options"].tap()
        app.buttons["Playback settings"].tap()
        let start = app.buttons["playback.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let form = app.descendants(matching: .any).matching(identifier: "playback.form").firstMatch
        for identifier in ["playback.promptAudio", "playback.answerAudio", "playback.sentenceAudio"] {
            let toggle = app.switches[identifier].firstMatch
            for _ in 0..<6 {
                if toggle.exists, toggle.isHittable, toggle.frame.maxY < start.frame.minY - 4 { break }
                form.swipeUp()
            }
            XCTAssertTrue(toggle.exists && toggle.isHittable)
            XCTAssertLessThan(toggle.frame.maxY, start.frame.minY)
            let before = toggle.value as? String
            XCTAssertTrue(before == "On" || before == "Off")
            // SwiftUI exposes the full Form row as a switch; tap its actual right-hand control.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let changed = NSPredicate(format: "value == %@", before == "On" ? "Off" : "On")
            expectation(for: changed, evaluatedWith: toggle)
            waitForExpectations(timeout: 5)
            XCTAssertTrue(start.exists)
        }
        capture("35-playback-audio-controls")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["review.known"].exists)
        XCTAssertFalse(app.buttons["playback.stop"].exists)
    }

    func testAutomaticPlaybackRevealsAdvancesAndStopsWithoutRating() {
        let play = app.buttons["study.autoplay"]
        XCTAssertLessThanOrEqual(play.frame.maxX, app.buttons["study.options"].frame.minX)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        startSilentPlayback(captureOptions: true)
        XCTAssertTrue(app.staticTexts["card.answer"].waitForExistence(timeout: 8))
        app.buttons["playback.pause"].tap()
        XCTAssertEqual(app.buttons["playback.pause"].label, "Play automatic study")
        XCTAssertTrue(app.buttons["playback.stop"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["playback.stop"].frame.height, 44)
        capture("32-automatic-study-paused")
        app.buttons["playback.pause"].tap()
        let second = NSPredicate(format: "label == %@", "abandon")
        expectation(for: second, evaluatedWith: app.staticTexts["card.prompt"])
        waitForExpectations(timeout: 12)
        app.buttons["playback.pause"].tap()
        app.buttons["playback.next"].tap()
        XCTAssertEqual(app.staticTexts["card.prompt"].label, "ability")
        app.buttons["playback.previous"].tap()
        XCTAssertEqual(app.staticTexts["card.prompt"].label, "abandon")
        app.buttons["playback.stop"].tap()
        waitForPrompt("a, an")
        XCTAssertEqual(app.staticTexts["session.count"].label.components(separatedBy: "/").map { $0.filter(\.isNumber) }, ["0", "3000"])
        app.buttons["study.autoplay"].tap()
        XCTAssertTrue(app.buttons["playback.stop"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["playback.start"].exists, "The Play button must start immediately")
        app.buttons["study.autoplay"].tap()
        XCTAssertEqual(app.buttons["playback.pause"].label, "Play automatic study")
        app.buttons["playback.stop"].tap()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "0")
    }

    func testAutomaticPlaybackPausesWhenChangingTabs() {
        startSilentPlayback()
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Study"].tap()
        XCTAssertEqual(app.buttons["playback.pause"].label, "Play automatic study")
        app.buttons["playback.stop"].tap()
        waitForPrompt("a, an")
    }

    func testAutomaticPlaybackFinishesFocusedWordWithoutChangingKnownCount() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap(); search.typeText("zone")
        app.buttons["words.practice"].tap()
        waitForPrompt("zone")
        startSilentPlayback()
        let completed = NSPredicate(format: "label == %@", "1 / 1")
        expectation(for: completed, evaluatedWith: app.staticTexts["session.count"])
        waitForExpectations(timeout: 12)
        XCTAssertEqual(app.buttons["playback.pause"].label, "Play automatic study")
        XCTAssertEqual(app.staticTexts["card.translation"].label, "The zone is marked on the map.")
        app.buttons["playback.stop"].tap()
        waitForPrompt("zone")
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "0")
    }

    func testRevealSentenceAndZoomIllustration() {
        waitForPrompt("a, an")
        capture("01-study-prompt")
        app.buttons["review.known"].tap()
        waitForPrompt("abandon")
        app.buttons["card.flip"].tap()
        XCTAssertEqual(app.staticTexts["card.answer"].label, "överge")
        XCTAssertEqual(app.staticTexts["card.sentence"].label, "En halua överge tätä suunnitelmaa.")
        XCTAssertEqual(app.staticTexts["card.translation"].label, "I do not want to abandon this plan.")
        XCTAssertTrue(app.staticTexts["card.translation"].isHittable)
        app.buttons["card.detail"].tap()
        XCTAssertTrue(app.staticTexts["detail.swedish"].waitForExistence(timeout: 5))
        app.buttons["detail.image"].tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        app.buttons["illustration.done"].tap()
        app.buttons["detail.done"].tap()
        app.buttons["review.known"].tap()
        waitForPrompt("ability")
        app.buttons["card.flip"].tap()
        XCTAssertEqual(app.staticTexts["card.answer"].label, "förmåga")
        XCTAssertEqual(app.staticTexts["card.translation"].label, "They have the ability to learn quickly.")
        XCTAssertTrue(app.buttons["review.known"].isHittable)
        XCTAssertTrue(app.buttons["card.flip"].isHittable)
        capture("02-study-answer")
        app.buttons["card.detail"].tap()
        XCTAssertTrue(app.staticTexts["detail.swedish"].waitForExistence(timeout: 5))
        app.buttons["detail.image"].tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("03-full-illustration")
        app.buttons["illustration.done"].tap()
        app.buttons["detail.done"].tap()
        XCTAssertTrue(app.buttons["card.detail"].waitForExistence(timeout: 5))
    }

    func testLongSentenceTranslationIsVisibleInStudyAndWordDetail() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("govern")
        app.buttons["word.sv-1175"].tap()
        XCTAssertTrue(app.buttons["detail.done"].waitForExistence(timeout: 5))
        let translation = app.staticTexts["detail.translation"]
        for _ in 0..<6 where !translation.isHittable { app.swipeUp() }
        XCTAssertEqual(translation.label, "The government wants to govern the country fairly.")
        XCTAssertTrue(translation.isHittable)
        XCTAssertFalse(app.buttons["detail.translate"].exists)
        XCTAssertGreaterThanOrEqual(translation.frame.minY, app.staticTexts["detail.sentence"].frame.maxY)
        capture("28-detail-sentence-translation")
        app.buttons["detail.done"].tap()
        app.buttons["words.practice"].tap()
        waitForPrompt("govern")
        app.buttons["card.flip"].tap()
        let subtitle = app.staticTexts["card.translation"]
        let sentence = app.staticTexts["card.sentence"]
        let flip = app.buttons["card.flip"]
        XCTAssertEqual(sentence.label, "Hallitus haluaa hallita maata oikeudenmukaisesti.")
        XCTAssertEqual(subtitle.label, "The government wants to govern the country fairly.")
        XCTAssertTrue(subtitle.isHittable)
        XCTAssertGreaterThanOrEqual(subtitle.frame.minY, sentence.frame.maxY)
        XCTAssertLessThanOrEqual(subtitle.frame.maxY, app.otherElements["card.artwork"].frame.minY)
        XCTAssertLessThanOrEqual(subtitle.frame.maxY, flip.frame.minY)
        XCTAssertTrue(flip.isHittable)
        XCTAssertTrue(app.buttons["review.known"].isHittable)
        capture("27-study-sentence-translation")
        flip.tap()
        waitForPrompt("govern")
        XCTAssertFalse(app.staticTexts["card.translation"].exists)
    }

    func testCardFitsScreenAndImageSwipeDoesNotOpenOrFlipIt() {
        let card = app.otherElements["study.card"]
        let flip = app.buttons["card.flip"]
        XCTAssertGreaterThanOrEqual(flip.frame.width, card.frame.width - 2)
        flip.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["card.answer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["review.learning"].isHittable)
        XCTAssertTrue(app.buttons["review.known"].isHittable)
        XCTAssertLessThanOrEqual(card.frame.maxY, app.buttons["review.known"].frame.minY)
        XCTAssertGreaterThanOrEqual(card.frame.minY, app.buttons["study.filters"].frame.maxY)
        let artwork = app.otherElements["card.artwork"]
        XCTAssertTrue(artwork.exists)
        artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(app.staticTexts["card.answer"].exists)
        XCTAssertFalse(app.buttons["illustration.done"].exists)
        artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.45)))
        waitForPrompt("abandon")
        XCTAssertFalse(app.buttons["illustration.done"].exists)
        app.buttons["card.flip"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["card.answer"].label, "överge")
        let details = app.buttons["card.detail"]
        XCTAssertFalse(details.frame.intersects(app.otherElements["card.artwork"].frame))
        capture("25-study-detail-control")
        details.tap()
        XCTAssertTrue(app.staticTexts["detail.swedish"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "överge")
        let picture = app.descendants(matching: .any).matching(identifier: "detail.artworkImage").firstMatch
        XCTAssertTrue(picture.waitForExistence(timeout: 5))
        let ready = NSPredicate(format: "value == %@", "Ready")
        expectation(for: ready, evaluatedWith: picture)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(app.buttons["detail.image"].frame.minY, picture.frame.maxY)
        capture("26-shared-word-detail")
        app.buttons["detail.done"].tap()
        app.buttons["card.flip"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        waitForPrompt("abandon")
    }

    func testBundledAArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("aunt")
        app.buttons["word.sv-0199"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "täti")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("15-bundled-a-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledBArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("bottle")
        app.buttons["word.sv-0316"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "pullo")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("16-bundled-b-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledCArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("coffee")
        app.buttons["word.sv-0489"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "kahvi")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("17-bundled-c-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledDArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("dictionary")
        app.buttons["word.sv-0737"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "sanakirja")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("18-bundled-d-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledEArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("elephant")
        app.buttons["word.sv-0858"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "norsu")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("19-bundled-e-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledFArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("February")
        app.buttons["word.sv-1016"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "helmikuu")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("20-bundled-f-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledGArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("garage")
        app.buttons["word.sv-1141"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "autotalli; autokorjaamo")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("21-bundled-g-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledHArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("hockey")
        app.buttons["word.sv-1273"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "jääkiekko")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("22-bundled-h-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledIArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("ice cream")
        app.buttons["word.sv-1311"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "jäätelö")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("23-bundled-i-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testBundledZArtworkAppearsOnFreshLaunchWithoutImport() {
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("zero")
        app.buttons["word.sv-2999"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "nolla")
        let image = app.buttons["detail.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("24-bundled-z-artwork")
        app.buttons["illustration.done"].tap()
    }

    func testRatingInStudyDetailUpdatesRemainingQueue() {
        waitForPrompt("a, an")
        app.buttons["card.flip"].tap()
        app.buttons["card.detail"].tap()
        XCTAssertTrue(app.buttons["detail.done"].waitForExistence(timeout: 5))
        let known = app.buttons["detail.status.known"]
        for _ in 0..<6 where !known.isHittable { app.swipeUp() }
        XCTAssertTrue(known.isHittable)
        known.tap()
        app.buttons["detail.done"].tap()
        waitForPrompt("abandon")
        let counts = app.staticTexts["session.count"].label.split(separator: "/").map { String($0.filter(\.isNumber)) }
        XCTAssertEqual(counts, ["1", "3000"])
        app.tabBars.buttons["Words"].tap()
        XCTAssertEqual(app.staticTexts["words.filteredCount"].label.filter(\.isNumber), "2999")
    }

    func testRepeatedTabSwitchesAndFiltersKeepSharedSelection() {
        for _ in 0..<3 {
            app.tabBars.buttons["Words"].tap()
            XCTAssertTrue(app.textFields["words.search"].waitForExistence(timeout: 5))
            app.tabBars.buttons["Study"].tap()
            XCTAssertTrue(app.buttons["study.filters"].waitForExistence(timeout: 5))
            app.buttons["study.filters"].tap()
            XCTAssertTrue(app.buttons["filter.apply"].waitForExistence(timeout: 5))
            app.buttons["filter.scope.all"].tap()
            app.buttons["letter.A"].tap()
            XCTAssertEqual(app.buttons["filter.apply"].label, "Show 211 words")
            app.buttons["filter.apply"].tap()
            waitForPrompt("a, an")
        }
        app.tabBars.buttons["Words"].tap()
        XCTAssertEqual(app.staticTexts["words.filteredCount"].label, "211 shown")
    }

    func testSwipingBothWaysAndUndo() {
        let card = app.otherElements["study.card"]
        XCTAssertTrue(card.exists)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45)))
        waitForPrompt("abandon")
        let next = app.otherElements["study.card"]
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: next.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)))
        waitForPrompt("ability")
        app.buttons["review.undo"].tap()
        waitForPrompt("abandon")
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "1")
        capture("04-progress")
    }

    func testLearningListSearchAndFocusedReview() {
        app.buttons["review.known"].tap()
        waitForPrompt("abandon")
        app.buttons["review.learning"].tap()
        waitForPrompt("ability")
        app.tabBars.buttons["Words"].tap()
        applyFilters(scope: "learning", letter: nil, inWords: true)
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("överge")
        XCTAssertTrue(app.buttons["words.practice"].exists)
        capture("05-learning-list")
        app.buttons["words.practice"].tap()
        waitForPrompt("abandon")
        XCTAssertEqual(app.staticTexts["session.count"].label, "0 / 1")
        app.buttons["review.known"].tap()
        XCTAssertTrue(app.otherElements["session.complete"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "2")
    }

    func testProgressPersistsAcrossAppRelaunch() {
        app.terminate()
        app.launchArguments = ["-test-store", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["card.reveal"].waitForExistence(timeout: 30))
        app.buttons["review.known"].tap()
        waitForPrompt("abandon")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["card.reveal"].waitForExistence(timeout: 30))
        waitForPrompt("abandon")
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "1")
    }

    func testLastCatalogWordCanBeFoundRevealedAndReviewed() {
        app.tabBars.buttons["Words"].tap()
        XCTAssertEqual(app.staticTexts["words.total"].label.filter(\.isNumber), "3000")
        let search = app.textFields["words.search"]
        search.tap()
        search.typeText("zone")
        app.buttons["word.sv-3000"].tap()
        XCTAssertEqual(app.staticTexts["detail.swedish"].label, "vyöhyke; alue")
        XCTAssertFalse(app.buttons["detail.translate"].exists)
        app.buttons["Done"].tap()
        app.buttons["words.practice"].tap()
        waitForPrompt("zone")
        app.buttons["card.reveal"].tap()
        XCTAssertEqual(app.staticTexts["card.sentence"].label, "Vyöhyke on merkitty karttaan.")
        XCTAssertEqual(app.staticTexts["card.translation"].label, "The zone is marked on the map.")
        capture("06-catalog-example")
        app.buttons["review.known"].tap()
        XCTAssertTrue(app.otherElements["session.complete"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertEqual(app.staticTexts["progress.known"].label, "1")
        XCTAssertEqual(app.staticTexts["progress.total"].label.filter(\.isNumber), "3000")
    }

    func testLetterSelectionIsSharedByStudyAndWords() {
        waitForPrompt("a, an")
        applyFilters(scope: "all", letter: "B")
        waitForPrompt("baby")
        capture("07-study-letter-b")
        app.buttons["review.known"].tap()
        waitForPrompt("back")
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.buttons["words.filters"].label.contains("B"))
        applyFilters(scope: "known", letter: "B", inWords: true)
        XCTAssertTrue(app.buttons["word.sv-0212"].exists)
        capture("08-words-letter-b")
        app.buttons["words.practice"].tap()
        waitForPrompt("baby")
        XCTAssertEqual(app.staticTexts["session.count"].label, "0 / 1")
        applyFilters(scope: "all", letter: "D")
        waitForPrompt("dad")
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.buttons["words.filters"].label.contains("D"))
        XCTAssertTrue(app.buttons["word.sv-0656"].exists)
        applyFilters(scope: "all", letter: "C", inWords: true)
        XCTAssertTrue(app.buttons["word.sv-0364"].exists)
        app.buttons["words.practice"].tap()
        waitForPrompt("cable")
    }

    func testEmptyLetterCanReturnToAllLetters() {
        applyFilters(scope: "remaining", letter: "X")
        XCTAssertTrue(app.otherElements["session.complete"].waitForExistence(timeout: 5))
        applyFilters(scope: "remaining", letter: nil)
        waitForPrompt("a, an")
    }

    private func applyFilters(scope: String, letter: String?, inWords: Bool = false) {
        app.buttons[inWords ? "words.filters" : "study.filters"].tap()
        app.buttons["filter.scope." + scope].tap()
        let target = app.buttons[letter.map { "letter." + $0 } ?? "letter.all"]
        let content = app.scrollViews["filters.content"]
        let apply = app.buttons["filter.apply"]
        for _ in 0..<6 {
            if target.exists, target.isHittable,
               target.frame.minY >= content.frame.minY + 4,
               target.frame.maxY <= min(content.frame.maxY, apply.frame.minY) - 4 { break }
            if target.exists, target.frame.minY < content.frame.minY { content.swipeDown() }
            else { content.swipeUp() }
        }
        target.tap()
        capture("09-unified-filters")
        app.buttons["filter.apply"].tap()
    }

    func testEveryCardCanOpenAndCopyAnArtworkPromptWithoutAnImage() {
        app.tabBars.buttons["Words"].tap()
        app.buttons["word.sv-0001"].tap()
        app.buttons["detail.artwork"].tap()
        XCTAssertTrue(app.textViews["artwork.prompt"].waitForExistence(timeout: 5))
        let text = app.textViews["artwork.prompt"].value as? String ?? ""
        XCTAssertTrue(text.contains("sv-0001"))
        XCTAssertTrue(text.contains("a, an"))
        revealArtworkControl("artwork.copy").tap()
        revealArtworkControl("artwork.files")
        XCTAssertEqual(app.staticTexts["artwork.message"].label, "Prompt copied.")
        XCTAssertTrue(app.buttons["artwork.photos"].exists)
        XCTAssertTrue(app.buttons["artwork.files"].exists)
        capture("10-artwork-prompt")
    }

    func testArtworkImportShowsMemoryHookAndSurvivesRelaunch() {
        app.terminate()
        app.launchArguments = ["-test-store", UUID().uuidString, "-ui-artwork-fixture"]
        app.launch()
        openAbilityArtwork()
        revealArtworkControl("artwork.copy").tap()
        let fixture = app.buttons["artwork.fixture"]
        for _ in 0..<4 where !fixture.isHittable { app.swipeUp() }
        fixture.tap()
        let saved = NSPredicate(format: "label BEGINSWITH %@", "Saved locally")
        expectation(for: saved, evaluatedWith: app.staticTexts["artwork.message"])
        waitForExpectations(timeout: 10)
        capture("11-artwork-import")
        app.buttons["artwork.done"].tap()
        XCTAssertTrue(app.staticTexts["detail.memoryHook"].exists)
        XCTAssertTrue(app.staticTexts["detail.memoryHook"].label.uppercased().contains("KEY + KEY"))
        capture("12-word-with-mnemonic")
        app.buttons["detail.image"].tap()
        XCTAssertTrue(app.buttons["illustration.done"].waitForExistence(timeout: 5))
        capture("13-imported-artwork-zoom")
        app.buttons["illustration.done"].tap()
        app.terminate()
        app.launch()
        openAbilityArtwork()
        XCTAssertTrue(app.buttons["artwork.preview"].waitForExistence(timeout: 5))
        app.buttons["artwork.done"].tap()
        XCTAssertTrue(app.staticTexts["detail.memoryHook"].label.uppercased().contains("KEY + KEY"))
    }

    @discardableResult
    private func revealArtworkControl(_ id: String) -> XCUIElement {
        let button = app.buttons[id]
        for _ in 0..<4 where !button.isHittable { app.swipeUp() }
        return button
    }

    private func openAbilityArtwork() {
        XCTAssertTrue(app.tabBars.buttons["Words"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Words"].tap()
        let search = app.textFields["words.search"]
        search.tap(); search.typeText("ability")
        app.buttons["word.sv-0003"].tap()
        app.buttons["detail.artwork"].tap()
        XCTAssertTrue(app.textViews["artwork.prompt"].waitForExistence(timeout: 5))
    }

    func testWordCollectionOffersBulkArtworkImport() {
        app.tabBars.buttons["Words"].tap()
        app.buttons["words.options"].tap()
        app.buttons["words.importArtwork"].tap()
        XCTAssertTrue(app.buttons["artwork.pack.choose"].waitForExistence(timeout: 5))
        capture("14-artwork-pack-import")
    }

    private func waitForPrompt(_ text: String) {
        let predicate = NSPredicate(format: "label == %@", text)
        expectation(for: predicate, evaluatedWith: app.staticTexts["card.prompt"])
        waitForExpectations(timeout: 8)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
