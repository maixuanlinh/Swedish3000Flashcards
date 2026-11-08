import SwiftUI

struct WordLibraryView: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    @Environment(AppNavigation.self) private var navigation
    @State private var showingPremium = false
    @State private var search = ""
    @State private var selectedWord: VocabularyWord?
    @State private var importingArtworkPack = false
    @State private var showingFilters = false
    @State private var browsingTopics = true
    @State private var browsingCoreWords = false

    private var filterTitle: String {
        [navigation.scope.title, navigation.startingLetter, navigation.topic].compactMap { $0 }.joined(separator: " · ")
    }

    private var selectedTopic: VocabularyTopic? {
        navigation.topic.flatMap(VocabularyTopic.init(rawValue:))
    }

    private var showsTopics: Bool {
        browsingTopics && search.isEmpty && navigation.topic == nil
    }

    var body: some View {
        let searched = store.searchWords(search)
        let filtered = searched.filter {
            navigation.scope.includes($0) && $0.matchesTopic(navigation.topic) &&
            (navigation.startingLetter == nil || store.initial(for: $0) == navigation.startingLetter)
        }
        let progress = store.topicProgress(words: store.words)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let topic = selectedTopic {
                        topicHeader(topic, progress: progress[topic, default: TopicProgress()])
                    }
                    searchField
                    if showsTopics {
                        overallProgress
                        Picker("Browse vocabulary", selection: $browsingCoreWords) {
                            Text("Everyday topics").tag(false)
                            Text("Word groups").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("words.collections")
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(browsingCoreWords ? "Everyday word groups" : "Explore by topic")
                                    .font(.system(size: 23, weight: .semibold, design: .serif))
                                    .foregroundStyle(Palette.ink)
                                Text(browsingCoreWords ? "7 focused collections · up to 300 words each" : "9 themes for everyday situations")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 4)
                        }
                        HStack {
                            Button {
                                browsingTopics = false
                                navigation.applyFilters(scope: .all, letter: nil, topic: nil)
                            } label: {
                                Label("All vocabulary", systemImage: "text.book.closed")
                                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("words.allVocabulary")
                            Spacer()
                            filterButton
                        }
                        TopicCardGrid(topics: browsingCoreWords ? VocabularyTopic.coreCollections : VocabularyTopic.themes, progress: progress, selected: nil) { topic in
                            search = ""
                            browsingTopics = false
                            navigation.applyFilters(scope: .all, letter: nil, topic: topic.rawValue)
                        }
                        Text("Words can appear in several topics. Your overall progress counts each word once.")
                            .font(.caption).foregroundStyle(Palette.muted).padding(.bottom, 8)
                    } else {
                        HStack {
                            filterButton
                            Spacer(minLength: 8)
                            Text("\(filtered.count) shown").font(.caption).foregroundStyle(Palette.muted)
                                .accessibilityIdentifier("words.filteredCount")
                        }
                        if filtered.isEmpty {
                            ContentUnavailableView {
                                Label("No matching words", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try another word or change your filters.")
                            } actions: {
                                Button("Clear filters") {
                                    search = ""
                                    navigation.applyFilters(scope: .all, letter: nil, topic: nil)
                                }
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { word in
                                    Button { selectedWord = word } label: { wordRow(word) }
                                        .buttonStyle(.plain).accessibilityIdentifier("word.\(word.id)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 16)
            }
            .accessibilityIdentifier("words.content")
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if !showsTopics && !filtered.isEmpty {
                    Button {
                        navigation.review(navigation.scope, ids: filtered.map(\.id))
                    } label: {
                        Label(filtered.count == 1 ? "Practise this word" : "Practise these \(filtered.count) words", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .buttonStyle(FilledActionStyle()).accessibilityIdentifier("words.practice")
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Palette.background.opacity(0.97))
                }
            }
            .onChange(of: navigation.request) { _, _ in
                if navigation.tab == 0 { selectedWord = nil; importingArtworkPack = false; showingFilters = false }
            }
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .onChange(of: premium.isPremium) { _, owns in if !owns { importingArtworkPack = false } }
            .sheet(item: $selectedWord) { WordDetailView(word: $0) }
            .sheet(isPresented: $importingArtworkPack) { ArtworkPackImporter() }
            .sheet(isPresented: $showingFilters) {
                VocabularyFilterSheet(words: searched, scope: navigation.scope,
                                      letter: navigation.startingLetter, topic: navigation.topic) { scope, letter, topic in
                    browsingTopics = false
                    navigation.applyFilters(scope: scope, letter: letter, topic: topic)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if !showsTopics {
                Button {
                    search = ""
                    browsingTopics = true
                    navigation.applyFilters(scope: .all, letter: nil, topic: nil)
                } label: {
                    Label("Topics", systemImage: "chevron.left").font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("words.backToTopics")
            } else {
                Text("Words").font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
            }
            Spacer()
            Text("\(store.words.count) words").font(.subheadline).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("words.total")
            Menu {
                Button("Import artwork pack", systemImage: premium.isPremium ? "folder.badge.plus" : "lock.fill") {
                    if premium.isPremium { importingArtworkPack = true } else { showingPremium = true }
                }
                .accessibilityIdentifier("words.importArtwork")
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Palette.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Word collection options").accessibilityIdentifier("words.options")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
            TextField("Search English or Swedish", text: $search)
                .font(.subheadline).autocorrectionDisabled().accessibilityIdentifier("words.search")
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 32, minHeight: 32) }
                    .foregroundStyle(Palette.muted).accessibilityLabel("Clear search")
            }
        }
        .padding(13).background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private var filterButton: some View {
        Button { showingFilters = true } label: {
            Label(showsTopics ? "Filters" : filterTitle, systemImage: "line.3.horizontal.decrease")
                .font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                .frame(minHeight: 44)
        }
        .foregroundStyle(Palette.accent).accessibilityIdentifier("words.filters")
    }

    private var overallProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your vocabulary").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.count(.known)) / \(store.words.count) known").font(.caption)
                    .accessibilityIdentifier("topics.overallProgress")
            }
            ProgressView(value: store.knownFraction).tint(Palette.accent)
            Text("Choose a topic for your next practice.").font(.caption).foregroundStyle(Palette.muted)
        }
        .foregroundStyle(Palette.ink).padding(16)
        .background(Palette.accentSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
    }

    private func topicHeader(_ topic: VocabularyTopic, progress: TopicProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                TopicIcon(topic: topic, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.swedish).font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    Text(topic.rawValue).font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
            Text(topic.detail).font(.subheadline).foregroundStyle(Palette.muted)
            HStack {
                Text("\(progress.known) / \(progress.total) known")
                Spacer()
                Text("\(progress.learning) learning")
            }
            .font(.caption).foregroundStyle(Palette.muted)
            ProgressView(value: progress.fraction).tint(Palette.accent)
            Text("Progress is shared across topics.").font(.caption).foregroundStyle(Palette.muted)
        }
        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityIdentifier("words.topicHeader")
    }

    private func wordRow(_ word: VocabularyWord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Palette.background)
                if !premium.hasLesson(word) {
                    Image(systemName: "lock.fill").foregroundStyle(Palette.accent)
                        .accessibilityLabel("Illustrated lesson requires Premium")
                } else if store.hasArtwork(for: word), store.activeArtwork(for: word.id) != nil || !word.imageContainsText {
                    WordArtworkImage(word: word, thumbnail: true).padding(4)
                } else {
                    Image(systemName: word.symbol).font(.system(size: 23)).foregroundStyle(Palette.accent)
                }
            }
            .frame(width: 51, height: 55).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(word.swedish).font(.system(size: 20, weight: .medium, design: .serif)).foregroundStyle(Palette.ink)
                Text(word.english).font(.subheadline).foregroundStyle(Palette.muted)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        StatusBadge(status: word.status)
                        if let other = VocabularyTopic.allCases.first(where: { word.studyTopics.contains($0) && $0 != selectedTopic }) {
                            Text(other.rawValue).font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    StatusBadge(status: word.status)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                .padding(.top, 8)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct TopicIcon: View {
    let topic: VocabularyTopic
    var size: CGFloat = 44

    private var tint: Color {
        switch topic {
        case .background, .travel, .society: Palette.peach
        case .shopping, .work: Color(red: 0.98, green: 0.93, blue: 0.78)
        case .culture, .health: Color(red: 0.87, green: 0.93, blue: 0.96)
        default: Palette.accentSoft
        }
    }

    var body: some View {
        Image(systemName: topic.symbol)
            .font(.system(size: size * 0.48, weight: .regular))
            .foregroundStyle(Palette.accent).frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct TopicCardGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var topics: [VocabularyTopic] = VocabularyTopic.allCases
    let progress: [VocabularyTopic: TopicProgress]
    let selected: String?
    let onSelect: (VocabularyTopic) -> Void

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 155), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(topics) { topic in
                let stats = progress[topic, default: TopicProgress()]
                let isSelected = selected == topic.rawValue
                Button { onSelect(topic) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TopicIcon(topic: topic)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent)
                            } else {
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        Text(topic.swedish)
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        Text(topic.rawValue).font(.caption).foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        ProgressView(value: stats.fraction).tint(Palette.accent)
                        Text("\(stats.known) / \(stats.total) known")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    .padding(15).frame(maxWidth: .infinity, minHeight: 194, alignment: .topLeading)
                    .background(isSelected ? Palette.accentSoft.opacity(0.4) : .white, in: RoundedRectangle(cornerRadius: 21))
                    .overlay {
                        RoundedRectangle(cornerRadius: 21)
                            .strokeBorder(isSelected ? Palette.accent : Palette.line.opacity(0.6), lineWidth: isSelected ? 2 : 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 21))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("topic.\(String(describing: topic))")
                .accessibilityLabel("\(topic.swedish), \(topic.rawValue), \(stats.known) of \(stats.total) known")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
