import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class StudyStore {
    let container: ModelContainer
    let context: ModelContext
    private(set) var words: [VocabularyWord] = []
    private(set) var events: [ReviewEvent] = []
    private(set) var artworks: [ArtworkRevision] = []
    let artworkDirectory: URL
    @ObservationIgnored private var wordsByID: [String: VocabularyWord] = [:]
    @ObservationIgnored private var initialsByID: [String: String] = [:]
    @ObservationIgnored private var cachedSearch: String?
    @ObservationIgnored private var cachedSearchWords: [VocabularyWord] = []

    init(container: ModelContainer, seeds: [WordSeed], artworkDirectory: URL? = nil) throws {
        self.container = container
        self.artworkDirectory = artworkDirectory ?? URL.applicationSupportDirectory.appending(path: "Artwork", directoryHint: .isDirectory)
        context = container.mainContext
        try upsertSeeds(seeds)
        try refresh()
    }

    static func readSeeds(bundle: Bundle = .main) throws -> [WordSeed] {
        guard let starterURL = bundle.url(forResource: "starter100", withExtension: "json"),
              let catalogURL = bundle.url(forResource: "catalog3000", withExtension: "json"),
              let examplesURL = bundle.url(forResource: "examples3000", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let decoder = JSONDecoder()
        let starter = try decoder.decode([WordSeed].self, from: Data(contentsOf: starterURL))
        let catalog = try decoder.decode(VocabularyCatalog.self, from: Data(contentsOf: catalogURL))
        let examples = try decoder.decode([SentenceSeed].self, from: Data(contentsOf: examplesURL))
        let catalogIDs = Set(catalog.entries.map(\.id))
        guard (1...3_000).contains(catalog.entryCount), catalog.entries.count == catalog.entryCount,
              catalogIDs.count == catalog.entryCount,
              examples.count == catalog.entryCount,
              Set(examples.map(\.id)) == catalogIDs,
              examples.allSatisfy({ !$0.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                   !$0.sentenceEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(starter.map(\.id)).count == starter.count,
              starter.allSatisfy({ catalogIDs.contains($0.id) }),
              catalog.entries.allSatisfy({ !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                          !$0.swedish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Preserve edited senses and artwork while sorting the entire collection
        // by English. Stable source IDs retain progress when display order changes.
        var seeds = starter.sorted { $0.order < $1.order }
        let starterIDs = Set(starter.map(\.id))
        for entry in catalog.entries where !starterIDs.contains(entry.id) {
            seeds.append(WordSeed(id: entry.id, sourceID: entry.sourceID, order: seeds.count,
                                  english: entry.english, swedish: entry.swedish,
                                  sentence: "", sentenceEnglish: "", topic: "Vocabulary",
                                  symbol: "text.book.closed", imageName: nil, imageContainsText: false))
        }
        let examplesByID = Dictionary(uniqueKeysWithValues: examples.map { ($0.id, $0) })
        let keys: [String: String] = Dictionary(uniqueKeysWithValues: seeds.map {
            ($0.id, EnglishAlphabet.sortKey($0.english))
        })
        let sorted: [WordSeed] = seeds.sorted { left, right in
            let leftKey = keys[left.id]!
            let rightKey = keys[right.id]!
            if leftKey != rightKey { return leftKey < rightKey }
            return left.sourceID < right.sourceID
        }
        return sorted.enumerated().map { order, seed in
            let example = examplesByID[seed.id]!
            let sameSentence = example.sentence == seed.sentence
            // Artwork with embedded text must stay in sync with the current example.
            let imageName = seed.imageContainsText && !sameSentence ? nil : seed.imageName
            return WordSeed(id: seed.id, sourceID: seed.sourceID, order: order,
                            english: seed.english, swedish: seed.swedish,
                            sentence: example.sentence,
                            sentenceEnglish: example.sentenceEnglish,
                            topic: seed.topic, symbol: seed.symbol,
                            imageName: imageName, imageContainsText: imageName != nil && seed.imageContainsText)
        }
    }

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([VocabularyWord.self, ReviewEvent.self, ArtworkPrompt.self, ArtworkRevision.self])
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func upsertSeeds(_ seeds: [WordSeed]) throws {
        let existing = try context.fetch(FetchDescriptor<VocabularyWord>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for seed in seeds {
            if let word = byID[seed.id] {
                // Content updates must not erase the learner's progress.
                word.sourceID = seed.sourceID
                word.order = seed.order
                word.english = seed.english
                word.swedish = seed.swedish
                word.sentence = seed.sentence
                word.sentenceEnglish = seed.sentenceEnglish
                word.topic = seed.topic
                word.symbol = seed.symbol
                word.imageName = seed.imageName
                word.imageContainsText = seed.imageContainsText
            } else {
                context.insert(VocabularyWord(seed: seed))
            }
        }
        try context.save()
    }

    private func refresh() throws {
        words = try context.fetch(FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\.order)]))
        wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        initialsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, EnglishAlphabet.initial($0.english)) })
        cachedSearch = nil
        cachedSearchWords = []
        events = try context.fetch(FetchDescriptor<ReviewEvent>(sortBy: [SortDescriptor(\.date)]))
        artworks = try context.fetch(FetchDescriptor<ArtworkRevision>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func word(withID id: String) -> VocabularyWord? { wordsByID[id] }

    func initial(for word: VocabularyWord) -> String {
        initialsByID[word.id] ?? EnglishAlphabet.initial(word.english)
    }

    // Vocabulary text is fixed for this store's lifetime; ratings remain live model values.
    func searchWords(_ query: String) -> [VocabularyWord] {
        if query.isEmpty { return words }
        if cachedSearch == query { return cachedSearchWords }
        let matches = words.filter {
            $0.english.localizedStandardContains(query) || $0.swedish.localizedStandardContains(query) ||
            $0.sentence.localizedStandardContains(query)
        }
        cachedSearch = query
        cachedSearchWords = matches
        return matches
    }

    func filterSummary(words candidates: [VocabularyWord], scope: ReviewScope, topic: String?) -> VocabularyFilterSummary {
        var counts: [String: Int] = [:]
        var topics: Set<String> = []
        var total = 0
        for word in candidates {
            topics.insert(word.topic)
            if scope.includes(word) && (topic == nil || word.topic == topic) {
                counts[initial(for: word), default: 0] += 1
                total += 1
            }
        }
        return VocabularyFilterSummary(total: total, letterCounts: counts, topics: topics.sorted())
    }

    func activeArtwork(for wordID: String) -> ArtworkRevision? {
        artworks.first { $0.wordID == wordID && $0.isActive }
    }

    func artworkHistory(for wordID: String) -> [ArtworkRevision] {
        artworks.filter { $0.wordID == wordID }
    }

    func promptHistory(for wordID: String) -> [ArtworkPrompt] {
        let descriptor = FetchDescriptor<ArtworkPrompt>(predicate: #Predicate { $0.wordID == wordID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func hasArtwork(for word: VocabularyWord) -> Bool {
        if let revision = activeArtwork(for: word.id),
           FileManager.default.fileExists(atPath: artworkDirectory.appending(path: revision.filename).path) { return true }
        return BundledArtwork.records[word.id] != nil || word.imageName != nil
    }

    func artworkContainsText(for word: VocabularyWord) -> Bool {
        activeArtwork(for: word.id) != nil || BundledArtwork.records[word.id] != nil || word.imageContainsText
    }

    func artworkMemoryHook(for word: VocabularyWord) -> String {
        activeArtwork(for: word.id)?.memoryHook ?? BundledArtwork.records[word.id]?.memoryHook ?? ""
    }

    func artworkImage(_ revision: ArtworkRevision, thumbnail: Bool = false) -> UIImage? {
        let filename = thumbnail ? revision.thumbnailFilename : revision.filename
        return ArtworkFiles.image(at: artworkDirectory.appending(path: filename))
    }

    func artworkSources(for word: VocabularyWord, thumbnail: Bool = false) -> [ArtworkImageSource] {
        var sources: [ArtworkImageSource] = []
        if let revision = activeArtwork(for: word.id) {
            sources.append(.file(artworkDirectory.appending(path: thumbnail ? revision.thumbnailFilename : revision.filename)))
        }
        if let url = BundledArtwork.url(for: word.id, thumbnail: thumbnail) { sources.append(.file(url)) }
        if let name = word.imageName { sources.append(.asset(name)) }
        return sources
    }

    func artworkImage(for word: VocabularyWord, thumbnail: Bool = false) -> UIImage? {
        if let revision = activeArtwork(for: word.id), let image = artworkImage(revision, thumbnail: thumbnail) { return image }
        if let image = BundledArtwork.image(for: word.id, thumbnail: thumbnail) { return image }
        return word.imageName.flatMap { UIImage(named: $0) }
    }

    func saveArtworkPrompt(for wordID: String, text: String, memoryHook: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let last = promptHistory(for: wordID).first, last.text == text && last.memoryHook == memoryHook { return }
        context.insert(ArtworkPrompt(wordID: wordID, text: text, memoryHook: memoryHook))
        do { try context.save() } catch { context.rollback(); throw error }
    }

    @discardableResult
    func importArtwork(_ data: Data, for word: VocabularyWord, prompt: String, memoryHook: String, source: String) async throws -> ArtworkRevision {
        let prepared = try await Task.detached(priority: .userInitiated) { try ArtworkFiles.prepare(data) }.value
        let id = UUID()
        let folder = artworkDirectory.appending(path: word.id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let full = folder.appending(path: id.uuidString + ".jpg")
        let thumb = folder.appending(path: id.uuidString + "-thumb.jpg")
        do {
            try prepared.full.write(to: full, options: .atomic)
            try prepared.thumbnail.write(to: thumb, options: .atomic)
            let revision = ArtworkRevision(id: id, wordID: word.id, promptText: prompt, memoryHook: memoryHook,
                filename: word.id + "/" + full.lastPathComponent,
                thumbnailFilename: word.id + "/" + thumb.lastPathComponent,
                byteCount: prepared.full.count + prepared.thumbnail.count,
                width: prepared.width, height: prepared.height, source: source)
            for previous in artworkHistory(for: word.id) { previous.isActive = false }
            context.insert(revision)
            if !prompt.isEmpty {
                let last = promptHistory(for: word.id).first
                if last?.text != prompt || last?.memoryHook != memoryHook {
                    context.insert(ArtworkPrompt(wordID: word.id, text: prompt, memoryHook: memoryHook))
                }
            }
            try context.save()
            artworks.insert(revision, at: 0)
            return revision
        } catch {
            context.rollback()
            try? FileManager.default.removeItem(at: full)
            try? FileManager.default.removeItem(at: thumb)
            throw error
        }
    }

    func activateArtwork(_ revision: ArtworkRevision) throws {
        guard FileManager.default.fileExists(atPath: artworkDirectory.appending(path: revision.filename).path) else {
            throw ArtworkError.invalidImage
        }
        for item in artworkHistory(for: revision.wordID) { item.isActive = item.id == revision.id }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func useOriginalArtwork(for wordID: String) throws {
        for item in artworkHistory(for: wordID) { item.isActive = false }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func exportArtwork(for word: VocabularyWord) throws -> URL {
        let images: [[String: Any]] = try artworkHistory(for: word.id).map { item in
            let data = try Data(contentsOf: artworkDirectory.appending(path: item.filename))
            return ["id": item.id.uuidString, "createdAt": item.createdAt.ISO8601Format(),
                    "prompt": item.promptText, "memoryHook": item.memoryHook,
                    "source": item.source, "isActive": item.isActive,
                    "width": item.width, "height": item.height, "jpegBase64": data.base64EncodedString()]
        }
        let prompts: [[String: Any]] = promptHistory(for: word.id).map {
            ["id": $0.id.uuidString, "text": $0.text, "memoryHook": $0.memoryHook, "createdAt": $0.createdAt.ISO8601Format()]
        }
        let archive: [String: Any] = ["format": "swedish-cards-artwork-v1", "wordID": word.id,
            "english": word.english, "swedish": word.swedish, "sentence": word.sentence,
            "prompts": prompts, "images": images]
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: word.id + "-artwork.json")
        try JSONSerialization.data(withJSONObject: archive, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        return url
    }

    func importArtworkPack(_ data: Data, onProgress: (Int, Int) -> Void) async throws -> (imported: Int, skipped: Int) {
        let pack = try await Task.detached(priority: .userInitiated) { try ArtworkPack.read(data) }.value
        let byID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        guard pack.records.allSatisfy({ byID[$0.wordID] != nil }) else { throw ArtworkPack.PackError.unknownWord }
        var imported = 0, skipped = 0
        onProgress(0, pack.records.count)
        for (index, record) in pack.records.enumerated() {
            let source = "Artwork pack · " + record.assetID
            if artworkHistory(for: record.wordID).contains(where: { $0.source == source }) {
                skipped += 1
            } else if let word = byID[record.wordID], let image = Data(base64Encoded: record.jpegBase64) {
                try await importArtwork(image, for: word, prompt: record.prompt, memoryHook: record.memoryHook, source: source)
                imported += 1
            }
            onProgress(index + 1, pack.records.count)
            await Task.yield()
        }
        return (imported, skipped)
    }

    func count(_ status: LearningStatus) -> Int { words.filter { $0.status == status }.count }
    var todayCount: Int { events.filter { Calendar.current.isDateInToday($0.date) }.count }
    var knownFraction: Double { words.isEmpty ? 0 : Double(count(.known)) / Double(words.count) }

    func reviewWords(in scope: ReviewScope, startingWith letter: String? = nil) -> [VocabularyWord] {
        words.filter { scope.includes($0) && (letter == nil || initial(for: $0) == letter) }
    }

    func letterCounts(in scope: ReviewScope = .all) -> [String: Int] {
        Dictionary(grouping: words.filter(scope.includes), by: { EnglishAlphabet.initial($0.english) })
            .mapValues(\.count)
    }

    @discardableResult
    func rate(_ word: VocabularyWord, as status: LearningStatus, at date: Date = .now) throws -> ReviewSnapshot {
        let event = ReviewEvent(wordID: word.id, outcome: status, date: date)
        let snapshot = ReviewSnapshot(wordID: word.id, previousStatus: word.status,
                                      previousCount: word.reviewCount, previousDate: word.lastReviewed, event: event)
        word.status = status
        word.reviewCount += 1
        word.lastReviewed = date
        context.insert(event)
        do {
            try context.save()
            events.append(event)
            return snapshot
        } catch {
            context.rollback()
            throw error
        }
    }

    func undo(_ snapshot: ReviewSnapshot) throws {
        guard let word = word(withID: snapshot.wordID) else { return }
        guard word.reviewCount == snapshot.previousCount + 1,
              word.lastReviewed == snapshot.event.date else {
            throw ReviewError.changedSinceSwipe
        }
        word.status = snapshot.previousStatus
        word.reviewCount = snapshot.previousCount
        word.lastReviewed = snapshot.previousDate
        context.delete(snapshot.event)
        do {
            try context.save()
            events.removeAll { $0.id == snapshot.event.id }
        } catch {
            context.rollback()
            throw error
        }
    }

    func reviews(on date: Date) -> Int {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count
    }
}

enum ReviewError: LocalizedError {
    case changedSinceSwipe
    var errorDescription: String? {
        "This word has been reviewed again since that swipe. Its newer progress has been kept."
    }
}
