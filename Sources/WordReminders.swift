import Foundation
import Observation
import UIKit
import UserNotifications

protocol ReminderNotificationCenter: Sendable {
    func authorization() async -> UNAuthorizationStatus
    func requestPermission() async throws -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ ids: [String]) async
    func removeDelivered(_ ids: [String]) async
    func deliveredIDs() async -> [String]
}

struct SystemReminderCenter: ReminderNotificationCenter, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ ids: [String]) async { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func removeDelivered(_ ids: [String]) async { center.removeDeliveredNotifications(withIdentifiers: ids) }
    func deliveredIDs() async -> [String] { await center.deliveredNotifications().map(\.request.identifier) }
}

enum ReminderNotification {
    static let prefix = "swedish3000.word-reminder."
    static let wordKey = "wordID"
    static let promptKey = "prompt"
    static let category = "WORD_PRACTICE"

    static func content(word: ReminderWord, settings: WordReminderSettings,
                        temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let text = WordReminderPlan.text(for: word, prompt: settings.prompt)
        content.title = text.title
        content.body = text.body
        content.categoryIdentifier = category
        content.threadIdentifier = "word-practice"
        content.userInfo = [wordKey: word.id, promptKey: settings.prompt.rawValue]
        if settings.sound { content.sound = .default }
        if settings.showArtwork, let source = word.thumbnail {
            // The notification service can move attachment files. Never hand it
            // an original, an imported revision, or a shared thumbnail directly.
            let fileExtension = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
            let copy = temporaryDirectory.appending(path: "reminder-\(UUID().uuidString).\(fileExtension)")
            try FileManager.default.copyItem(at: source, to: copy)
            do {
                content.attachments = [try UNNotificationAttachment(identifier: "word-artwork", url: copy,
                    options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false])]
            } catch {
                try? FileManager.default.removeItem(at: copy)
                throw error
            }
        }
        return content
    }

    static func cleanStagingFiles(_ content: UNMutableNotificationContent) {
        // Keep the source alive until add() finishes and the system has ingested it.
        for attachment in content.attachments where
            attachment.url.path.hasPrefix(FileManager.default.temporaryDirectory.path) &&
            attachment.url.lastPathComponent.hasPrefix("reminder-") {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }
}

struct ReminderScheduleResult: Sendable {
    var count = 0
    var nextDate: Date?
    var wordIDs: [String] = []
    var message: String?
    var missingArtwork = 0
}

