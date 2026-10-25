import Foundation
import Observation
import StoreKit

enum PremiumAccess {
    static func isPreview(_ english: String) -> Bool { EnglishAlphabet.initial(english) == "A" }
    static func hasLesson(_ english: String, premium: Bool) -> Bool { premium || isPreview(english) }
}

struct PremiumOffer: Equatable {
    let price: String
}

enum PremiumPurchaseOutcome { case purchased, cancelled, pending }

@MainActor
protocol PremiumClient: AnyObject {
    func offer() async throws -> PremiumOffer?
    func hasPurchase() async -> Bool
    func purchase() async throws -> PremiumPurchaseOutcome
    func restore() async throws
    func updates() -> AsyncStream<Void>
}

@MainActor
final class ApplePremiumClient: PremiumClient {
    private var product: Product?

    func offer() async throws -> PremiumOffer? {
        let products = try await Product.products(for: [PremiumStore.productID])
        product = products.first { $0.id == PremiumStore.productID && $0.type == .nonConsumable }
        return product.map { PremiumOffer(price: $0.displayPrice) }
    }

    func hasPurchase() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PremiumStore.productID,
               transaction.productType == .nonConsumable,
               transaction.revocationDate == nil { return true }
        }
        return false
    }

    func purchase() async throws -> PremiumPurchaseOutcome {
        guard let product else { throw StoreKitError.notAvailableInStorefront }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification,
                  transaction.productID == PremiumStore.productID,
                  transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else { throw StoreKitError.notEntitled }
            // StoreKit retains the durable entitlement independently of app storage.
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw StoreKitError.unknown
        }
    }

    func restore() async throws { try await AppStore.sync() }

    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    if case .verified(let transaction) = result,
                       transaction.productID == PremiumStore.productID {
                        continuation.yield(())
                        await transaction.finish()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
@Observable
final class PremiumStore {
    static let productID = "com.linapps.swedish3000.complete"

    // Compiled into the private Personal configuration only. Launch arguments,
    // preferences and the customer Debug/Release builds cannot enable this.
    static var personalBuildEnabled: Bool {
        #if DEBUG && SWEDISHCARDS_PERSONAL
        true
        #else
        false
        #endif
    }
    let isPersonal: Bool
    private(set) var isPremium = false
    private(set) var checked = false
    private(set) var offer: PremiumOffer?
    private(set) var busy = false
    private(set) var loadingPrice = false
    private(set) var message: String?
    private(set) var pending = false
    @ObservationIgnored private let client: any PremiumClient
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private var refreshRevision = 0

    var isLocalTesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SWEDISHCARDS_STOREKIT_TESTING"] == "1"
        #else
        false
        #endif
    }

    init(client: (any PremiumClient)? = nil) {
        self.client = client ?? ApplePremiumClient()
        // Explicitly injected clients retain real entitlement semantics in tests.
        isPersonal = client == nil && Self.personalBuildEnabled
        if isPersonal { isPremium = true; checked = true }
    }

    deinit { listener?.cancel() }

    func hasLesson(_ word: VocabularyWord) -> Bool {
        PremiumAccess.hasLesson(word.english, premium: isPremium)
    }

    func start() async {
        if isPersonal { await refreshAccess(); return }
        if listener == nil {
            let updates = client.updates()
            listener = Task { [weak self] in
                for await _ in updates {
                    guard !Task.isCancelled else { return }
                    await self?.refreshAccess()
                }
            }
        }
        await refreshAccess()
    }

    func refreshAccess() async {
        if isPersonal {
            isPremium = true; checked = true; pending = false; message = nil
            return
        }
        refreshRevision += 1
        let revision = refreshRevision
        let owns = await client.hasPurchase()
        guard revision == refreshRevision else { return }
        let wasPremium = isPremium
        isPremium = owns
        checked = true
        if owns { pending = false; message = nil }
        else if wasPremium { message = "Premium is no longer active for this Apple Account. Your free cards remain available." }
    }

    func loadOffer() async {
        guard !isPersonal, !loadingPrice, offer == nil else { return }
        loadingPrice = true
        defer { loadingPrice = false }
        do {
            offer = try await client.offer()
            if offer == nil, !isPremium { message = "The price isn’t available yet. Try again when the store is connected. Your free cards are ready." }
            else if !pending { message = nil }
        } catch { if !isPremium { message = "The store couldn’t be reached. Please check your connection and try again." } }
    }

    func purchase() async {
        guard !isPersonal, !busy, !loadingPrice, offer != nil, !isPremium else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await client.purchase() {
            case .purchased:
                await refreshAccess()
                if !isPremium { message = "We’re checking your purchase. Try Restore Purchases if Premium doesn’t appear." }
                else { message = "Premium unlocked for the available Swedish lessons." }
            case .cancelled: break
            case .pending:
                pending = true
                message = "Waiting for purchase approval. Premium will unlock when the store confirms it."
            }
        } catch StoreKitError.userCancelled {
            // Dismissing Apple's purchase sheet is an ordinary user choice.
        } catch { message = "The purchase couldn’t be completed or verified. Please try again or use Restore Purchases." }
    }

    func restore() async {
        guard !isPersonal, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            try await client.restore()
            await refreshAccess()
            message = isPremium ? "Premium restored. All your complete lessons are unlocked." :
                "No Premium purchase was found. Use the Apple Account that originally purchased 3000 Swedish Words Premium."
        } catch { message = "Purchases couldn’t be restored. Check your connection and Apple Account, then try again." }
    }
}
