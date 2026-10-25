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

    func openReminder(wordID: String, englishFirst: Bool) {
        scope = .all
        startingLetter = nil
        topic = nil
        requestedIDs = [wordID]
        promptEnglishFirst = englishFirst
        request += 1
        tab = 0
    }

    func review(_ scope: ReviewScope, ids: [String]? = nil) {
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
        promptEnglishFirst = nil
        self.scope = scope
        startingLetter = letter
        self.topic = topic
        requestedIDs = nil
        request += 1
    }
}

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @Environment(WordReminders.self) private var reminders
    @Environment(PremiumStore.self) private var premium
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
        }
        .environment(navigation)
        .tint(Palette.forest)
        .sheet(isPresented: $showingReminders) { WordReminderSettingsView(settings: reminders.settings) }
        .task {
            consumeReminder()
            await premium.start()
            await reminders.setPremium(premium.isPremium, store: store)
            await reminders.refresh(store: store)
        }
        .onChange(of: inbox.pending) { _, _ in consumeReminder() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task {
                await premium.refreshAccess()
                await reminders.setPremium(premium.isPremium, store: store)
                await reminders.refresh(store: store)
            } }
        }
        .onChange(of: premium.isPremium) { _, value in
            Task { await reminders.setPremium(value, store: store) }
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
            navigation.tab = 2
            showingReminders = true
        }
    }
}
