import Foundation
import Observation
import AVFoundation

@MainActor
protocol StudySpeech: AnyObject {
    func speakAndWait(_ text: String, language: String, rate: Float) async throws
    func stop()
}

@MainActor
final class SpeechPlayer: NSObject, AVAudioPlayerDelegate, StudySpeech {
    private let media: LessonMedia
    private var player: AVAudioPlayer?
    private var pending: CheckedContinuation<Void, Error>?
    private var activeID: UUID?
    private var loadTask: Task<Data, Error>?

    init(media: LessonMedia? = nil) { self.media = media ?? .shared; super.init() }

    func speakAndWait(_ text: String, language: String, rate: Float) async throws {
        try Task.checkCancellation()
        stop()
        let requestID = UUID()
        activeID = requestID
        let request = Task { try await media.data(for: lessonRecordingKey(language: language, text: text)) }
        loadTask = request
        let data: Data
        do {
            data = try await withTaskCancellationHandler {
                try await request.value
            } onCancel: { request.cancel() }
        }
        catch {
            if activeID == requestID { activeID = nil; loadTask = nil }
            throw error
        }
        try Task.checkCancellation()
        guard activeID == requestID else { throw CancellationError() }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
        let audio = try AVAudioPlayer(data: data)
        audio.delegate = self
        audio.enableRate = true
        audio.rate = min(1.25, max(0.75, rate / 0.42))
        audio.prepareToPlay()
        player = audio
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard activeID == requestID else { continuation.resume(throwing: CancellationError()); return }
                pending = continuation
                if !audio.play() { complete(requestID, error: SpeechError.unavailable) }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.cancel(requestID) } }
        try Task.checkCancellation()
    }
    private func cancel(_ requestID: UUID) {
        guard activeID == requestID else { return }
        stop()
    }
    func stop() {
        let continuation = pending
        pending = nil; activeID = nil
        loadTask?.cancel(); loadTask = nil
        player?.stop(); player = nil
        continuation?.resume(throwing: CancellationError())
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player, let id = self.activeID else { return }
            self.complete(id, error: flag ? nil : SpeechError.unavailable)
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player, let id = self.activeID else { return }
            self.complete(id, error: error ?? SpeechError.unavailable)
        }
    }
    private func complete(_ requestID: UUID, error: Error?) {
        guard activeID == requestID else { return }
        let continuation = pending
        pending = nil; activeID = nil; loadTask = nil; player = nil
        if let error { continuation?.resume(throwing: error) } else { continuation?.resume() }
    }
    enum SpeechError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "The pronunciation recording could not be played. Check your connection and try again."
        }
    }
}

struct AutoStudyItem: Equatable {
    let id: String
    let prompt: String
    let promptLanguage: String
    let answer: String
    let answerLanguage: String
    let sentence: String
}
struct AutoStudySettings: Equatable {
    var recallSeconds: Double = 3
    var answerSeconds: Double = 2
    var readPrompt = true
    var readAnswer = true
    var readSentence = true
    var speechRate: Float = 0.42
}

@MainActor
@Observable
final class AutoStudyPlayer {
    enum State: Equatable { case idle, playing, paused, finished }
    private(set) var state: State = .idle
    private(set) var currentID: String?
    private(set) var revealed = false
    private(set) var index = 0
    private(set) var playedCount = 0
    private(set) var total = 0
    private(set) var error: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var speech: (any StudySpeech)?
    @ObservationIgnored private let wait: (Double) async throws -> Void
    @ObservationIgnored private var items: [AutoStudyItem] = []
    @ObservationIgnored private var settings = AutoStudySettings()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var completedIDs: Set<String> = []
    var isActive: Bool { state != .idle }
    var isPlaying: Bool { state == .playing }

    init(speech: (any StudySpeech)? = nil, wait: @escaping (Double) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.speech = speech; self.wait = wait
    }
    func start(_ items: [AutoStudyItem], settings: AutoStudySettings) {
        stop()
        guard !items.isEmpty else { return }
        self.items = items
        self.settings = settings; total = self.items.count; index = 0; playedCount = 0; completedIDs = []
        run()
    }
    private func cancelWork() {
        generation += 1; task?.cancel(); task = nil; speech?.stop()
    }
    func pause() {
        guard state == .playing else { return }
        cancelWork(); state = .paused
    }
    func resume() { guard state == .paused else { return }; run() }
    func stop() {
        cancelWork(); state = .idle; currentID = nil; revealed = false; error = nil
        items = []; total = 0; index = 0; playedCount = 0; completedIDs = []
    }
    func flip() { pause(); revealed.toggle() }
    func step(_ delta: Int) {
        guard !items.isEmpty else { return }
        let wasPlaying = isPlaying
        cancelWork(); index = min(max(index + delta, 0), items.count - 1)
        currentID = items[index].id; revealed = false; state = .paused
        if wasPlaying { run() }
    }
    private func say(_ text: String, language: String) async throws {
        if speech == nil { speech = SpeechPlayer() }
        try await speech!.speakAndWait(text, language: language, rate: settings.speechRate)
    }
    private func run() {
        cancelWork(); state = .playing; error = nil
        let runID = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                while index < items.count {
                    try Task.checkCancellation()
                    guard generation == runID else { return }
                    let item = items[index]; currentID = item.id; revealed = false
                    if settings.readPrompt { try await say(item.prompt, language: item.promptLanguage) }
                    try await wait(max(0, settings.recallSeconds))
                    try Task.checkCancellation()
                    guard generation == runID else { return }
                    revealed = true
                    if settings.readAnswer { try await say(item.answer, language: item.answerLanguage) }
                    if settings.readSentence && !item.sentence.isEmpty { try await say(item.sentence, language: "sv-SE") }
                    try await wait(max(0, settings.answerSeconds))
                    try Task.checkCancellation()
                    guard generation == runID else { return }
                    completedIDs.insert(item.id); playedCount = completedIDs.count
                    if index + 1 == items.count {
                        state = .finished
                        return
                    }
                    index += 1
                }
            } catch is CancellationError {
                // Pause/stop owns the state transition; an old task must not overwrite a new run.
            } catch {
                guard generation == runID else { return }
                self.error = error.localizedDescription; state = .paused
            }
        }
    }
}
