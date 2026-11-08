import XCTest
import SwiftData
import UIKit
@testable import SwedishCards

@MainActor
final class StudyStoreTests: XCTestCase {

    func testTopicCoverageAndSharedProgressNeverDuplicateWords() throws {
        let seeds = try StudyStore.readSeeds()
        let container = try StudyStore.makeContainer(inMemory: true)
        let store = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(VocabularyTopic.allCases.count, 16)
        XCTAssertTrue(store.words.allSatisfy { !$0.studyTopics.isEmpty })
        let initial = store.topicProgress(words: store.words)
        XCTAssertTrue(VocabularyTopic.allCases.allSatisfy { initial[$0, default: TopicProgress()].total > 100 })
        let moving = try XCTUnwrap(store.words.first { $0.english == "move" })
        XCTAssertTrue(moving.matchesTopic(VocabularyTopic.home.rawValue))
        XCTAssertTrue(moving.matchesTopic(VocabularyTopic.commonVerbs.rawValue))
        XCTAssertFalse(moving.matchesTopic(VocabularyTopic.nature.rawValue))
        let snapshot = try store.rate(moving, as: .known)
        let updated = store.topicProgress(words: store.words)
        XCTAssertEqual(updated[.home]?.known, 1)
        XCTAssertEqual(updated[.commonVerbs]?.known, 1)
        XCTAssertEqual(store.count(.known), 1)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.words.count, 3000)
        for topic in moving.studyTopics {
            let known = store.filterSummary(words: store.words, scope: .known, topic: topic.rawValue)
            XCTAssertEqual(known.total, 1)
            XCTAssertEqual(known.count(startingWith: "M"), 1)
            let matches = store.words.filter { $0.matchesTopic(topic.rawValue) }
            XCTAssertEqual(Set(matches.map(\.id)).count, matches.count)
        }
        let reopened = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(reopened.word(withID: moving.id)?.status, .known)
        XCTAssertEqual(reopened.word(withID: moving.id)?.reviewCount, 1)
        XCTAssertEqual(reopened.events.count, 1)
        XCTAssertEqual(reopened.topicProgress(words: reopened.words)[.home]?.known, 1)
        try store.undo(snapshot)
        XCTAssertEqual(store.topicProgress(words: store.words)[.home]?.known, 0)
        XCTAssertEqual(store.count(.known), 0)
    }

    func testCoreCollectionsPartitionEssentialsAndStayBelow300Words() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let core = Set(VocabularyTopic.coreCollections)
        let groups = VocabularyTopic.coreCollections.map { topic in
            store.words.filter { $0.matchesTopic(topic.rawValue) }
        }
        XCTAssertEqual(groups.count, 7)
        XCTAssertTrue(groups.allSatisfy { !$0.isEmpty && $0.count <= 300 })
        let ids = groups.flatMap { $0.map(\.id) }
        XCTAssertEqual(ids.count, 1390)
        XCTAssertEqual(Set(ids).count, ids.count)
        for word in store.words {
            XCTAssertLessThanOrEqual(word.studyTopics.intersection(core).count, 1, word.english)
        }
        let expected: [(String, VocabularyTopic)] = [
            ("eat", .commonVerbs), ("move", .commonVerbs), ("think", .communicationVerbs),
            ("careful", .adjectives), ("quickly", .adverbs), ("because", .essentials),
            ("they", .essentials), ("may", .essentials), ("May", .timeNumbers),
            ("yellow", .timeNumbers), ("reason", .nouns), ("refrigerator", .nouns),
            ("bicycle / bike", .travel)
        ]
        for (english, topic) in expected {
            let word = try XCTUnwrap(store.words.first { $0.english == english })
            XCTAssertTrue(word.studyTopics.contains(topic), english)
        }
        let oldIDs = Set(try StudyStore.readSeeds().map(\.id))
        XCTAssertEqual(Set(store.words.map(\.id)), oldIDs)
    }

    func testTopicSearchCountsAndStudyMembershipAgree() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let searched = store.searchWords("house")
        let summary = store.filterSummary(words: searched, scope: .all, topic: VocabularyTopic.home.rawValue)
        let expected = searched.filter { $0.matchesTopic(VocabularyTopic.home.rawValue) }
        XCTAssertEqual(summary.total, expected.count)
        XCTAssertEqual(summary.letterCounts.values.reduce(0, +), expected.count)
        let apple = try XCTUnwrap(store.words.first { $0.english == "apple" })
        XCTAssertTrue(apple.matchesTopic(VocabularyTopic.shopping.rawValue))
        XCTAssertFalse(apple.matchesTopic(VocabularyTopic.work.rawValue))
        XCTAssertTrue(apple.matchesTopic(apple.topic))
        XCTAssertEqual(VocabularyTopic.topics(for: "because"), [.essentials])
        XCTAssertTrue(store.words.filter { $0.matchesTopic(VocabularyTopic.travel.rawValue) }.contains { $0.english == "reservation" })
        XCTAssertTrue(store.words.filter { $0.matchesTopic(VocabularyTopic.shopping.rawValue) }.contains { $0.english == "reservation" })
    }

    func testSavedStudySessionKeepsExactSelectionOrderFiltersAndProgressAcrossReopening() throws {
        let name = "saved-session-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try StudyStore.makeContainer(inMemory: true)
        let seeds = try StudyStore.readSeeds()
        let store = try StudyStore(container: container, seeds: seeds, sessionDefaults: defaults)
        let home = store.words.filter { $0.matchesTopic(VocabularyTopic.home.rawValue) }
        let selected = Array(home.suffix(3).reversed())
        try store.rate(selected[0], as: .learning)
        store.saveSession(ids: selected.map(\.id) + [selected[0].id, "missing"], initialCount: 5,
            scope: .all, letter: nil, topic: VocabularyTopic.home.rawValue)
        let reopened = try StudyStore(container: container, seeds: seeds, sessionDefaults: defaults)
        XCTAssertEqual(reopened.savedSession?.remainingIDs, selected.map(\.id))
        XCTAssertEqual(reopened.savedSession?.initialCount, 5)
        XCTAssertEqual(reopened.savedSession?.topic, VocabularyTopic.home.rawValue)
        XCTAssertEqual(reopened.word(withID: selected[0].id)?.status, .learning)
        XCTAssertEqual(reopened.events.count, 1)
        let navigation = AppNavigation()
        navigation.resumeStudy()
        XCTAssertTrue(navigation.resumeSessionRequested)
        navigation.openReminder(wordID: selected[1].id, englishFirst: true)
        XCTAssertTrue(navigation.isReminderSession)
        XCTAssertFalse(navigation.resumeSessionRequested)
        navigation.studyLearningWords()
        XCTAssertEqual(navigation.scope, .learning)
        XCTAssertNil(navigation.topic); XCTAssertNil(navigation.startingLetter)
    }

    func testIndexedLookupAndFilterCountsFollowRatingsAndUndo() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let first = try XCTUnwrap(store.word(withID: "sv-0001"))
        XCTAssertNil(store.word(withID: "missing"))
        XCTAssertEqual(store.initial(for: first), "A")
        XCTAssertTrue(store.searchWords("ÖVERGE").contains { $0.id == "sv-0002" })
        XCTAssertTrue(store.searchWords("ÖVERGE").contains { $0.id == "sv-0002" })
        let snapshot = try store.rate(first, as: .known)
        let remaining = store.filterSummary(words: store.words, scope: .remaining, topic: nil)
        XCTAssertEqual(remaining.total, 2999)
        XCTAssertEqual(remaining.count(startingWith: "A"), 210)
        XCTAssertEqual(remaining.count(startingWith: "X"), 0)
        XCTAssertEqual(remaining.letterCounts.values.reduce(0, +), remaining.total)
        let known = store.filterSummary(words: store.words, scope: .known, topic: first.topic)
        XCTAssertEqual(known.total, 1)
        XCTAssertEqual(known.count(startingWith: "A"), 1)
        try store.undo(snapshot)
        XCTAssertEqual(store.filterSummary(words: store.words, scope: .remaining, topic: nil).total, 3000)
        let searched = store.searchWords("ÖVERGE")
        XCTAssertEqual(store.filterSummary(words: searched, scope: .all, topic: nil).total, searched.count)
    }

    func testNavigationLookupAndFilterSummaryPerformance() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let ids = store.words.map(\.id)
        measure {
            let found = ids.reduce(0) { $0 + (store.word(withID: $1) == nil ? 0 : 1) }
            XCTAssertEqual(found, 3000)
            XCTAssertEqual(store.filterSummary(words: store.words, scope: .all, topic: nil).total, 3000)
        }
    }

    func testUnifiedFiltersApplyTogetherWithoutChangingTheCurrentTab() throws {
        let navigation = AppNavigation()
        navigation.review(.all, ids: ["sv-0003"])
        navigation.tab = 1
        let previousRequest = navigation.request
        navigation.applyFilters(scope: .new, letter: "B", topic: "Vocabulary")
        XCTAssertEqual(navigation.scope, .new)
        XCTAssertEqual(navigation.startingLetter, "B")
        XCTAssertEqual(navigation.topic, "Vocabulary")
        XCTAssertNil(navigation.requestedIDs)
        XCTAssertEqual(navigation.request, previousRequest + 1)
        XCTAssertEqual(navigation.tab, 1)
        let word = VocabularyWord(seed: try XCTUnwrap(StudyStore.readSeeds().first))
        XCTAssertTrue(ReviewScope.new.includes(word))
        word.status = .learning
        XCTAssertFalse(ReviewScope.new.includes(word))
        XCTAssertTrue(ReviewScope.remaining.includes(word))
    }
    func testFullCatalogHas3000UniqueWordsAndSentences() throws {
        let seeds = try StudyStore.readSeeds()
        XCTAssertEqual(seeds.count, 3000)
        XCTAssertEqual(Set(seeds.map(\.id)).count, 3000)
        XCTAssertTrue(seeds.allSatisfy { !$0.english.isEmpty && !$0.swedish.isEmpty && !$0.sentence.isEmpty && !$0.sentenceEnglish.isEmpty })
        XCTAssertEqual(Set(seeds.map(\.order)), Set(0..<3000))
        XCTAssertEqual(Set(seeds.map(\.sourceID)), Set(1...3000))
        XCTAssertEqual(seeds.first { $0.sourceID == 3000 }?.sentence, "Här börjar en bilfri zon.")
        XCTAssertEqual(BundledArtwork.records.count, 3000)
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: seeds)
        XCTAssertEqual(store.words.count, 3000)
        XCTAssertEqual(store.count(.new), 3000)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testAllSentenceTranslationsUpgradeAnExistingCatalogWithoutResettingProgress() throws {
        let seeds = try StudyStore.readSeeds()
        let container = try StudyStore.makeContainer(inMemory: true)
        let oldSeeds = seeds.map { seed in
            WordSeed(id: seed.id, sourceID: seed.sourceID, order: seed.order,
                english: seed.english, swedish: seed.swedish, sentence: seed.sentence, sentenceEnglish: "",
                topic: seed.topic, symbol: seed.symbol, imageName: seed.imageName, imageContainsText: seed.imageContainsText)
        }
        let original = try StudyStore(container: container, seeds: oldSeeds)
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try original.rate(try XCTUnwrap(original.word(withID: "sv-0002")), as: .known, at: reviewedAt)
        try original.rate(try XCTUnwrap(original.word(withID: "sv-3000")), as: .learning, at: reviewedAt)
        let updated = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(updated.words.count, 3000)
        for seed in seeds {
            let word = try XCTUnwrap(updated.word(withID: seed.id))
            XCTAssertFalse(word.sentenceEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, seed.id)
            XCTAssertEqual(word.sentenceEnglish, seed.sentenceEnglish, seed.id)
            XCTAssertEqual(word.sentence, seed.sentence, seed.id)
        }
        let expected = [
            "sv-0002": "They had to abandon the boat.",
            "sv-0003": "She has the ability to learn quickly.",
            "sv-0769": "I dislike loud noises.",
            "sv-1175": "It is difficult to govern a large country.",
            "sv-2999": "There are zero apples in the basket.",
            "sv-3000": "A car-free zone begins here."
        ]
        for (id, translation) in expected {
            XCTAssertEqual(updated.word(withID: id)?.sentenceEnglish, translation)
        }
        XCTAssertEqual(updated.word(withID: "sv-0002")?.status, .known)
        XCTAssertEqual(updated.word(withID: "sv-3000")?.status, .learning)
        XCTAssertEqual(updated.word(withID: "sv-0002")?.reviewCount, 1)
        XCTAssertEqual(updated.word(withID: "sv-0002")?.lastReviewed, reviewedAt)
        XCTAssertEqual(updated.events.count, 2)
        let reopened = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(reopened.events.count, 2)
        XCTAssertEqual(reopened.count(.new), 2998)
    }

    func testRatingFiltersAndUndoRestoreCompleteState() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let first = store.words[0]
        let second = store.words[1]
        let date = Date()
        let snapshot = try store.rate(first, as: .known, at: date)
        try store.rate(second, as: .learning, at: date)
        XCTAssertEqual(store.count(.known), 1)
        XCTAssertEqual(store.count(.learning), 1)
        XCTAssertEqual(store.count(.new), 2998)
        XCTAssertEqual(store.reviewWords(in: .remaining).count, 2999)
        XCTAssertEqual(store.reviewWords(in: .learning).map(\.id), [second.id])
        XCTAssertEqual(store.reviewWords(in: .known).map(\.id), [first.id])
        XCTAssertEqual(store.todayCount, 2)
        XCTAssertEqual(first.lastReviewed, date)
        XCTAssertEqual(first.reviewCount, 1)
        try store.undo(snapshot)
        XCTAssertEqual(first.status, .new)
        XCTAssertEqual(first.reviewCount, 0)
        XCTAssertNil(first.lastReviewed)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertEqual(store.knownFraction, 0)
    }

    func testUpgradeFrom100To3000NeverResetsProgressOrDuplicatesWords() throws {
        let seeds = try StudyStore.readSeeds()
        let container = try StudyStore.makeContainer(inMemory: true)
        let starterURL = try XCTUnwrap(Bundle.main.url(forResource: "starter100", withExtension: "json"))
        let currentStarter = try JSONDecoder().decode([WordSeed].self, from: Data(contentsOf: starterURL))
        // Keep the migration fixture historical even when bundled starter examples are refreshed.
        let first = try XCTUnwrap(currentStarter.first)
        let legacyFirst = WordSeed(id: first.id, sourceID: first.sourceID, order: first.order,
            english: first.english, swedish: first.swedish,
            sentence: "Tämä on vanha aloitusesimerkki.", sentenceEnglish: "",
            topic: first.topic, symbol: first.symbol,
            imageName: first.imageName, imageContainsText: first.imageContainsText)
        let oldStarter = [legacyFirst] + Array(currentStarter.dropFirst())
        let store = try StudyStore(container: container, seeds: oldStarter)
        XCTAssertEqual(store.words.count, 100)
        try store.rate(store.words[0], as: .known)
        let expanded = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(expanded.words.count, 3000)
        let upgraded = try XCTUnwrap(expanded.words.first { $0.id == oldStarter[0].id })
        let newSeed = try XCTUnwrap(seeds.first { $0.id == oldStarter[0].id })
        XCTAssertEqual(upgraded.status, .known)
        XCTAssertEqual(upgraded.reviewCount, 1)
        XCTAssertEqual(upgraded.sentence, newSeed.sentence)
        XCTAssertEqual(upgraded.sentenceEnglish, newSeed.sentenceEnglish)
        XCTAssertNotEqual(upgraded.sentence, oldStarter[0].sentence)
        XCTAssertEqual(expanded.words.first?.english, "a, an")
        XCTAssertEqual(expanded.events.first?.wordID, oldStarter[0].id)
        let again = try StudyStore(container: container, seeds: seeds)
        XCTAssertEqual(again.words.count, 3000)
        XCTAssertEqual(again.events.count, 1)
    }

    func testOnDiskProgressSurvivesReopeningDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "test.store")
        let seeds = try StudyStore.readSeeds()
        var first: StudyStore? = try StudyStore(container: StudyStore.makeContainer(url: url), seeds: seeds)
        try first!.rate(first!.words[0], as: .known)
        try first!.rate(first!.words[1], as: .learning)
        first = nil
        let reopened = try StudyStore(container: StudyStore.makeContainer(url: url), seeds: seeds)
        XCTAssertEqual(reopened.words.count, 3000)
        XCTAssertEqual(reopened.words[0].status, .known)
        XCTAssertEqual(reopened.words[1].status, .learning)
        XCTAssertEqual(reopened.events.count, 2)
    }

    func testContentUpdatesPreserveLearningHistory() throws {
        let seeds = try StudyStore.readSeeds()
        let container = try StudyStore.makeContainer(inMemory: true)
        let store = try StudyStore(container: container, seeds: [seeds[0]])
        try store.rate(store.words[0], as: .known)
        let old = seeds[0]
        let updated = WordSeed(id: old.id, sourceID: old.sourceID, order: old.order,
            english: old.english, swedish: old.swedish,
            sentence: "Hän hylkäsi suunnitelman.", sentenceEnglish: "He abandoned the plan.",
            topic: old.topic, symbol: old.symbol, imageName: nil, imageContainsText: false)
        let reopened = try StudyStore(container: container, seeds: [updated])
        XCTAssertEqual(reopened.words[0].sentence, updated.sentence)
        XCTAssertEqual(reopened.words[0].sentenceEnglish, updated.sentenceEnglish)
        XCTAssertNil(reopened.words[0].imageName)
        XCTAssertEqual(reopened.words[0].status, .known)
        XCTAssertEqual(reopened.words[0].reviewCount, 1)
        XCTAssertEqual(reopened.events.count, 1)
    }

    func testAllCardsUseEnglishDictionaryOrderIncludingMixedLearningStatuses() throws {
        let seeds = try StudyStore.readSeeds()
        let keys = seeds.map { EnglishAlphabet.sortKey($0.english) }
        XCTAssertEqual(keys, keys.sorted())
        XCTAssertEqual(Array(seeds.prefix(5).map(\.english)), ["a, an", "abandon", "ability", "able", "about"])
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: seeds)
        try store.rate(store.words[0], as: .learning)
        XCTAssertEqual(store.reviewWords(in: .remaining).first?.id, store.words[0].id)
        XCTAssertEqual(EnglishAlphabet.sortKey("T-shirt"), "tshirt")
        XCTAssertEqual(EnglishAlphabet.initial("AI"), "A")
        XCTAssertEqual(EnglishAlphabet.initial("Wi-Fi"), "W")
        XCTAssertEqual(EnglishAlphabet.sortKey("May"), EnglishAlphabet.sortKey("may"))
        XCTAssertEqual(EnglishAlphabet.sortKey("close (near)"), "close")
        XCTAssertEqual(EnglishAlphabet.sortKey("like (similar)"), "like")
        XCTAssertEqual(EnglishAlphabet.sortKey("bicycle / bike"), "bicycle")
        let closeWords = seeds.filter { $0.english.hasPrefix("close") }.map(\.english)
        XCTAssertEqual(closeWords, ["close (shut)", "close (near)", "closed", "closely", "closet"])
    }

    func testLetterFiltersCombineWithLearningStatusAndKeepEnglishOrder() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let bWords = store.reviewWords(in: .all, startingWith: "B")
        XCTAssertEqual(bWords.first?.english, "baby")
        XCTAssertFalse(bWords.isEmpty)
        XCTAssertTrue(bWords.allSatisfy { $0.english.lowercased().hasPrefix("b") })
        try store.rate(bWords[0], as: .known)
        try store.rate(bWords[1], as: .learning)
        XCTAssertEqual(store.reviewWords(in: .learning, startingWith: "B").map(\.id), [bWords[1].id])
        XCTAssertEqual(store.reviewWords(in: .known, startingWith: "B").map(\.id), [bWords[0].id])
        XCTAssertFalse(store.reviewWords(in: .remaining, startingWith: "B").contains { $0.id == bWords[0].id })
        XCTAssertTrue(store.reviewWords(in: .all, startingWith: "X").isEmpty)
        XCTAssertEqual(store.letterCounts().values.reduce(0, +), 3000)
        XCTAssertEqual(store.letterCounts()["B"], bWords.count)
        XCTAssertEqual(store.reviewWords(in: .all).count, 3000)
    }

    func testUndoDoesNotOverwriteANewerReview() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let word = store.words[0]
        let first = try store.rate(word, as: .known)
        try store.rate(word, as: .learning, at: Date().addingTimeInterval(1))
        XCTAssertThrowsError(try store.undo(first))
        XCTAssertEqual(word.status, .learning)
        XCTAssertEqual(word.reviewCount, 2)
        XCTAssertEqual(store.events.count, 2)
    }
    func testImportedArtworkKeepsVersionsPromptsAndProgressAcrossRelaunch() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let seeds = try StudyStore.readSeeds().filter { $0.id == "sv-0003" }
        let url = folder.appending(path: "words.store")
        let art = folder.appending(path: "Artwork")
        let store = try StudyStore(container: StudyStore.makeContainer(url: url), seeds: seeds, artworkDirectory: art)
        let word = try XCTUnwrap(store.words.first)
        try store.rate(word, as: .known)
        let fixture = try testArtworkFixtureURL()
        let data = try Data(contentsOf: fixture)
        try store.saveArtworkPrompt(for: word.id, text: "Two keys unlock skills.", memoryHook: "KEY + KEY")
        try store.saveArtworkPrompt(for: word.id, text: "Two keys unlock skills.", memoryHook: "KEY + KEY")
        XCTAssertEqual(store.promptHistory(for: word.id).count, 1)
        let first = try await store.importArtwork(data, for: word, prompt: "Two keys unlock skills.", memoryHook: "KEY + KEY", source: "Test")
        XCTAssertLessThanOrEqual(first.width, 768)
        XCTAssertLessThanOrEqual(first.height, 768)
        XCTAssertLessThan(first.byteCount, 200_000)
        let thumb = try XCTUnwrap(store.artworkImage(first, thumbnail: true))
        XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), 160)
        let second = try await store.importArtwork(data, for: word, prompt: "A new pair of keys.", memoryHook: "Two keys, new version", source: "Test")
        XCTAssertNotEqual(first.filename, second.filename)
        XCTAssertFalse(first.isActive)
        XCTAssertEqual(store.activeArtwork(for: word.id)?.id, second.id)
        XCTAssertEqual(store.artworkHistory(for: word.id).count, 2)
        XCTAssertEqual(store.promptHistory(for: word.id).count, 2)
        try store.activateArtwork(first)
        XCTAssertEqual(store.activeArtwork(for: word.id)?.id, first.id)
        let export = try store.exportArtwork(for: word)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: export)) as? [String: Any])
        XCTAssertEqual(payload["wordID"] as? String, word.id)
        XCTAssertEqual((payload["images"] as? [[String: Any]])?.count, 2)
        let reopened = try StudyStore(container: StudyStore.makeContainer(url: url), seeds: seeds, artworkDirectory: art)
        XCTAssertEqual(reopened.activeArtwork(for: word.id)?.id, first.id)
        XCTAssertEqual(reopened.promptHistory(for: word.id).count, 2)
        XCTAssertNotNil(reopened.artworkImage(for: reopened.words[0]))
        XCTAssertEqual(reopened.words[0].status, .known)
        XCTAssertEqual(reopened.events.count, 1)
        try reopened.useOriginalArtwork(for: word.id)
        XCTAssertNil(reopened.activeArtwork(for: word.id))
        XCTAssertEqual(reopened.artworkHistory(for: word.id).count, 2)
    }

    func testInvalidImageDoesNotChangeProgressOrCreateArtwork() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true),
            seeds: Array(try StudyStore.readSeeds().prefix(1)), artworkDirectory: folder)
        let word = store.words[0]
        try store.rate(word, as: .learning)
        do {
            try await store.importArtwork(Data("not an image".utf8), for: word, prompt: "Example", memoryHook: "", source: "Test")
            XCTFail("An invalid image should be rejected")
        } catch is ArtworkError { }
        XCTAssertTrue(store.artworks.isEmpty)
        XCTAssertTrue(store.promptHistory(for: word.id).isEmpty)
        XCTAssertEqual(word.status, .learning)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testArtworkTablesMigrateAnExistingVocabularyDatabase() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "old.store")
        let seed = try XCTUnwrap(StudyStore.readSeeds().first { $0.id == "sv-0002" })
        try autoreleasepool {
            let schema = Schema([VocabularyWord.self, ReviewEvent.self])
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let old = try ModelContainer(for: schema, configurations: [config])
            let word = VocabularyWord(seed: seed)
            word.status = .learning; word.reviewCount = 1
            old.mainContext.insert(word)
            old.mainContext.insert(ReviewEvent(wordID: word.id, outcome: .learning))
            try old.mainContext.save()
        }
        let upgraded = try StudyStore(container: StudyStore.makeContainer(url: url), seeds: [seed], artworkDirectory: folder.appending(path: "Artwork"))
        XCTAssertEqual(upgraded.words[0].status, .learning)
        XCTAssertEqual(upgraded.words[0].reviewCount, 1)
        XCTAssertEqual(upgraded.events.count, 1)
        XCTAssertTrue(upgraded.artworks.isEmpty)
        try upgraded.saveArtworkPrompt(for: seed.id, text: "After migration", memoryHook: "")
        XCTAssertEqual(upgraded.promptHistory(for: seed.id).count, 1)
    }

    func testEveryWordCanCreateAnArtworkPrompt() throws {
        let seeds = try StudyStore.readSeeds()
        for seed in seeds {
            let word = VocabularyWord(seed: seed)
            let prompt = ArtworkPromptBuilder.make(for: word)
            XCTAssertTrue(prompt.contains("Swedish"))
            XCTAssertTrue(prompt.contains(word.swedish))
            XCTAssertTrue(prompt.contains(word.sentence))
            XCTAssertTrue(prompt.contains(word.id))
        }
    }

    func testAll3000HostedImagesAreAddressableWithoutImporting() throws {
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: StudyStore.readSeeds())
        let words = store.reviewWords(in: .all)
        let mediaURL = try XCTUnwrap(Bundle.main.url(forResource: "lesson-media", withExtension: "json"))
        let media = try JSONDecoder().decode(LessonMediaManifest.self, from: Data(contentsOf: mediaURL)).validated()
        let expectedCounts: [String: Int] = ["A": 211, "B": 152, "C": 292, "D": 163, "E": 162, "F": 155, "G": 73, "H": 100, "I": 121, "J": 23, "K": 18, "L": 108, "M": 134, "N": 65, "O": 82, "P": 238, "Q": 16, "R": 163, "S": 351, "T": 166, "U": 50, "V": 36, "W": 106, "X": 0, "Y": 13, "Z": 2]
        for (letter, count) in expectedCounts {
            XCTAssertEqual(store.reviewWords(in: .all, startingWith: letter).count, count, letter)
        }
        XCTAssertEqual(words.count, 3000)
        XCTAssertEqual(Set(BundledArtwork.records.keys), Set(words.map(\.id)))
        XCTAssertTrue(store.artworks.isEmpty)
        for word in words {
            try autoreleasepool {
                XCTAssertTrue(store.hasArtwork(for: word), word.id)
                XCTAssertTrue(store.artworkContainsText(for: word), word.id)
                let full = try XCTUnwrap(BundledArtwork.mediaKey(for: word.id), word.id)
                let thumb = try XCTUnwrap(BundledArtwork.mediaKey(for: word.id, thumbnail: true), word.id)
                XCTAssertNotNil(media.itemByKey[full], word.id)
                XCTAssertNotNil(media.itemByKey[thumb], word.id)
                XCTAssertFalse(store.artworkMemoryHook(for: word).isEmpty, word.id)
            }
        }
        XCTAssertEqual(BundledArtwork.records["sv-0199"]?.assetID, "sv-0199-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0003"]?.assetID, "sv-0003-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0215"]?.assetID, "sv-0215-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0239"]?.assetID, "sv-0239-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0245"]?.assetID, "sv-0245-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0389"]?.assetID, "sv-0389-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0393"]?.assetID, "sv-0393-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0574"]?.assetID, "sv-0574-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0612"]?.assetID, "sv-0612-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0810"]?.assetID, "sv-0810-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0860"]?.assetID, "sv-0860-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0864"]?.assetID, "sv-0864-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0978"]?.assetID, "sv-0978-r002")
        XCTAssertEqual(BundledArtwork.records["sv-0999"]?.assetID, "sv-0999-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1004"]?.assetID, "sv-1004-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1082"]?.assetID, "sv-1082-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1141"]?.assetID, "sv-1141-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1164"]?.assetID, "sv-1164-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1184"]?.assetID, "sv-1184-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1185"]?.assetID, "sv-1185-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1338"]?.assetID, "sv-1338-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1384"]?.assetID, "sv-1384-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1540"]?.assetID, "sv-1540-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1587"]?.assetID, "sv-1587-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1622"]?.assetID, "sv-1622-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1655"]?.assetID, "sv-1655-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1663"]?.assetID, "sv-1663-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1665"]?.assetID, "sv-1665-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1701"]?.assetID, "sv-1701-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1731"]?.assetID, "sv-1731-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1780"]?.assetID, "sv-1780-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1795"]?.assetID, "sv-1795-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1797"]?.assetID, "sv-1797-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1807"]?.assetID, "sv-1807-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1825"]?.assetID, "sv-1825-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1920"]?.assetID, "sv-1920-r002")
        XCTAssertEqual(BundledArtwork.records["sv-1944"]?.assetID, "sv-1944-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2004"]?.assetID, "sv-2004-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2009"]?.assetID, "sv-2009-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2073"]?.assetID, "sv-2073-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2120"]?.assetID, "sv-2120-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2139"]?.assetID, "sv-2139-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2185"]?.assetID, "sv-2185-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2243"]?.assetID, "sv-2243-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2254"]?.assetID, "sv-2254-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2295"]?.assetID, "sv-2295-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2333"]?.assetID, "sv-2333-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2370"]?.assetID, "sv-2370-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2372"]?.assetID, "sv-2372-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2373"]?.assetID, "sv-2373-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2374"]?.assetID, "sv-2374-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2375"]?.assetID, "sv-2375-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2376"]?.assetID, "sv-2376-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2377"]?.assetID, "sv-2377-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2450"]?.assetID, "sv-2450-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2464"]?.assetID, "sv-2464-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2472"]?.assetID, "sv-2472-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2503"]?.assetID, "sv-2503-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2673"]?.assetID, "sv-2673-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2740"]?.assetID, "sv-2740-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2757"]?.assetID, "sv-2757-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2858"]?.assetID, "sv-2858-r002")
        XCTAssertEqual(BundledArtwork.records["sv-2910"]?.assetID, "sv-2910-r002")
        XCTAssertEqual(store.count(.new), 3000)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testBundledArtworkUpdatePreservesPersonalImageAndLearningProgress() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let seeds = try StudyStore.readSeeds().filter { $0.id == "sv-0003" }
        let container = try StudyStore.makeContainer(inMemory: true)
        let store = try StudyStore(container: container, seeds: seeds, artworkDirectory: directory)
        let word = try XCTUnwrap(store.words.first)
        let media = LessonMedia(baseURL: URL(string: "https://example.invalid/")!, storageRoot: directory.appending(path: "Media"), automaticEnabled: false)
        let key = try XCTUnwrap(BundledArtwork.mediaKey(for: word.id))
        let bundled = try await media.data(for: key)
        try store.rate(word, as: .known)
        let fixture = try Data(contentsOf: testArtworkFixtureURL())
        let personal = try await store.importArtwork(fixture, for: word, prompt: "Personal", memoryHook: "My hook", source: "Photos")
        let updated = try StudyStore(container: container, seeds: seeds, artworkDirectory: directory)
        let updatedWord = try XCTUnwrap(updated.words.first)
        XCTAssertEqual(updated.activeArtwork(for: word.id)?.id, personal.id)
        XCTAssertEqual(updated.artworkMemoryHook(for: updatedWord), "My hook")
        XCTAssertEqual(updatedWord.status, .known)
        XCTAssertEqual(updated.events.count, 1)
        try updated.useOriginalArtwork(for: word.id)
        XCTAssertNil(updated.activeArtwork(for: word.id))
        let restored = try await media.data(for: key)
        XCTAssertEqual(restored, bundled)
        XCTAssertNil(updated.activeArtwork(for: word.id))
        XCTAssertEqual(updated.artworkMemoryHook(for: updatedWord), BundledArtwork.records[word.id]?.memoryHook)
        XCTAssertEqual(updated.artworkHistory(for: word.id).count, 1)
    }

    func testArtworkPackImportsMultipleWordsAndRetriesWithoutDuplicates() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let seeds = try StudyStore.readSeeds()
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: Array(seeds.prefix(4)), artworkDirectory: directory)
        let word = try XCTUnwrap(store.words.first { $0.id == "sv-0003" })
        try store.rate(word, as: .known)
        let fixture = try Data(contentsOf: testArtworkFixtureURL())
        let records: [[String: String]] = ["sv-0002", "sv-0003"].map {
            ["assetID": $0 + "-test-r001", "wordID": $0, "prompt": "Exact prompt for " + $0,
             "memoryHook": "Visible memory link", "jpegBase64": fixture.base64EncodedString()]
        }
        let pack = try JSONSerialization.data(withJSONObject: ["format": "swedish-cards-artwork-pack-v1", "records": records])
        var counts: [Int] = []
        let result = try await store.importArtworkPack(pack) { done, _ in counts.append(done) }
        XCTAssertEqual(result.imported, 2); XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(counts, [0, 1, 2]); XCTAssertEqual(store.artworks.count, 2)
        XCTAssertEqual(word.status, .known); XCTAssertEqual(store.events.count, 1)
        let original = try XCTUnwrap(store.activeArtwork(for: word.id))
        XCTAssertEqual(original.promptText, "Exact prompt for sv-0003")
        let custom = try await store.importArtwork(fixture, for: word, prompt: "Personal revision", memoryHook: "Custom", source: "Photos")
        let retry = try await store.importArtworkPack(pack) { _, _ in }
        XCTAssertEqual(retry.imported, 0); XCTAssertEqual(retry.skipped, 2)
        XCTAssertEqual(store.artworks.count, 3)
        XCTAssertEqual(store.activeArtwork(for: word.id)?.id, custom.id)
        try store.activateArtwork(original)
        XCTAssertNotNil(store.artworkImage(for: word))
    }

    func testArtworkPackPreflightRejectsUnknownWordsBeforeWritingAnyImage() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StudyStore(container: StudyStore.makeContainer(inMemory: true), seeds: Array(StudyStore.readSeeds().prefix(3)), artworkDirectory: directory)
        let fixture = try Data(contentsOf: testArtworkFixtureURL())
        let records: [[String: String]] = ["sv-0002", "sv-9999"].map {
            ["assetID": $0 + "-test", "wordID": $0, "prompt": "Test", "memoryHook": "Test", "jpegBase64": fixture.base64EncodedString()]
        }
        let pack = try JSONSerialization.data(withJSONObject: ["format": "swedish-cards-artwork-pack-v1", "records": records])
        do {
            _ = try await store.importArtworkPack(pack) { _, _ in }
            XCTFail("Expected unknown-word error")
        } catch ArtworkPack.PackError.unknownWord { }
        XCTAssertTrue(store.artworks.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        let duplicated = try JSONSerialization.data(withJSONObject: ["format": "swedish-cards-artwork-pack-v1", "records": [records[0], records[0]]])
        XCTAssertThrowsError(try ArtworkPack.read(duplicated))
        let broken = try JSONSerialization.data(withJSONObject: ["format": "swedish-cards-artwork-pack-v1", "records": [["assetID": "bad", "wordID": "sv-0002", "prompt": "Test", "memoryHook": "Test", "jpegBase64": "not-an-image"]]])
        XCTAssertThrowsError(try ArtworkPack.read(broken))
    }

}

@MainActor
func testArtworkFixtureURL() throws -> URL {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
    }
    let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
    let url = URL.temporaryDirectory.appending(path: "Swedish-test-artwork-" + UUID().uuidString + ".jpg")
    try data.write(to: url)
    return url
}
