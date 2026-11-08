import Foundation

enum ReminderPrompt: String, Codable, CaseIterable, Identifiable {
    case swedish, english, pair
    var id: String { rawValue }
    var title: String {
        switch self {
        case .swedish: "Swedish question"
        case .english: "English question"
        case .pair: "Word and meaning"
        }
    }
    var englishFirst: Bool { self == .english }
}

enum ReminderPool: String, Codable, CaseIterable, Identifiable {
    case all, learning, remaining
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All words"
        case .learning: "Still learning"
        case .remaining: "New & learning"
        }
    }
}

struct WordReminderSettings: Codable, Equatable, Sendable {
    var enabled = false
    // Minutes from local midnight. Legacy custom times remain compatible.
    var times = [540, 780, 1020, 1260]
    var pool: ReminderPool = .all
    var letter: String?
    var prompt: ReminderPrompt = .swedish
    var sound = false
    var showArtwork = true
    var intervalMinutes: Int? = 60
    var sleepStart: Int? = 22 * 60
    var sleepEnd: Int? = 8 * 60

    func isSleeping(at minute: Int) -> Bool {
        guard let start = sleepStart, let end = sleepEnd else { return false }
        if start == end { return true }
        return start < end ? (start..<end).contains(minute) : minute >= start || minute < end
    }

    var scheduledMinutes: [Int] {
        let value = normalized
        let candidates: [Int]
        if let interval = value.intervalMinutes {
            let anchor = value.sleepEnd ?? 0
            candidates = stride(from: 0, to: 1440, by: interval).map { ($0 + anchor) % 1440 }
        } else { candidates = value.times }
        return Array(Set(candidates.filter { !value.isSleeping(at: $0) })).sorted()
    }

    var normalized: Self {
        var copy = self
        copy.times = Array(Set(times.filter { (0..<1440).contains($0) })).sorted().prefix(48).map { $0 }
        if copy.times.isEmpty { copy.times = [540] }
        if let intervalMinutes, ![30, 60, 120, 180, 240].contains(intervalMinutes) { copy.intervalMinutes = 60 }
        if let sleepStart, !(0..<1440).contains(sleepStart) { copy.sleepStart = nil }
        if let sleepEnd, !(0..<1440).contains(sleepEnd) { copy.sleepEnd = nil }
        if let letter, !EnglishAlphabet.letters.contains(letter) { copy.letter = nil }
        return copy
    }
}

struct ReminderWord: Sendable, Equatable {
    let id: String
    let english: String
    let swedish: String
    let status: String
    let thumbnail: URL?
}

struct PlannedWordReminder: Sendable, Equatable {
    let date: Date
    let word: ReminderWord
    var minuteOfDay: Int? = nil
}

enum WordReminderPlan {
    static let maximumWords = 56
    static let horizonDays = 14

    static func eligible(_ words: [ReminderWord], settings: WordReminderSettings) -> [ReminderWord] {
        let settings = settings.normalized
        return words.filter {
            (settings.letter == nil || EnglishAlphabet.initial($0.english) == settings.letter) &&
            (settings.pool == .all || (settings.pool == .learning ? $0.status == "learning" : $0.status != "known"))
        }
    }

    static func dates(settings: WordReminderSettings, now: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return [] }
        var dates: Set<Date> = []
        for day in 0...horizonDays {
            guard let date = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            for minute in settings.scheduledMinutes {
                if let next = calendar.nextDate(after: date.addingTimeInterval(-1),
                    matching: DateComponents(hour: minute / 60, minute: minute % 60),
                    matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                   calendar.isDate(next, inSameDayAs: date), next > now, next < end {
                    dates.insert(next)
                }
            }
        }
        return Array(dates.sorted().prefix(maximumWords))
    }

    static func repeating<R: RandomNumberGenerator>(words: [ReminderWord], settings: WordReminderSettings,
        now: Date, calendar: Calendar, avoiding recentIDs: [String] = [], using rng: inout R) -> [PlannedWordReminder] {
        let pool = eligible(words, settings: settings)
        guard !pool.isEmpty else { return [] }
        let slots = settings.scheduledMinutes.compactMap { minute -> (Int, Date)? in
            guard let date = calendar.nextDate(after: now, matching: DateComponents(hour: minute / 60, minute: minute % 60),
                matchingPolicy: .strict, repeatedTimePolicy: .first) else { return nil }
            return (minute, date)
        }.sorted { $0.1 < $1.1 }
        let recent = Set(recentIDs)
        var bag = pool.filter { !recent.contains($0.id) }.shuffled(using: &rng)
        var previous = recentIDs.last
        return slots.map { minute, date in
            if bag.isEmpty { bag = pool.shuffled(using: &rng) }
            if bag.last?.id == previous, bag.count > 1 { bag.swapAt(0, bag.count - 1) }
            let word = bag.removeLast(); previous = word.id
            return PlannedWordReminder(date: date, word: word, minuteOfDay: minute)
        }
    }

    // Shuffle in cycles: no repetition until the selected pool is exhausted, and
    // no identical neighbours across cycles when there is more than one word.
    static func make<R: RandomNumberGenerator>(words: [ReminderWord], settings: WordReminderSettings,
        now: Date, calendar: Calendar, avoiding recentIDs: [String] = [], using rng: inout R) -> [PlannedWordReminder] {
        let pool = eligible(words, settings: settings)
        guard !pool.isEmpty else { return [] }
        let recent = Set(recentIDs)
        var bag = pool.filter { !recent.contains($0.id) }.shuffled(using: &rng)
        var previous = recentIDs.last
        return dates(settings: settings, now: now, calendar: calendar).map { date in
            if bag.isEmpty { bag = pool.shuffled(using: &rng) }
            if bag.last?.id == previous, bag.count > 1 { bag.swapAt(0, bag.count - 1) }
            let word = bag.removeLast()
            previous = word.id
            return PlannedWordReminder(date: date, word: word)
        }
    }

    static func text(for word: ReminderWord, prompt: ReminderPrompt) -> (title: String, body: String) {
        switch prompt {
        case .swedish: ("Do you remember this word?", "\(word.swedish.uppercased())\nTap to recall its English meaning.")
        case .english: ("Can you say it in Swedish?", "\(word.english.uppercased())\nTap to recall the Swedish word.")
        case .pair: ("A little Swedish practice", "\(word.swedish.uppercased()) — \(word.english)\nTap to practise this word.")
        }
    }
}
