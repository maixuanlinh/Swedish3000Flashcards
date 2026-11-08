import XCTest
import SwiftData
import UIKit
@testable import SwedishCards

@MainActor
final class SwedishContentTests: XCTestCase {
    func testCompleteCollectionUseStableSwedishIDsAndMatchingExamples() throws {
        let seeds = try StudyStore.readSeeds()
        XCTAssertEqual(seeds.count, 3000)
        XCTAssertEqual(Set(seeds.map(\.id)).count, seeds.count)
        XCTAssertTrue(Set(1...3000) == Set(seeds.map(\.sourceID)))
        XCTAssertTrue(seeds.allSatisfy { $0.id.hasPrefix("sv-") && !$0.swedish.isEmpty && !$0.sentence.isEmpty && !$0.sentenceEnglish.isEmpty })
        XCTAssertEqual(seeds.first?.english, "a, an")
        XCTAssertEqual(seeds.first?.swedish, "en / ett")
        XCTAssertEqual(seeds.first?.sentence, "Jag ser en katt och ett äpple.")
        XCTAssertEqual(seeds.first { $0.id == "sv-0136" }?.swedish, "ett äpple")
        XCTAssertEqual(seeds.first { $0.id == "sv-0211" }?.english, "awful")
        XCTAssertEqual(seeds.first { $0.id == "sv-0212" }?.swedish, "en bebis")
        XCTAssertEqual(seeds.first { $0.id == "sv-2627" }?.english, "system")
        XCTAssertEqual(seeds.first { $0.id == "sv-1461" }?.swedish, "en sort")
        XCTAssertEqual(seeds.first { $0.id == "sv-1462" }?.swedish, "snäll")
        XCTAssertEqual(seeds.first { $0.id == "sv-1525" }?.swedish, "ligga")
        XCTAssertEqual(seeds.first { $0.id == "sv-1526" }?.swedish, "ljuga")
    }

    func testArtworkCoverageIsHonestAndPromptsAreSwedish() async throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        XCTAssertEqual(BundledArtwork.records.count, 3000)
        XCTAssertLessThanOrEqual(BundledArtwork.records.count, store.words.count)
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-0001"))
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-1309"))
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-1650"))
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-2627"))
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-2628"))
        XCTAssertNotNil(BundledArtwork.mediaKey(for: "sv-3000"))
        XCTAssertNil(store.word(withID: "sv-9999"))
        let mediaURL = try XCTUnwrap(Bundle.main.url(forResource: "lesson-media", withExtension: "json"))
        let mediaCatalog = try JSONDecoder().decode(LessonMediaManifest.self, from: Data(contentsOf: mediaURL)).validated()
        for id in BundledArtwork.records.keys {
            XCTAssertNotNil(store.word(withID: id))
            let key = try XCTUnwrap(BundledArtwork.mediaKey(for: id))
            XCTAssertNotNil(mediaCatalog.itemByKey[key])
        }
        XCTAssertNil(BundledArtwork.mediaKey(for: "fi-0001"))
        let starterKey = try XCTUnwrap(BundledArtwork.mediaKey(for: "sv-0001"))
        let starterImage = try await LessonMedia.shared.data(for: starterKey)
        XCTAssertNotNil(UIImage(data: starterImage))
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
        let next = WordSeed(id: "sv-9999", sourceID: 9999, order: 3000, english: "table", swedish: "ett bord", sentence: "Boken ligger på bordet.", sentenceEnglish: "The book is on the table.", topic: "Vocabulary", symbol: "person", imageName: nil, imageContainsText: false)
        let expanded = try StudyStore(container: container, seeds: seeds + [next])
        XCTAssertEqual(expanded.words.count, seeds.count + 1)
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
