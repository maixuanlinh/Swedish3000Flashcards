import XCTest
@testable import SwedishCards

@MainActor
final class RecordedSpeechTests: XCTestCase {
    func testStarterWordAndSentencePlayWithoutAnyNetworkOrInstalledVoice() async throws {
        let media = LessonMedia(baseURL: URL(string: "https://example.invalid/")!)
        let speech = SpeechPlayer(media: media)
        try await speech.speakAndWait("en / ett", language: "sv-SE", rate: 0.42)
        try await speech.speakAndWait("a, an", language: "en-US", rate: 0.42)
        try await speech.speakAndWait("Jag ser en katt och ett äpple.", language: "sv-SE", rate: 0.42)
    }

    func testStoppingARecordingCancelsItsAwaiter() async throws {
        let media = LessonMedia(baseURL: URL(string: "https://example.invalid/")!)
        let speech = SpeechPlayer(media: media)
        let playback = Task {
            try await speech.speakAndWait("Jag ser en katt och ett äpple.", language: "sv-SE", rate: 0.32)
        }
        try await Task.sleep(for: .milliseconds(100))
        speech.stop()
        do {
            try await playback.value
            XCTFail("Stopping playback must cancel the suspended call")
        } catch is CancellationError {}
    }
}