actor WordReminderScheduler {
    private let center: any ReminderNotificationCenter
    private var revision = 0
    init(center: any ReminderNotificationCenter = SystemReminderCenter()) { self.center = center }

    func replace(words: [ReminderWord], settings: WordReminderSettings, now: Date = .now,
                 calendar: Calendar = .current, avoiding: [String] = []) async -> ReminderScheduleResult {
        revision += 1
        let token = revision
        let pending = await center.pending()
        guard token == revision else { return ReminderScheduleResult() }
        let owned = pending.filter { $0.identifier.hasPrefix(ReminderNotification.prefix) }.map(\.identifier)
        await center.removePending(owned)
        guard token == revision, settings.enabled else { return ReminderScheduleResult() }
        guard [.authorized, .provisional, .ephemeral].contains(await center.authorization()) else {
            return ReminderScheduleResult(message: "Notifications are off for 3000 Swedish Words. Allow them in iPhone Settings.")
        }
        guard token == revision else { return ReminderScheduleResult() }
        var rng = SystemRandomNumberGenerator()
        let plan = WordReminderPlan.make(words: words, settings: settings, now: now,
            calendar: calendar, avoiding: avoiding, using: &rng)
        guard !plan.isEmpty else { return ReminderScheduleResult(message: "No words match this selection. Choose another group or letter.") }
        var result = ReminderScheduleResult()
        // Stay below iOS's pending-request budget and leave unrelated requests alone.
        let available = max(0, min(57, 64 - (pending.count - owned.count)))
        guard available >= 2 else { return ReminderScheduleResult(message: "There is no room for more reminders. Please try again later.") }
        for item in plan.prefix(available - 1) {
            guard token == revision else { return result }
            let content: UNMutableNotificationContent
            do { content = try ReminderNotification.content(word: item.word, settings: settings) }
            catch {
                // A broken personal picture must not prevent the word reminder.
                var textOnly = settings; textOnly.showArtwork = false
                content = try! ReminderNotification.content(word: item.word, settings: textOnly)
                result.missingArtwork += 1
            }
            defer { ReminderNotification.cleanStagingFiles(content) }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let request = UNNotificationRequest(identifier: ReminderNotification.prefix + UUID().uuidString,
                content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                if token != revision {
                    await center.removePending([request.identifier])
                    return result
                }
                result.count += 1
                result.nextDate = result.nextDate ?? item.date
                result.wordIDs.append(item.word.id)
            } catch { result.message = "Some reminders couldn’t be scheduled. Open Word reminders and try Save again." }
        }
        if token == revision, let last = plan.prefix(available - 1).last,
           let refreshDate = calendar.date(byAdding: .day, value: 1, to: last.date) {
            let content = UNMutableNotificationContent()
            content.title = "Ready for more Swedish?"
            content.body = "Open 3000 Swedish Words to refresh your next two weeks of word reminders."
            content.userInfo = ["refreshReminders": true]
            content.threadIdentifier = "word-practice"
            if settings.sound { content.sound = .default }
            let request = UNNotificationRequest(identifier: ReminderNotification.prefix + UUID().uuidString,
                content: content, trigger: UNCalendarNotificationTrigger(dateMatching:
                    calendar.dateComponents([.year, .month, .day, .hour, .minute], from: refreshDate), repeats: false))
            do {
                try await center.add(request)
                if token != revision { await center.removePending([request.identifier]) }
            } catch { result.message = "The final refresh reminder couldn’t be scheduled. Your word reminders are ready." }
        }
        return result
    }

    func sample(word: ReminderWord, settings: WordReminderSettings) async throws {
        let content = try ReminderNotification.content(word: word, settings: settings)
        defer { ReminderNotification.cleanStagingFiles(content) }
        try await center.add(UNNotificationRequest(identifier: ReminderNotification.prefix + "sample",
            content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
}

@MainActor
@Observable
final class WordReminders {
    private(set) var settings: WordReminderSettings
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var busy = false
    private(set) var nextDate: Date?
    private(set) var scheduledCount = 0
    private(set) var message: String?
    private(set) var missingArtwork = 0
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let center: any ReminderNotificationCenter
    @ObservationIgnored private let scheduler: WordReminderScheduler
    @ObservationIgnored private var operation = 0
    @ObservationIgnored private var recentIDs: [String]
    @ObservationIgnored private var premiumAccess = false
    @ObservationIgnored private var lastAppliedAccess: Bool?
    private static let settingsKey = "wordReminderSettings.v1"

    init(defaults: UserDefaults = .standard, center: any ReminderNotificationCenter = SystemReminderCenter()) {
        self.defaults = defaults; self.center = center
        scheduler = WordReminderScheduler(center: center)
        settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(WordReminderSettings.self, from: $0) }?.normalized ?? WordReminderSettings()
        recentIDs = defaults.stringArray(forKey: "wordReminderRecentIDs") ?? []
    }

    func checkPermission() async { authorization = await center.authorization() }

    func setPremium(_ value: Bool, store: StudyStore) async {
        guard lastAppliedAccess != value else { return }
        lastAppliedAccess = value
        premiumAccess = value
        // Remove delivered pictures too, so a refund cannot leave paid artwork
        // visible in the notification list. Basic text reminders remain free.
        if !value {
            let delivered = await center.deliveredIDs()
            await center.removeDelivered(delivered.filter { $0.hasPrefix(ReminderNotification.prefix) })
        }
        if settings.enabled { await rebuild(store: store) }
    }

    func snapshots(from store: StudyStore) -> [ReminderWord] {
        var revisions: [String: URL] = [:]
        for revision in store.artworks where revision.isActive && revisions[revision.wordID] == nil {
            revisions[revision.wordID] = store.artworkDirectory.appending(path: revision.filename)
        }
        return store.words.map { word in
            let personal = revisions[word.id].flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
            // iOS derives its thumbnail from the attachment. The existing 768px
            // picture also keeps the mnemonic text legible when expanded.
            return ReminderWord(id: word.id, english: word.english, swedish: word.swedish,
                status: word.statusRaw, thumbnail: PremiumAccess.hasLesson(word.english, premium: premiumAccess) ?
                    (personal ?? BundledArtwork.url(for: word.id)) : nil)
        }
    }

    func save(_ draft: WordReminderSettings, store: StudyStore) async -> Bool {
        guard !busy else { return false }
        busy = true
        message = nil
        defer { busy = false }
        var value = draft.normalized
        if value.enabled {
            await checkPermission()
            if authorization == .notDetermined {
                do { _ = try await center.requestPermission(); await checkPermission() }
                catch { message = "Notification permission couldn’t be checked. Please try again."; return false }
            }
            if ![.authorized, .provisional, .ephemeral].contains(authorization) {
                message = "Allow notifications in iPhone Settings, then return here and save."
                return false
            }
            guard !WordReminderPlan.eligible(snapshots(from: store), settings: value).isEmpty else {
                message = "No words match this selection. Choose another group or letter."
                return false
            }
        } else { value.enabled = false }
        settings = value
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.settingsKey)
        await rebuild(store: store)
        return message == nil
    }

    func refresh(store: StudyStore) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await checkPermission()
        // No permission prompt on startup or foregrounding.
        guard settings.enabled else { return }
        await rebuild(store: store)
    }

    private func rebuild(store: StudyStore) async {
        operation += 1
        let token = operation
        let words = settings.enabled ? snapshots(from: store) : []
        let result = await scheduler.replace(words: words, settings: settings, avoiding: recentIDs)
        guard token == operation else { return }
        scheduledCount = result.count
        nextDate = result.nextDate
        message = result.message
        missingArtwork = result.missingArtwork
        if !result.wordIDs.isEmpty {
            recentIDs = Array((recentIDs + result.wordIDs).suffix(112))
            defaults.set(recentIDs, forKey: "wordReminderRecentIDs")
        }
    }

    func sendSample(store: StudyStore, draft: WordReminderSettings) async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        await checkPermission()
        if authorization == .notDetermined {
            do { _ = try await center.requestPermission(); await checkPermission() }
            catch { message = error.localizedDescription; return }
        }
        guard [.authorized, .provisional, .ephemeral].contains(authorization) else {
            message = "Allow notifications in iPhone Settings to try a sample."; return
        }
        // Prefer a concrete word with a thumbnail for a useful first preview.
        let words = WordReminderPlan.eligible(snapshots(from: store), settings: draft)
        guard let word = words.first(where: { $0.english == "apple" }) ?? words.first else {
            message = "No words match this selection. Choose another group or letter."; return
        }
        do {
            try await scheduler.sample(word: word, settings: draft)
            message = "Sample scheduled in 5 seconds. Close this screen or lock your phone to see it."
        } catch { message = "The sample couldn’t be scheduled: \(error.localizedDescription)" }
    }
}

struct ReminderDestination: Equatable {
    let id = UUID()
    let wordID: String?
    let englishFirst: Bool
}

@MainActor
@Observable
final class ReminderInbox {
    static let shared = ReminderInbox()
    var pending: ReminderDestination?
    func receive(_ info: [AnyHashable: Any]) {
        if let id = info[ReminderNotification.wordKey] as? String {
            let prompt = (info[ReminderNotification.promptKey] as? String).flatMap(ReminderPrompt.init(rawValue:)) ?? .swedish
            pending = ReminderDestination(wordID: id, englishFirst: prompt.englishFirst)
        } else if info["refreshReminders"] as? Bool == true {
            pending = ReminderDestination(wordID: nil, englishFirst: false)
        }
    }
}

final class ReminderAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: ReminderNotification.category,
            actions: [UNNotificationAction(identifier: "PRACTICE", title: "Practise word", options: .foreground)], intentIdentifiers: [])])
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(notification.request.content.sound == nil ? [.banner, .list] : [.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier || response.actionIdentifier == "PRACTICE" else {
            completionHandler(); return
        }
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            ReminderInbox.shared.receive(info)
            completionHandler()
        }
    }
}
