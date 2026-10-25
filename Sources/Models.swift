import Foundation
import SwiftData

enum LearningStatus: String, CaseIterable, Identifiable {
    case new, learning, known
    var id: String { rawValue }
    var title: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .known: "Known"
        }
    }
}

struct WordSeed: Codable {
    let id: String
    let sourceID: Int
    let order: Int
    let english: String
    let swedish: String
    let sentence: String
    let sentenceEnglish: String
    let topic: String
    let symbol: String
    let imageName: String?
    let imageContainsText: Bool
}

struct VocabularyCatalog: Decodable {
    let entryCount: Int
    let entries: [Entry]

    struct Entry: Decodable {
        let id: String
        let sourceID: Int
        let english: String
        let swedish: String
    }
}

struct SentenceSeed: Decodable {
    let id: String
    let sentence: String
    let sentenceEnglish: String
}

@Model
final class VocabularyWord {
    @Attribute(.unique) var id: String
    var sourceID: Int
    var order: Int
    var english: String
    var swedish: String
    var sentence: String
    var sentenceEnglish: String
    var topic: String
    var symbol: String
    var imageName: String?
    var imageContainsText: Bool
    var statusRaw: String
    var reviewCount: Int
    var lastReviewed: Date?

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    init(seed: WordSeed) {
        id = seed.id
        sourceID = seed.sourceID
        order = seed.order
        english = seed.english
        swedish = seed.swedish
        sentence = seed.sentence
        sentenceEnglish = seed.sentenceEnglish
        topic = seed.topic
        symbol = seed.symbol
        imageName = seed.imageName
        imageContainsText = seed.imageContainsText
        statusRaw = LearningStatus.new.rawValue
        reviewCount = 0
    }
}

@Model
final class ReviewEvent {
    @Attribute(.unique) var id: UUID
    var wordID: String
    var outcome: String
    var date: Date

    init(wordID: String, outcome: LearningStatus, date: Date = .now) {
        id = UUID()
        self.wordID = wordID
        self.outcome = outcome.rawValue
        self.date = date
    }
}

struct ReviewSnapshot {
    let wordID: String
    let previousStatus: LearningStatus
    let previousCount: Int
    let previousDate: Date?
    let event: ReviewEvent
}

enum ReviewScope: String, CaseIterable, Identifiable {
    case remaining, new, learning, known, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .remaining: "New & learning"
        case .new: "New words"
        case .learning: "Still learning"
        case .known: "Known words"
        case .all: "All words"
        }
    }
    func includes(_ word: VocabularyWord) -> Bool {
        switch self {
        case .remaining: word.status != .known
        case .new: word.status == .new
        case .learning: word.status == .learning
        case .known: word.status == .known
        case .all: true
        }
    }
}
