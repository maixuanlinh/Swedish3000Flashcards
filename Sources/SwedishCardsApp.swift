import SwiftUI
import SwiftData

@main
@MainActor
struct SwedishCardsApp: App {
    @UIApplicationDelegateAdaptor(ReminderAppDelegate.self) private var appDelegate
    @State private var reminders = WordReminders()
    @State private var premium = PremiumStore()
    @State private var store: StudyStore?
    @State private var startupError: String?

    @State private var loading = false

    private func start() async {
        guard store == nil, !loading else { return }
        loading = true
        startupError = nil
        // Decode the two large metadata files before navigation, away from the UI thread.
        await Task.detached(priority: .userInitiated) {
            BundledArtwork.preload()
            ArtworkPromptBuilder.preload()
        }.value
        guard !Task.isCancelled else { loading = false; return }
        do { store = try Self.load() }
        catch { startupError = error.localizedDescription }
        loading = false
    }

    private static func load() throws -> StudyStore {
        let args = ProcessInfo.processInfo.arguments
        var testURL: URL?
        if let index = args.firstIndex(of: "-test-store"), args.indices.contains(index + 1) {
            let name = args[index + 1].filter { $0.isLetter || $0.isNumber || $0 == "-" }
            let directory = URL.applicationSupportDirectory.appending(path: "TestStores")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            testURL = directory.appending(path: name + ".store")
        }
        let container = try StudyStore.makeContainer(inMemory: args.contains("-ui-testing"), url: testURL)
        let artworkDirectory: URL?
        if args.contains("-ui-testing") {
            artworkDirectory = URL.temporaryDirectory.appending(path: "UITestArtwork/" + UUID().uuidString)
        } else if let testURL {
            artworkDirectory = URL.applicationSupportDirectory.appending(path: "TestArtwork/" + testURL.lastPathComponent)
        } else { artworkDirectory = nil }
        return try StudyStore(container: container, seeds: StudyStore.readSeeds(), artworkDirectory: artworkDirectory)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView()
                        .environment(store)
                        .environment(reminders)
                        .environment(premium)
                        .modelContainer(store.container)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("Your words couldn’t open", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(startupError)
                    } actions: {
                        Button("Try again") {
                            Task { await start() }
                        }
                    }
                } else {
                    ProgressView().tint(Palette.forest)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.background)
                        .accessibilityLabel("Loading vocabulary")
                }
            }
            .task { await start() }
            .tint(Palette.forest)
            .preferredColorScheme(.light)
        }
    }
}
