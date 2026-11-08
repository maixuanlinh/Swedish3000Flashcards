import XCTest
import StoreKit
import StoreKitTest
import UserNotifications
import UIKit
@testable import SwedishCards

@MainActor
private final class FakePremiumClient: PremiumClient {
    var owns = false
    var price: PremiumOffer? = PremiumOffer(price: "€11.99")
    var outcome = PremiumPurchaseOutcome.cancelled
    var purchaseFails = false
    var restoreFails = false
    var purchaseCalls = 0
    var restoreCalls = 0
    var entitlementTemporarilyUnavailable = false
    var holdEntitlementReads = false
    var waitingReads: [CheckedContinuation<Bool, Never>] = []
    let events = AsyncStream<Void>.makeStream()
    func offer() async throws -> PremiumOffer? { price }
    func hasPurchase() async -> Bool {
        if holdEntitlementReads { return await withCheckedContinuation { waitingReads.append($0) } }
        return entitlementTemporarilyUnavailable ? false : owns
    }
    func purchase() async throws -> PremiumPurchaseOutcome {
        purchaseCalls += 1
        if purchaseFails { throw StoreKitError.notEntitled }
        if case .purchased = outcome { owns = true }
        return outcome
    }
    func restore() async throws { restoreCalls += 1; if restoreFails { throw StoreKitError.unknown } }
    func updates() -> AsyncStream<Void> { events.stream }
}

private actor PremiumReminderCenter: ReminderNotificationCenter {
    var removed: [String] = []
    func authorization() async -> UNAuthorizationStatus { .authorized }
    func requestPermission() async throws -> Bool { true }
    func pending() async -> [UNNotificationRequest] { [] }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePending(_ ids: [String]) async {}
    func removeDelivered(_ ids: [String]) async { removed += ids }
    func deliveredIDs() async -> [String] { ["unrelated", ReminderNotification.prefix + "old-paid-picture"] }
    func removedIDs() -> [String] { removed }
}

@MainActor
final class PremiumStoreTests: XCTestCase {
    func testVerifiedPurchaseWaitsForDelayedEntitlementAvailability() async throws {
        let client = FakePremiumClient()
        let store = PremiumStore(client: client)
        await store.start(); await store.loadOffer()
        client.outcome = .purchased
        client.entitlementTemporarilyUnavailable = true
        let cacheUpdate = Task {
            try await Task.sleep(for: .milliseconds(75))
            client.entitlementTemporarilyUnavailable = false
        }
        await store.purchase()
        try await cacheUpdate.value
        XCTAssertTrue(store.isPremium)
        XCTAssertFalse(store.busy)
        XCTAssertTrue(store.message?.contains("unlocked") == true)
    }

    func testOverlappingChecksDoNotReturnBeforeCurrentAccessIsApplied() async throws {
        let client = FakePremiumClient()
        client.holdEntitlementReads = true
        let store = PremiumStore(client: client)
        var firstReturned = false
        let first = Task { await store.refreshAccess(); firstReturned = true }
        for _ in 0..<100 where client.waitingReads.count < 1 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(client.waitingReads.count, 1)
        let second = Task { await store.refreshAccess() }
        for _ in 0..<100 where client.waitingReads.count < 2 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(client.waitingReads.count, 2)
        client.waitingReads.removeFirst().resume(returning: false)
        for _ in 0..<100 where client.waitingReads.count < 2 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(firstReturned)
        XCTAssertFalse(store.checked)
        client.waitingReads.removeFirst().resume(returning: true)
        client.waitingReads.removeFirst().resume(returning: true)
        await first.value
        await second.value
        XCTAssertTrue(store.checked)
        XCTAssertTrue(store.isPremium)
    }

