import SwiftUI
import Observation
import UIKit

@MainActor
@Observable
final class AppNavigation {
    var tab = 0
    var scope: ReviewScope = .remaining
    var requestedIDs: [String]?
    var startingLetter: String?
    var topic: String?
    var request = 0
    var promptEnglishFirst: Bool?
    var resumeSessionRequested = false
    var isReminderSession = false

    func openReminder(wordID: String, englishFirst: Bool) {
        isReminderSession = true
        resumeSessionRequested = false
        scope = .all
        startingLetter = nil
        topic = nil
        requestedIDs = [wordID]
        promptEnglishFirst = englishFirst
        request += 1
        tab = 0
    }

    func review(_ scope: ReviewScope, ids: [String]? = nil) {
        isReminderSession = false
        resumeSessionRequested = false
        promptEnglishFirst = nil
        self.scope = scope
        requestedIDs = ids
        request += 1
        tab = 0
    }

    func selectLetter(_ letter: String?) {
        promptEnglishFirst = nil
        startingLetter = letter
        requestedIDs = nil
        request += 1
    }

    func applyFilters(scope: ReviewScope, letter: String?, topic: String?) {
        isReminderSession = false
        resumeSessionRequested = false
        promptEnglishFirst = nil
        self.scope = scope
        startingLetter = letter
        self.topic = topic
        requestedIDs = nil
        request += 1
    }
    func resumeStudy() {
        isReminderSession = false
        resumeSessionRequested = true
        promptEnglishFirst = nil
        request += 1
        tab = 0
    }

    func studyLearningWords() {
        startingLetter = nil
        topic = nil
        review(.learning)
    }

}

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @Environment(WordReminders.self) private var reminders
    @Environment(PremiumStore.self) private var premium
    @Environment(LessonMedia.self) private var media
    @Environment(\.scenePhase) private var scenePhase
    @State private var inbox = ReminderInbox.shared
    @State private var showingReminders = false
    @State private var navigation = AppNavigation()

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            StudyView()
                .tabItem { Label("Study", systemImage: "rectangle.on.rectangle.angled") }
                .tag(0)
            WordLibraryView()
                .tabItem { Label("Words", systemImage: "text.book.closed") }
                .tag(1)
            ProgressViewScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .environment(navigation)
        .tint(Palette.accent)
        .sheet(isPresented: Binding(get: { media.showingPremiumDownloadPrompt }, set: { media.showingPremiumDownloadPrompt = $0 }), onDismiss: { media.dismissPremiumDownloadPrompt() }) {
            PremiumOfflineDownloadPrompt()
        }
        .sheet(isPresented: $showingReminders) { WordReminderSettingsView(settings: reminders.settings) }
        .task {
            consumeReminder()
            await premium.start()
            await media.setPremium(premium.isPremium)
            await reminders.setPremium(premium.isPremium, store: store)
            await reminders.refresh(store: store)
            await media.activateDownloads(premium: premium.isPremium, offerPrompt: true)
        }
        .onChange(of: inbox.pending) { _, _ in consumeReminder() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task {
                await premium.refreshAccess()
                await media.setPremium(premium.isPremium)
                await media.activateDownloads(premium: premium.isPremium)
                await reminders.setPremium(premium.isPremium, store: store)
                await reminders.refresh(store: store)
            } }
        }
        .onChange(of: premium.isPremium) { _, value in
            Task {
                await media.setPremium(value)
                await media.activateDownloads(premium: value, offerPrompt: true)
                await reminders.setPremium(value, store: store)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await reminders.refresh(store: store) }
        }
    }

    private func consumeReminder() {
        guard let destination = inbox.pending else { return }
        inbox.pending = nil
        if let id = destination.wordID, store.word(withID: id) != nil {
            showingReminders = false
            navigation.openReminder(wordID: id, englishFirst: destination.englishFirst)
        } else {
            navigation.tab = 3
            showingReminders = true
        }
    }
}
