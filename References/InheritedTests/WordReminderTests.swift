import XCTest
import UserNotifications
@testable import SwedishCards

private actor TestReminderCenter: ReminderNotificationCenter {
    var status: UNAuthorizationStatus
    var requests: [String: UNNotificationRequest] = [:]
    var prompts = 0
    var delayAdds = false
    var rejectAdds = false
    init(status: UNAuthorizationStatus = .authorized) { self.status = status }
    func authorization() async -> UNAuthorizationStatus { status }
    func requestPermission() async throws -> Bool { prompts += 1; return status == .authorized }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws {
        if delayAdds { try await Task.sleep(for: .milliseconds(40)) }
        if rejectAdds { throw CocoaError(.fileWriteUnknown) }
        requests[request.identifier] = request
    }
    func removePending(_ ids: [String]) async { for id in ids { requests[id] = nil } }
    func removeDelivered(_ ids: [String]) async {}
    func deliveredIDs() async -> [String] { [] }
    func setDelay() { delayAdds = true }
    func setReject() { rejectAdds = true }
    func promptCount() -> Int { prompts }
}

final class WordReminderTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Helsinki")!
        return value
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 8))! }
    private var words: [ReminderWord] {
        (0..<100).map { ReminderWord(id: "word-\($0)", english: $0 % 2 == 0 ? "apple\($0)" : "book\($0)",
            swedish: "sana\($0)", status: $0 % 3 == 0 ? "learning" : ($0 % 3 == 1 ? "known" : "new"), thumbnail: nil) }
    }
    private var enabled: WordReminderSettings { var value = WordReminderSettings(); value.enabled = true; return value }

    func testFourDailyTimesAreFutureUniqueAndBoundedAcrossAutumnDST() {
        let dates = WordReminderPlan.dates(settings: enabled, now: now, calendar: calendar)
        XCTAssertEqual(dates.count, 56)
        XCTAssertEqual(Set(dates).count, 56)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertTrue(dates.allSatisfy { $0 > now })
        XCTAssertEqual(Set(dates.map { calendar.component(.hour, from: $0) }), Set([9, 13, 17, 21]))
        XCTAssertEqual(Set(dates.map { calendar.startOfDay(for: $0) }).count, 14)
    }

    func testCustomTimesNormalizeAndSpringClockGapDoesNotDuplicateADay() {
        var settings = enabled
        settings.times = [-1, 1440, 180, 180, 600]
        settings.letter = "INVALID"
        XCTAssertEqual(settings.normalized.times, [180, 600])
        XCTAssertNil(settings.normalized.letter)
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 0))!
        let dates = WordReminderPlan.dates(settings: settings, now: start, calendar: calendar)
        XCTAssertEqual(dates.count, 28)
        XCTAssertEqual(Set(dates).count, 28)
        XCTAssertEqual(Dictionary(grouping: dates, by: { calendar.startOfDay(for: $0) }).values.map(\.count).max(), 2)
        settings.times = []
        XCTAssertEqual(settings.normalized.times, [540])
    }

    func testWordSelectionCombinesStatusAndEnglishLetterWithoutFallback() {
        var settings = enabled; settings.pool = .learning; settings.letter = "B"
        let selected = WordReminderPlan.eligible(words, settings: settings)
        XCTAssertFalse(selected.isEmpty)
        XCTAssertTrue(selected.allSatisfy { $0.status == "learning" && $0.english.hasPrefix("b") })
        settings.pool = .remaining
        XCTAssertTrue(WordReminderPlan.eligible(words, settings: settings).allSatisfy { $0.status != "known" })
        settings.letter = "X"
        var rng = SystemRandomNumberGenerator()
        XCTAssertTrue(WordReminderPlan.make(words: words, settings: settings, now: now, calendar: calendar, using: &rng).isEmpty)
    }

    func testShuffleAvoidsRepeatsUntilPoolExhaustedAndHandlesSingleWord() {
        var rng = SystemRandomNumberGenerator()
        let plan = WordReminderPlan.make(words: words, settings: enabled, now: now, calendar: calendar,
            avoiding: Array(words.prefix(20).map(\.id)), using: &rng)
        XCTAssertEqual(Set(plan.map(\.word.id)).count, 56)
        XCTAssertFalse(plan.contains { Set(words.prefix(20).map(\.id)).contains($0.word.id) })
        let small = WordReminderPlan.make(words: Array(words.prefix(3)), settings: enabled, now: now, calendar: calendar, using: &rng)
        XCTAssertEqual(Set(small.prefix(3).map(\.word.id)).count, 3)
        XCTAssertTrue(zip(small, small.dropFirst()).allSatisfy { $0.word.id != $1.word.id })
        let single = WordReminderPlan.make(words: [words[0]], settings: enabled, now: now, calendar: calendar, using: &rng)
        XCTAssertEqual(single.count, 56)
        XCTAssertTrue(single.allSatisfy { $0.word.id == words[0].id })
    }

    func testPayloadHasStableWordIDPromptAndNoAutomaticRatingAction() throws {
        let content = try ReminderNotification.content(word: words[0], settings: enabled)
        XCTAssertEqual(content.title, "Do you remember this word?")
        XCTAssertTrue(content.body.contains(words[0].swedish.uppercased()))
        XCTAssertFalse(content.body.contains(words[0].english))
        XCTAssertNil(content.sound)
        XCTAssertEqual(content.userInfo["wordID"] as? String, words[0].id)
        XCTAssertEqual(content.userInfo["prompt"] as? String, "swedish")
        var settings = enabled; settings.prompt = .english; settings.sound = true
        let english = try ReminderNotification.content(word: words[0], settings: settings)
        XCTAssertTrue(english.body.contains(words[0].english.uppercased()))
        XCTAssertNotNil(english.sound)
        settings.prompt = .pair
        XCTAssertTrue(try ReminderNotification.content(word: words[0], settings: settings).body.contains(" — "))
    }

    func testAttachmentUsesDisposableCopyAndKeepsOriginalThumbnailUnchanged() throws {
        let original = try XCTUnwrap(BundledArtwork.url(for: "sv-0002", thumbnail: true))
        let originalData = try Data(contentsOf: original)
        let word = ReminderWord(id: "sv-0002", english: "abandon", swedish: "överge", status: "new", thumbnail: original)
        let content = try ReminderNotification.content(word: word, settings: enabled)
        let attachment = try XCTUnwrap(content.attachments.first)
        XCTAssertNotEqual(attachment.url, original)
        XCTAssertEqual(try Data(contentsOf: attachment.url), originalData)
        ReminderNotification.cleanStagingFiles(content)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachment.url.path))
        XCTAssertEqual(try Data(contentsOf: original), originalData)
    }

    func testSystemRoundTripKeepsTheScheduledArtworkFile() async throws {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized else { throw XCTSkip("Enable notifications through the sample UI check first.") }
        let original = try XCTUnwrap(BundledArtwork.url(for: "sv-0002", thumbnail: true))
        let content = try ReminderNotification.content(word: ReminderWord(id: "sv-0002", english: "abandon",
            swedish: "överge", status: "new", thumbnail: original), settings: enabled)
        let id = ReminderNotification.prefix + "attachment-integration"
        defer { center.removePendingNotificationRequests(withIdentifiers: [id]) }
        try await center.add(UNNotificationRequest(identifier: id, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)))
        ReminderNotification.cleanStagingFiles(content)
        let pending = await center.pendingNotificationRequests()
        let request = try XCTUnwrap(pending.first { $0.identifier == id })
        XCTAssertEqual(request.content.attachments.count, 1)
        let attachment = try XCTUnwrap(request.content.attachments.first)
        let scoped = attachment.url.startAccessingSecurityScopedResource()
        defer { if scoped { attachment.url.stopAccessingSecurityScopedResource() } }
        XCTAssertEqual(try Data(contentsOf: attachment.url), try Data(contentsOf: original))
    }

    func testSchedulerReplacesOnlyOwnRequestsAndDisableCancelsThem() async throws {
        let center = TestReminderCenter()
        let unrelated = UNNotificationRequest(identifier: "unrelated", content: UNMutableNotificationContent(), trigger: nil)
        try await center.add(unrelated)
        let scheduler = WordReminderScheduler(center: center)
        let first = await scheduler.replace(words: words, settings: enabled, now: now, calendar: calendar)
        XCTAssertEqual(first.count, 56)
        let pending = await center.pending()
        XCTAssertEqual(pending.count, 58)
        XCTAssertTrue(pending.allSatisfy { !$0.identifier.hasPrefix(ReminderNotification.prefix) || $0.trigger?.repeats == false })
        let second = await scheduler.replace(words: words, settings: enabled, now: now, calendar: calendar)
        XCTAssertEqual(second.count, 56)
        let replacements = await center.pending()
        XCTAssertEqual(replacements.count, 58)
        XCTAssertTrue(Set(pending.map(\.identifier)).intersection(replacements.map(\.identifier)) == ["unrelated"])
        _ = await scheduler.replace(words: words, settings: WordReminderSettings(), now: now, calendar: calendar)
        let final = await center.pending()
        XCTAssertEqual(final.map(\.identifier), ["unrelated"])
    }

    func testDeniedPermissionAndEmptyPoolScheduleNothing() async {
        let center = TestReminderCenter(status: .denied)
        let result = await WordReminderScheduler(center: center).replace(words: words, settings: enabled)
        XCTAssertEqual(result.count, 0); XCTAssertNotNil(result.message)
        let empty = await WordReminderScheduler(center: TestReminderCenter()).replace(words: [], settings: enabled)
        XCTAssertEqual(empty.count, 0); XCTAssertTrue(empty.message?.contains("No words") == true)
        let prompts = await center.promptCount()
        XCTAssertEqual(prompts, 0)
    }

    func testDisableDuringAnInFlightAddLeavesNoStaleReminders() async throws {
        let center = TestReminderCenter(); await center.setDelay()
        let scheduler = WordReminderScheduler(center: center)
        let task = Task { await scheduler.replace(words: words, settings: enabled, now: now, calendar: calendar) }
        try await Task.sleep(for: .milliseconds(10))
        _ = await scheduler.replace(words: words, settings: WordReminderSettings(), now: now, calendar: calendar)
        _ = await task.value
        let remaining = await center.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testScheduleFailureIsReportedAndForeignRequestsRespectBudget() async throws {
        let center = TestReminderCenter(); await center.setReject()
        let failed = await WordReminderScheduler(center: center).replace(words: words, settings: enabled, now: now, calendar: calendar)
        XCTAssertEqual(failed.count, 0); XCTAssertNotNil(failed.message)
        let crowded = TestReminderCenter()
        for number in 0..<60 {
            try await crowded.add(UNNotificationRequest(identifier: "other-\(number)", content: UNMutableNotificationContent(), trigger: nil))
        }
        let limited = await WordReminderScheduler(center: crowded).replace(words: words, settings: enabled, now: now, calendar: calendar)
        XCTAssertEqual(limited.count, 3)
        let pending = await crowded.pending()
        XCTAssertEqual(pending.count, 64)
    }

    @MainActor
    func testSettingsPersistAndStartupNeverAsksForPermission() async throws {
        let name = "reminder-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = TestReminderCenter()
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let reminders = WordReminders(defaults: defaults, center: center)
        let artwork = try XCTUnwrap(reminders.snapshots(from: store).first { $0.id == "sv-0002" })
        XCTAssertEqual(artwork.thumbnail, BundledArtwork.url(for: "sv-0002"))
        XCTAssertNotEqual(artwork.thumbnail, BundledArtwork.url(for: "sv-0002", thumbnail: true))
        XCTAssertFalse(reminders.settings.enabled)
        await reminders.refresh(store: store)
        let promptCount = await center.promptCount()
        XCTAssertEqual(promptCount, 0)
        var settings = enabled; settings.prompt = .english; settings.times = [700]; settings.letter = "A"
        let saved = await reminders.save(settings, store: store)
        XCTAssertTrue(saved)
        let reloaded = WordReminders(defaults: defaults, center: center)
        XCTAssertEqual(reloaded.settings, settings)
        XCTAssertEqual(store.events.count, 0)
        let disabled = await reloaded.save(WordReminderSettings(), store: store)
        XCTAssertTrue(disabled)
        let remaining = await center.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    @MainActor
    func testReminderRouteClearsFiltersAndCanOpenKnownWordWithoutRatingIt() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let word = try XCTUnwrap(store.word(withID: "sv-0002"))
        try store.rate(word, as: .known)
        let navigation = AppNavigation()
        navigation.applyFilters(scope: .learning, letter: "Z", topic: "None")
        navigation.openReminder(wordID: word.id, englishFirst: false)
        XCTAssertEqual(navigation.requestedIDs, [word.id])
        XCTAssertNil(navigation.startingLetter); XCTAssertNil(navigation.topic)
        XCTAssertEqual(navigation.scope, .all); XCTAssertEqual(navigation.tab, 0)
        XCTAssertEqual(navigation.promptEnglishFirst, false)
        XCTAssertEqual(store.reviewWords(in: navigation.scope).filter { navigation.requestedIDs!.contains($0.id) }.first?.id, word.id)
        XCTAssertEqual(word.status, .known); XCTAssertEqual(store.events.count, 1)
        navigation.applyFilters(scope: .all, letter: nil, topic: nil)
        XCTAssertNil(navigation.promptEnglishFirst)
    }

    @MainActor
    func testColdStartInboxKeepsDestinationUntilRootConsumesIt() {
        let inbox = ReminderInbox()
        inbox.receive(["wordID": "sv-0002", "prompt": "english"])
        XCTAssertEqual(inbox.pending?.wordID, "sv-0002")
        XCTAssertEqual(inbox.pending?.englishFirst, true)
        inbox.pending = nil
        inbox.receive(["refreshReminders": true])
        XCTAssertNotNil(inbox.pending); XCTAssertNil(inbox.pending?.wordID)
        inbox.pending = nil
        inbox.receive(["unrelated": true])
        XCTAssertNil(inbox.pending)
    }
}
