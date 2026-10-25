import SwiftUI

struct WordLibraryView: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    @State private var showingPremium = false
    @Environment(AppNavigation.self) private var navigation
    @State private var search = ""
    @State private var selectedWord: VocabularyWord?
    @State private var importingArtworkPack = false
    @State private var showingFilters = false

    private var filterTitle: String {
        [navigation.scope.title, navigation.startingLetter, navigation.topic].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        let searched = store.searchWords(search)
        let filtered = searched.filter { navigation.scope.includes($0) &&
            (navigation.topic == nil || $0.topic == navigation.topic) &&
            (navigation.startingLetter == nil || store.initial(for: $0) == navigation.startingLetter) }
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Words").font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(store.words.count) words").font(.subheadline).foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("words.total")
                        Menu {
                            Button("Import artwork pack", systemImage: premium.isPremium ? "folder.badge.plus" : "lock.fill") {
                                if premium.isPremium { importingArtworkPack = true } else { showingPremium = true }
                            }
                                .accessibilityIdentifier("words.importArtwork")
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Palette.forest)
                        }
                        .accessibilityLabel("Word collection options").accessibilityIdentifier("words.options")
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("Search English or Swedish", text: $search)
                            .font(.subheadline).autocorrectionDisabled().accessibilityIdentifier("words.search")
                        if !search.isEmpty {
                            Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .foregroundStyle(Palette.muted).accessibilityLabel("Clear search")
                        }
                    }
                    .padding(13).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    HStack {
                        Button { showingFilters = true } label: {
                            Label(filterTitle, systemImage: "line.3.horizontal.decrease")
                                .font(.subheadline.weight(.medium)).lineLimit(1)
                                .frame(minHeight: 44)
                        }
                        .foregroundStyle(Palette.forest).accessibilityIdentifier("words.filters")
                        Spacer()
                        Text("\(filtered.count) shown").font(.caption).foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("words.filteredCount")
                    }
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
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
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(filtered) { word in
                                Button { selectedWord = word } label: { wordRow(word) }
                                    .buttonStyle(.plain).accessibilityIdentifier("word.\(word.id)")
                            }
                        }
                        .padding(.horizontal, 18).padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if !filtered.isEmpty {
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
                                      letter: navigation.startingLetter, topic: navigation.topic,
                                      onApply: navigation.applyFilters)
            }
        }
    }

    private func wordRow(_ word: VocabularyWord) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Palette.background)
                if !premium.hasLesson(word) {
                    Image(systemName: "lock.fill").foregroundStyle(Palette.forest)
                        .accessibilityLabel("Illustrated lesson requires Premium")
                } else if store.hasArtwork(for: word), store.activeArtwork(for: word.id) != nil || !word.imageContainsText {
                    WordArtworkImage(word: word, thumbnail: true).padding(4)
                } else {
                    Image(systemName: word.symbol).font(.system(size: 23)).foregroundStyle(Palette.forest)
                }
            }
            .frame(width: 51, height: 55).clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text(word.swedish).font(.system(size: 20, weight: .medium, design: .serif)).foregroundStyle(Palette.ink)
                Text(word.english).font(.subheadline).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            StatusBadge(status: word.status)
        }
        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