    func testFreePreviewIsExactlyAll211AWordsAndBasicCatalogStaysComplete() throws {
        let seeds = try StudyStore.readSeeds()
        XCTAssertEqual(seeds.count, 3000)
        XCTAssertEqual(seeds.filter { PremiumAccess.isPreview($0.english) }.count, 211)
        XCTAssertTrue(PremiumAccess.hasLesson("abandon", premium: false))
        XCTAssertFalse(PremiumAccess.hasLesson("book", premium: false))
        XCTAssertTrue(PremiumAccess.hasLesson("book", premium: true))
        XCTAssertTrue(PremiumAccess.hasLesson("zoo", premium: true))
    }

    func testCancellationPendingAndFailureNeverGrantAccess() async {
        let client = FakePremiumClient(); let store = PremiumStore(client: client)
        await store.start(); await store.loadOffer()
        await store.purchase()
        XCTAssertFalse(store.isPremium); XCTAssertNil(store.message)
        client.outcome = .pending; await store.purchase()
        XCTAssertFalse(store.isPremium); XCTAssertTrue(store.pending)
        XCTAssertTrue(store.message?.contains("approval") == true)
        client.purchaseFails = true; await store.purchase()
        XCTAssertFalse(store.isPremium); XCTAssertNotNil(store.message)
        XCTAssertFalse(store.busy)
    }

    func testUnavailableProductDisablesPurchaseButRestoreRemainsAvailable() async {
        let client = FakePremiumClient(); client.price = nil
        let store = PremiumStore(client: client)
        await store.loadOffer(); await store.purchase()
        XCTAssertNil(store.offer); XCTAssertEqual(client.purchaseCalls, 0)
        XCTAssertNotNil(store.message)
        client.owns = true; await store.restore()
        XCTAssertTrue(store.isPremium); XCTAssertEqual(client.restoreCalls, 1)
    }

    func testVerifiedPurchaseRestoreAndLiveRevocationUpdateAccess() async throws {
        let client = FakePremiumClient(); let store = PremiumStore(client: client)
        await store.start(); await store.loadOffer()
        client.outcome = .purchased; await store.purchase()
        XCTAssertTrue(store.isPremium)
        await store.purchase(); XCTAssertEqual(client.purchaseCalls, 1)
        let recreated = PremiumStore(client: client); await recreated.restore()
        XCTAssertTrue(recreated.isPremium)
        client.owns = false; client.events.continuation.yield(())
        for _ in 0..<100 where store.isPremium { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isPremium)
        XCTAssertTrue(store.message?.contains("no longer active") == true)
    }

    func testRestoreWithoutPurchaseAndRestoreFailureGiveRecoverableMessages() async {
        let client = FakePremiumClient(); let store = PremiumStore(client: client)
        await store.restore()
        XCTAssertFalse(store.isPremium); XCTAssertTrue(store.message?.contains("No Premium purchase") == true)
        client.restoreFails = true; await store.restore()
        XCTAssertFalse(store.isPremium); XCTAssertFalse(store.busy)
        XCTAssertTrue(store.message?.contains("couldn’t be restored") == true)
    }

    func testNotificationArtworkFollowsAccessAndClearsDeliveredPaidPictures() async throws {
        let directory = URL.temporaryDirectory.appending(path: "ReminderArt-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds(), artworkDirectory: directory)
        let name = "premium-reminder-\(UUID())"; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let center = PremiumReminderCenter(); let reminders = WordReminders(defaults: defaults, center: center)
        let book = try XCTUnwrap(data.words.first { $0.english == "book" })
        let apple = try XCTUnwrap(data.words.first { $0.english == "apple" })
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }.pngData()!
        for word in [apple, book] {
            try await data.importArtwork(image, for: word, prompt: "Local test artwork", memoryHook: "test", source: "Test fixture")
        }
        let free = reminders.snapshots(from: data)
        XCTAssertNil(free.first { $0.id == book.id }?.thumbnail)
        XCTAssertNotNil(free.first { $0.id == apple.id }?.thumbnail)
        await reminders.setPremium(true, store: data)
        XCTAssertNotNil(reminders.snapshots(from: data).first { $0.id == book.id }?.thumbnail)
        await reminders.setPremium(false, store: data)
        XCTAssertNil(reminders.snapshots(from: data).first { $0.id == book.id }?.thumbnail)
        let removed = await center.removedIDs()
        XCTAssertEqual(removed, [ReminderNotification.prefix + "old-paid-picture"])
        XCTAssertTrue(data.events.isEmpty)
    }
}

