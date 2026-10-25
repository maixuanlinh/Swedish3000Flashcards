import XCTest
@testable import SwedishCards

@MainActor
final class AutoStudyPlayerTests: XCTestCase {
    private let cards = [
        AutoStudyItem(id: "one", prompt: "key", promptLanguage: "en-GB", answer: "en nyckel", answerLanguage: "sv-SE", sentence: "Nyckeln är i fickan."),
        AutoStudyItem(id: "two", prompt: "book", promptLanguage: "en-GB", answer: "en bok", answerLanguage: "sv-SE", sentence: "Boken är intressant.")
    ]
    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Playback did not reach the expected state", file: file, line: line)
    }
    func testSilentPlaybackUsesBothPausesAndFinishesWithoutSpeech() async throws {
        let speech = TestStudySpeech(); var waits: [Double] = []
        let player = AutoStudyPlayer(speech: speech, wait: { waits.append($0); try Task.checkCancellation() })
        player.start(cards, settings: AutoStudySettings(recallSeconds: 3, answerSeconds: 2, readPrompt: false, readAnswer: false, readSentence: false))
        try await eventually { player.state == .finished }
        XCTAssertEqual(waits, [3, 2, 3, 2])
        XCTAssertTrue(speech.requests.isEmpty)
        XCTAssertEqual(player.playedCount, 2)
        XCTAssertEqual(player.currentID, "two")
        XCTAssertTrue(player.revealed)
    }
    func testAnswerWaitsForSpeechCompletionBeforeAdvancing() async throws {
        let speech = TestStudySpeech(); speech.block = true
        let player = AutoStudyPlayer(speech: speech, wait: { _ in try Task.checkCancellation() })
        player.start(cards, settings: AutoStudySettings(readPrompt: false, readSentence: false))
        try await eventually { speech.pending != nil }
        XCTAssertEqual(player.currentID, "one")
        XCTAssertTrue(player.revealed)
        XCTAssertEqual(player.playedCount, 0)
        speech.complete()
        try await eventually { player.currentID == "two" && speech.pending != nil }
        XCTAssertEqual(player.playedCount, 1)
        speech.complete()
        try await eventually { player.state == .finished }
        XCTAssertEqual(player.playedCount, 2)
    }
    func testPauseSkipResumeAndStopCannotAdvanceFromAnOldSpeechTask() async throws {
        let speech = TestStudySpeech(); speech.block = true
        let player = AutoStudyPlayer(speech: speech, wait: { _ in try Task.checkCancellation() })
        player.start(cards, settings: AutoStudySettings(readPrompt: false, readSentence: false))
        try await eventually { speech.pending != nil }
        player.pause()
        XCTAssertEqual(player.state, .paused)
        XCTAssertEqual(player.currentID, "one")
        player.step(1)
        XCTAssertEqual(player.currentID, "two")
        XCTAssertEqual(player.playedCount, 0)
        player.resume()
        try await eventually { speech.pending != nil }
        speech.complete()
        try await eventually { player.state == .finished }
        XCTAssertEqual(player.playedCount, 1, "Skipping a card must not count it as played")
        player.stop()
        XCTAssertEqual(player.state, .idle)
        XCTAssertNil(player.currentID)
        XCTAssertEqual(player.playedCount, 0)
    }
    func testReversePromptAndSentenceUseTheirOwnLanguagesInOrder() async throws {
        let speech = TestStudySpeech()
        let player = AutoStudyPlayer(speech: speech, wait: { _ in try Task.checkCancellation() })
        let reverse = AutoStudyItem(id: "reverse", prompt: "en nyckel", promptLanguage: "sv-SE", answer: "key", answerLanguage: "en-GB", sentence: "Nyckeln är i fickan.")
        player.start([reverse], settings: AutoStudySettings(speechRate: 0.32))
        try await eventually { player.state == .finished }
        XCTAssertEqual(speech.requests.map(\.text), ["en nyckel", "key", "Nyckeln är i fickan."])
        XCTAssertEqual(speech.requests.map(\.language), ["sv-SE", "en-GB", "sv-SE"])
        XCTAssertTrue(speech.requests.allSatisfy { $0.rate == 0.32 })
    }
    func testStartingANewPlaylistCancelsTheOldRecallTimer() async throws {
        let speech = TestStudySpeech()
        let player = AutoStudyPlayer(speech: speech, wait: { _ in try await Task.sleep(for: .milliseconds(30)) })
        player.start(cards, settings: AutoStudySettings(readPrompt: false, readAnswer: false, readSentence: false))
        try await eventually { player.currentID == "one" }
        player.start([cards[1]], settings: AutoStudySettings(readPrompt: false, readAnswer: false, readSentence: false))
        try await eventually { player.state == .finished }
        XCTAssertEqual(player.currentID, "two")
        XCTAssertEqual(player.total, 1)
        XCTAssertEqual(player.playedCount, 1)
    }
    func testVoiceFailurePausesAndSilentRetryCanContinue() async throws {
        let speech = TestStudySpeech(); speech.fail = true
        let player = AutoStudyPlayer(speech: speech, wait: { _ in try Task.checkCancellation() })
        player.start(cards, settings: AutoStudySettings())
        try await eventually { player.state == .paused }
        XCTAssertNotNil(player.error)
        XCTAssertEqual(player.playedCount, 0)
        player.start(cards, settings: AutoStudySettings(readPrompt: false, readAnswer: false, readSentence: false))
        try await eventually { player.state == .finished }
        XCTAssertNil(player.error)
    }
}

@MainActor
private final class TestStudySpeech: StudySpeech {
    struct Request { let text: String; let language: String; let rate: Float }
    var requests: [Request] = []
    var block = false
    var fail = false
    var pending: CheckedContinuation<Void, Error>?
    func speakAndWait(_ text: String, language: String, rate: Float) async throws {
        try Task.checkCancellation()
        requests.append(Request(text: text, language: language, rate: rate))
        if fail { throw SpeechPlayer.SpeechError.missingVoice }
        if block { try await withCheckedThrowingContinuation { pending = $0 } }
        try Task.checkCancellation()
    }
    func stop() { let old = pending; pending = nil; old?.resume(throwing: CancellationError()) }
    func complete() { let old = pending; pending = nil; old?.resume() }
}
