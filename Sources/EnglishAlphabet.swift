import SwiftUI

enum EnglishAlphabet {
    static let letters = (65...90).map { String(UnicodeScalar($0)!) }

    // English dictionary order, independent of the phone's display language.
    // Ignore spaces, hyphens and punctuation; keep homographs stable by source ID.
    static func sortKey(_ word: String) -> String {
        let headword = word.components(separatedBy: "(")[0].components(separatedBy: " / ")[0]
        return headword.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func initial(_ word: String) -> String {
        String(sortKey(word).prefix(1)).uppercased()
    }

    static func matches(_ word: String, letter: String?) -> Bool {
        letter == nil || initial(word) == letter
    }
}

struct VocabularyFilterSummary {
    let total: Int
    let letterCounts: [String: Int]
    let topics: [String]

    func count(startingWith letter: String?) -> Int {
        letter.map { letterCounts[$0, default: 0] } ?? total
    }
}

struct VocabularyFilterSheet: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let words: [VocabularyWord]
    let onApply: (ReviewScope, String?, String?) -> Void
    @State private var scope: ReviewScope
    @State private var letter: String?
    @State private var topic: String?

    init(words: [VocabularyWord], scope: ReviewScope, letter: String?, topic: String?,
         onApply: @escaping (ReviewScope, String?, String?) -> Void) {
        self.words = words; self.onApply = onApply
        _scope = State(initialValue: scope)
        _letter = State(initialValue: letter)
        _topic = State(initialValue: topic)
    }

    var body: some View {
        // One pass per selection, shared by all letter buttons and the result count.
        let summary = store.filterSummary(words: words, scope: scope, topic: topic)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Learning status")
                        ForEach(ReviewScope.allCases) { value in
                            Button { scope = value } label: {
                                HStack {
                                    Text(value.title)
                                    Spacer()
                                    Image(systemName: scope == value ? "checkmark.circle.fill" : "circle")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.accent)
                                .padding(13)
                                .background(scope == value ? Palette.accentSoft : .white, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("filter.scope.\(value.rawValue)")
                            .accessibilityAddTraits(scope == value ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Topic")
                        Button { topic = nil } label: {
                            HStack {
                                Text("All topics")
                                Spacer()
                                if topic == nil { Image(systemName: "checkmark.circle.fill") }
                            }
                            .font(.subheadline.weight(.medium)).padding(14)
                            .foregroundStyle(Palette.accent)
                            .background(topic == nil ? Palette.accentSoft : .white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityIdentifier("filter.topic.all")
                        TopicCardGrid(progress: store.topicProgress(words: words), selected: topic) { value in
                            topic = value.rawValue
                        }
                        .accessibilityIdentifier("filter.topic")
                        Text("A word can belong to several topics. Its learning progress is shared everywhere.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "English starts with")
                        Button { letter = nil } label: {
                            HStack {
                                Text("All letters")
                                Spacer()
                                Text("\(summary.total)").foregroundStyle(Palette.muted)
                                if letter == nil { Image(systemName: "checkmark") }
                            }
                            .font(.subheadline.weight(.medium)).padding(13)
                            .foregroundStyle(Palette.accent)
                            .background(letter == nil ? Palette.accentSoft : .white, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityIdentifier("letter.all")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(EnglishAlphabet.letters, id: \.self) { value in
                                Button { letter = value } label: {
                                    VStack(spacing: 3) {
                                        Text(value).font(.headline)
                                        Text("\(summary.letterCounts[value, default: 0])").font(.caption2).opacity(0.75)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 52)
                                    .foregroundStyle(letter == value ? .white : Palette.accent)
                                    .background(letter == value ? Palette.accent : .white, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityLabel("\(value), \(summary.letterCounts[value, default: 0]) words")
                                .accessibilityIdentifier("letter.\(value)")
                            }
                        }
                    }
                }
                .padding(20)
            }
            .accessibilityIdentifier("filters.content")
            .background(Palette.background)
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") { scope = .all; letter = nil; topic = nil }
                        .accessibilityIdentifier("filter.reset")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onApply(scope, letter, topic); dismiss()
                } label: { Text("Show \(summary.count(startingWith: letter)) words").frame(maxWidth: .infinity) }
                    .buttonStyle(FilledActionStyle())
                    .accessibilityIdentifier("filter.apply")
                    .padding(20).background(Palette.background)
            }
        }
    }
}