@MainActor
final class StoreKitPremiumTests: XCTestCase {
    private var session: SKTestSession!
    override func setUpWithError() throws {
        session = try SKTestSession(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: "SwedishCards", withExtension: "storekit")))
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        session.storefront = "FIN"
    }
    override func tearDownWithError() throws { session.clearTransactions(); session = nil }

    func testActualStoreKitPurchaseNewInstanceRestoreAndRefund() async throws {
        let premium = PremiumStore(); await premium.start(); await premium.loadOffer()
        XCTAssertNotNil(premium.offer); XCTAssertFalse(premium.isPremium)
        await premium.purchase()
        XCTAssertTrue(premium.isPremium, premium.message ?? "No entitlement")
        let recreated = PremiumStore(); await recreated.start()
        XCTAssertTrue(recreated.isPremium)
        await recreated.restore(); XCTAssertTrue(recreated.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        for _ in 0..<100 where premium.isPremium { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(premium.isPremium)
        await recreated.refreshAccess(); XCTAssertFalse(recreated.isPremium)
    }

    func testActualStoreKitPendingApprovalUnlocksOnlyAfterApproval() async throws {
        session.askToBuyEnabled = true
        let premium = PremiumStore(); await premium.start(); await premium.loadOffer()
        await premium.purchase()
        XCTAssertTrue(premium.pending); XCTAssertFalse(premium.isPremium)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        for _ in 0..<100 where !premium.isPremium { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertTrue(premium.isPremium); XCTAssertFalse(premium.pending)
    }

    func testActualStoreKitCancellationDoesNotShowAnError() async throws {
        let premium = PremiumStore(); await premium.start(); await premium.loadOffer()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await premium.purchase()
        XCTAssertFalse(premium.isPremium)
        XCTAssertNil(premium.message)
    }

    func testActualStoreKitFailureAndEmptyRestoreDoNotUnlock() async throws {
        let premium = PremiumStore(); await premium.start(); await premium.loadOffer()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await premium.purchase()
        XCTAssertFalse(premium.isPremium); XCTAssertNotNil(premium.message)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        await premium.restore()
        XCTAssertFalse(premium.isPremium); XCTAssertTrue(premium.message?.contains("No Premium purchase") == true)
    }
}

@MainActor
final class PersonalAccessTests: XCTestCase {
    func testDefaultStoreMatchesCompiledBuildAndSurvivesNewInstance() async {
        let store = PremiumStore()
        XCTAssertEqual(store.isPersonal, PremiumStore.personalBuildEnabled)
        if PremiumStore.personalBuildEnabled {
            XCTAssertTrue(store.isPremium)
            XCTAssertTrue(store.checked)
            await store.start()
            await store.refreshAccess()
            await store.loadOffer()
            await store.purchase()
            await store.restore()
            XCTAssertTrue(store.isPremium)
            XCTAssertNil(store.offer)
            XCTAssertNil(store.message)
            XCTAssertFalse(store.busy)
            let fresh = PremiumStore()
            await fresh.start()
            XCTAssertTrue(fresh.isPremium)
            let data = try! StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
            XCTAssertEqual(data.words.filter { fresh.hasLesson($0) }.count, 3000)
        } else {
            XCTAssertFalse(store.isPersonal)
            XCTAssertFalse(store.isPremium)
            XCTAssertFalse(store.checked)
        }
    }

    func testInjectedClientsAlwaysKeepCustomerEntitlementRules() async {
        let client = FakePremiumClient()
        let store = PremiumStore(client: client)
        XCTAssertFalse(store.isPersonal)
        await store.start()
        XCTAssertFalse(store.isPremium)
        client.owns = true
        await store.refreshAccess()
        XCTAssertTrue(store.isPremium)
        client.owns = false
        await store.refreshAccess()
        XCTAssertFalse(store.isPremium)
    }
}
