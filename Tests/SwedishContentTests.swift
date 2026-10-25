import XCTest
import SwiftData
@testable import SwedishCards

@MainActor
final class SwedishContentTests: XCTestCase {
    func testCurrentASetUsesStableSwedishIDsAndMatchingExamples() throws {
        let seeds = try StudyStore.readSeeds()
        XCTAssertEqual(seeds.count, 211)
        XCTAssertEqual(Set(seeds.map(\.id)).count, 211)
        XCTAssertEqual(Set(seeds.map(\.sourceID)), Set(1...211))
        XCTAssertTrue(seeds.allSatisfy { $0.id.hasPrefix("sv-") && !$0.swedish.isEmpty && !$0.sentence.isEmpty && !$0.sentenceEnglish.isEmpty })
        XCTAssertEqual(seeds.first?.english, "a, an")
        XCTAssertEqual(seeds.first?.swedish, "en / ett")
        XCTAssertEqual(seeds.first?.sentence, "Jag ser en katt och ett äpple.")
        XCTAssertEqual(seeds.first { $0.id == "sv-0136" }?.swedish, "ett äpple")
        XCTAssertEqual(seeds.last?.english, "awful")
    }

    func testArtworkCoverageIsHonestAndPromptsAreSwedish() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        XCTAssertGreaterThanOrEqual(BundledArtwork.records.count, 1)
        XCTAssertLessThanOrEqual(BundledArtwork.records.count, store.words.count)
        XCTAssertNotNil(BundledArtwork.image(for: "sv-0001"))
        XCTAssertNil(BundledArtwork.image(for: "sv-0212"))
        for id in BundledArtwork.records.keys {
            XCTAssertNotNil(store.word(withID: id))
            XCTAssertNotNil(BundledArtwork.image(for: id))
        }
        XCTAssertNil(BundledArtwork.image(for: "fi-0001"))
        for word in store.words {
            XCTAssertFalse(ArtworkPromptBuilder.memoryHook(for: word).isEmpty)
            XCTAssertTrue(ArtworkPromptBuilder.make(for: word).contains("Swedish"))
        }
    }

    func testSwedishSearchRatingsAndCatalogExpansionPreserveProgress() throws {
        let container = try StudyStore.makeContainer(inMemory: true)
        let seeds = try StudyStore.readSeeds()
        let first = try StudyStore(container: container, seeds: seeds)
        let abandon = try XCTUnwrap(first.word(withID: "sv-0002"))
        XCTAssertTrue(first.searchWords("ÖVERGE").contains { $0.id == abandon.id })
        try first.rate(abandon, as: .known)
        let next = WordSeed(id: "sv-0212", sourceID: 212, order: 211, english: "baby", swedish: "en bebis", sentence: "En bebis sover.", sentenceEnglish: "A baby is sleeping.", topic: "Family", symbol: "person", imageName: nil, imageContainsText: false)
        let expanded = try StudyStore(container: container, seeds: seeds + [next])
        XCTAssertEqual(expanded.words.count, 212)
        XCTAssertEqual(expanded.word(withID: abandon.id)?.status, .known)
        XCTAssertEqual(expanded.word(withID: abandon.id)?.reviewCount, 1)
        XCTAssertEqual(expanded.word(withID: next.id)?.status, .new)
    }

    func testReminderTextAndProductIdentityAreIndependentOfFinnish() {
        let word = ReminderWord(id: "sv-0001", english: "a, an", swedish: "en / ett", status: "new", thumbnail: nil)
        let text = WordReminderPlan.text(for: word, prompt: .english)
        XCTAssertEqual(text.title, "Can you say it in Swedish?")
        XCTAssertTrue(text.body.contains("Swedish"))
        XCTAssertEqual(PremiumStore.productID, "com.linapps.swedish3000.complete")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.linapps.swedish3000")
        XCTAssertTrue(PremiumAccess.hasLesson("apple", premium: false))
        XCTAssertFalse(PremiumAccess.hasLesson("baby", premium: false))
    }
}
