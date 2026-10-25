import SwiftUI
import AVFoundation

struct StudyView: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppNavigation.self) private var navigation
    @AppStorage("englishFirst") private var englishFirst = true
    @State private var queue: [String] = []
    @State private var history: [ReviewSnapshot] = []
    @State private var initialCount = 0
    @State private var started = false
    @State private var revealed = false
    @State private var drag: CGFloat = 0
    @State private var advancing = false
    @State private var draggingCard = false
    @State private var suppressTapsUntil = Date.distantPast
    @State private var error: String?
    @State private var detailWord: VocabularyWord?
    @State private var showingFilters = false
    @State private var speech: SpeechPlayer?
    @State private var playback = AutoStudyPlayer()
    @State private var showingPlayback = false
    @State private var showingPremium = false
    @AppStorage("recallSeconds") private var recallSeconds = 3.0
    @AppStorage("answerSeconds") private var answerSeconds = 2.0
    @AppStorage("readPrompt") private var readPrompt = true
    @AppStorage("readSentence") private var readSentence = true
    @AppStorage("readAnswer") private var readAnswer = true
    @AppStorage("speechRate") private var speechRate = 0.42

    private var automaticLocked: Bool { !premium.isPremium && queue.contains { id in
        store.word(withID: id).map { !premium.hasLesson($0) } ?? false
    } }

    private var showsEnglishFirst: Bool { navigation.promptEnglishFirst ?? englishFirst }

    private var current: VocabularyWord? {
        guard let id = playback.currentID ?? queue.first else { return nil }
        return store.word(withID: id)
    }
    private var canTapCard: Bool {
        !advancing && !draggingCard && Date.now >= suppressTapsUntil
    }
    private var filterTitle: String {
        [navigation.requestedIDs == nil ? navigation.scope.title : "Selected words",
         navigation.startingLetter, navigation.topic].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls
                if let word = current {
                    cardStack(word)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if playback.isActive { playbackControls } else { ratingButtons }
                } else {
                    completion.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
            .frame(maxWidth: 520).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if !started { startSession() }
                else { reconcileQueue() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
                if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   type == AVAudioSession.InterruptionType.began.rawValue { playback.pause() }
            }
            .onDisappear { playback.pause(); speech?.stop() }
            .onChange(of: navigation.tab) { _, tab in if tab != 0 { playback.pause() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
            .onChange(of: navigation.request) { _, _ in
                detailWord = nil; showingPlayback = false; showingFilters = false; showingPremium = false
                speech?.stop(); startSession()
            }
            .sheet(isPresented: $showingPremium) {
                PremiumView(preview: { navigation.applyFilters(scope: .all, letter: "A", topic: nil) })
            }
            .onChange(of: premium.isPremium) { _, owns in
                if !owns { playback.stop(); speech?.stop() }
            }
            .sheet(isPresented: $showingPlayback) { AutoStudyOptions(start: startAutomatic) }
            .sheet(isPresented: $showingFilters) {
                VocabularyFilterSheet(words: store.words, scope: navigation.scope,
                                      letter: navigation.startingLetter, topic: navigation.topic,
                                      onApply: navigation.applyFilters)
            }
            .sheet(item: $detailWord, onDismiss: reconcileQueue) { WordDetailView(word: $0) }
            .alert("Couldn’t complete that action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "Please try again.") }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button { playback.pause(); showingFilters = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(filterTitle).lineLimit(1)
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Filters: \(filterTitle)")
            .accessibilityIdentifier("study.filters")
            Spacer(minLength: 2)
            Text(playback.isActive ? "\(playback.playedCount) / \(playback.total)" : "\(initialCount - queue.count) / \(initialCount)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
                .fixedSize().accessibilityIdentifier("session.count")
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward").frame(width: 36, height: 44)
            }
            .accessibilityLabel("Undo last swipe").accessibilityIdentifier("review.undo")
            .disabled(history.isEmpty || advancing)
            Button {
                speech?.stop()
                if playback.isPlaying { playback.pause() }
                else if playback.state == .paused { playback.resume() }
                else { startAutomatic() }
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").frame(width: 36, height: 44)
                    .overlay(alignment: .topTrailing) { if automaticLocked { PremiumLock().allowsHitTesting(false) } }
            }.accessibilityLabel(playback.isPlaying ? "Pause automatic study" : "Play automatic study")
                .accessibilityIdentifier("study.autoplay").disabled(advancing || current == nil)
            Menu {
                Button("Playback settings", systemImage: "slider.horizontal.3") { playback.pause(); showingPlayback = true }
                Button(showsEnglishFirst ? "Show Swedish first" : "Show English first", systemImage: "arrow.left.arrow.right") {
                    playback.stop(); englishFirst = !showsEnglishFirst; navigation.promptEnglishFirst = nil; revealed = false
                }
                Button("Shuffle this session", systemImage: "shuffle") { playback.stop(); queue.shuffle(); revealed = false }
            } label: {
                Image(systemName: "ellipsis").frame(width: 32, height: 44)
            }
            .accessibilityLabel("Study options").accessibilityIdentifier("study.options")
        }
        .foregroundStyle(Palette.forest)
        .frame(height: 44)
    }

    private func cardStack(_ word: VocabularyWord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 27).fill(Palette.sage)
                .padding(.horizontal, 10).offset(y: 7)
            FlashcardView(word: word, revealed: Binding(
                            get: { playback.isActive ? playback.revealed : revealed },
                            set: { value in if playback.isActive { playback.flip() } else { revealed = value } }), englishFirst: showsEnglishFirst,
                          canInteract: { canTapCard },
                          openDetail: {
                              guard canTapCard else { return }
                              playback.pause(); detailWord = word
                          }, play: { if canTapCard { play(word.swedish) } },
                          openPremium: { playback.pause(); showingPremium = true })
                .background(.white, in: RoundedRectangle(cornerRadius: 27))
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(drag < 0 ? Palette.clay.opacity(Double(min(abs(drag)/100,1))) : Palette.forest.opacity(Double(min(drag/100,1))), lineWidth: 3)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: drag < 0 ? .topTrailing : .topLeading) {
                    if abs(drag) > 24 {
                        Text(drag < 0 ? "LEARNING" : "KNOWN")
                            .font(.headline).tracking(1).padding(12)
                            .foregroundStyle(drag < 0 ? Palette.clay : Palette.forest)
                            .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                            .padding(18).allowsHitTesting(false)
                    }
                }
                .shadow(color: Palette.ink.opacity(0.05), radius: 12, y: 5)
                .offset(x: drag).rotationEffect(.degrees(Double(drag / 25)))
                .simultaneousGesture(DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard !advancing else { return }
                        if !draggingCard { playback.pause() }
                        draggingCard = true
                        suppressTapsUntil = Date.now.addingTimeInterval(0.35)
                        if abs(value.translation.width) > abs(value.translation.height) { drag = value.translation.width }
                    }
                    .onEnded { value in
                        draggingCard = false
                        suppressTapsUntil = Date.now.addingTimeInterval(0.35)
                        guard !advancing else { return }
                        let distance = value.translation.width
                        let horizontal = abs(distance) > abs(value.translation.height)
                        if horizontal && (abs(distance) > 75 || (abs(distance) > 25 && abs(value.predictedEndTranslation.width) > 170)) {
                            rate(distance > 0 ? .known : .learning)
                        } else {
                            withAnimation(.spring(response: 0.3)) { drag = 0 }
                        }
                    })
                .accessibilityElement(children: .contain).accessibilityIdentifier("study.card")
        }
        .padding(.bottom, 7)
    }

    private var playbackControls: some View {
        VStack(spacing: 4) {
            if let message = playback.error { Text(message).font(.caption).foregroundStyle(Palette.clay) }
            HStack(spacing: 12) {
                Button { speech?.stop(); playback.step(-1) } label: { Image(systemName: "backward.end.fill").frame(width: 44, height: 54).contentShape(Rectangle()) }
                    .accessibilityLabel("Previous card").accessibilityIdentifier("playback.previous")
                Button {
                    speech?.stop()
                    if playback.isPlaying { playback.pause() }
                    else if playback.state == .finished { startAutomatic() }
                    else { playback.resume() }
                } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").frame(maxWidth: .infinity, minHeight: 54).contentShape(Rectangle()) }
                    .accessibilityLabel(playback.isPlaying ? "Pause automatic study" : "Play automatic study")
                    .accessibilityIdentifier("playback.pause")
                Button { speech?.stop(); playback.step(1) } label: { Image(systemName: "forward.end.fill").frame(width: 44, height: 54).contentShape(Rectangle()) }
                    .accessibilityLabel("Next card").accessibilityIdentifier("playback.next")
                Button { speech?.stop(); playback.stop(); revealed = false } label: { Image(systemName: "stop.fill").frame(width: 44, height: 54).contentShape(Rectangle()) }
                    .accessibilityLabel("Return to manual study").accessibilityIdentifier("playback.stop")
            }.foregroundStyle(Palette.forest).frame(maxWidth: .infinity)
                .background(Palette.sage, in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }

    private func startAutomatic() {
        guard !automaticLocked else { playback.pause(); showingPremium = true; return }
        guard !advancing else { return }
        speech?.stop()
        let candidates = queue.compactMap { store.word(withID: $0) }
        guard !candidates.isEmpty else { return }
        let items = candidates.map { word in
            AutoStudyItem(id: word.id, prompt: showsEnglishFirst ? word.english : word.swedish,
                promptLanguage: showsEnglishFirst ? "en-GB" : "sv-SE", answer: showsEnglishFirst ? word.swedish : word.english,
                answerLanguage: showsEnglishFirst ? "sv-SE" : "en-GB", sentence: word.sentence)
        }
        playback.start(items, settings: AutoStudySettings(recallSeconds: recallSeconds, answerSeconds: answerSeconds,
            readPrompt: readPrompt, readAnswer: readAnswer, readSentence: readSentence, speechRate: Float(speechRate)))
    }

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            Button { rate(.learning) } label: {
                HStack(spacing: 7) { Image(systemName: "arrow.left"); Text("Still learning") }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(Palette.clay).background(Palette.peach, in: RoundedRectangle(cornerRadius: 17))
            }
            .accessibilityIdentifier("review.learning")
            Button { rate(.known) } label: {
                HStack(spacing: 7) { Text("I know it"); Image(systemName: "checkmark") }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white).background(Palette.forest, in: RoundedRectangle(cornerRadius: 17))
            }
            .accessibilityIdentifier("review.known")
        }
        .font(.system(size: 14, weight: .semibold)).buttonStyle(.plain).disabled(advancing)
    }

    private var completion: some View {
        VStack(spacing: 20) {
            Image(systemName: history.isEmpty ? "leaf.circle" : "checkmark.seal.fill")
                .font(.system(size: 50)).foregroundStyle(Palette.forest)
            Text(history.isEmpty ? "No words in this group" : "Practice complete")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text(history.isEmpty ? "Change your filters to start practising." : "You reviewed \(history.count) words. Your progress is saved.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Button("Filters") { showingFilters = true }.buttonStyle(FilledActionStyle())
            Button("Study all \(store.words.count) words") {
                navigation.applyFilters(scope: .all, letter: nil, topic: nil)
            }.font(.subheadline.weight(.semibold))
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 27))
        .accessibilityElement(children: .contain).accessibilityIdentifier("session.complete")
    }

    private func reconcileQueue() {
        let previous = queue.first
        queue.removeAll { id in
            guard let word = store.word(withID: id) else { return true }
            return !navigation.scope.includes(word)
        }
        if playback.isActive, let id = playback.currentID, !queue.contains(id) { playback.stop() }
        if queue.first != previous { revealed = false }
    }

    private func startSession() {
        playback.stop()
        let selectedIDs = navigation.requestedIDs.map { Set($0) }
        queue = store.reviewWords(in: navigation.scope, startingWith: navigation.startingLetter)
            .filter { (navigation.topic == nil || $0.topic == navigation.topic) && (selectedIDs?.contains($0.id) ?? true) }.map(\.id)
        initialCount = queue.count
        history = []
        revealed = false
        drag = 0
        advancing = false
        draggingCard = false
        suppressTapsUntil = .distantPast
        started = true
    }

    private func rate(_ status: LearningStatus) {
        guard !advancing, let word = current else { return }
        playback.stop()
        do {
            let snapshot = try store.rate(word, as: status)
            history.append(snapshot)
            advancing = true
            let request = navigation.request
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeIn(duration: 0.18)) { drag = status == .known ? 600 : -600 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(190))
                guard navigation.request == request else { return }
                queue.removeAll { $0 == word.id }
                revealed = false
                drag = 0
                advancing = false
            }
        } catch {
            self.error = error.localizedDescription
            withAnimation { drag = 0 }
        }
    }

    private func undo() {
        guard !advancing, let snapshot = history.last else { return }
        playback.stop()
        do {
            try store.undo(snapshot)
            history.removeLast()
            queue.removeAll { $0 == snapshot.wordID }
            queue.insert(snapshot.wordID, at: 0)
            revealed = false
        } catch { self.error = error.localizedDescription }
    }

    private func play(_ text: String) {
        playback.pause()
        if speech == nil { speech = SpeechPlayer() }
        if speech?.speak(text, rate: Float(speechRate)) != true { error = "A Swedish voice is not available on this device. You can add one in Settings → Accessibility → Spoken Content → Voices." }
    }
}

private struct FlashcardView: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    let word: VocabularyWord
    @Binding var revealed: Bool
    let englishFirst: Bool
    let canInteract: () -> Bool
    let openDetail: () -> Void
    let play: () -> Void
    let openPremium: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 450
            VStack(spacing: 0) {
                if revealed {
                    VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: englishFirst ? "Swedish" : "English")
                                Text(englishFirst ? word.swedish : word.english)
                                    .font(.system(size: compact ? 28 : 34, weight: .medium, design: .serif))
                                    .minimumScaleFactor(0.65).lineLimit(2).foregroundStyle(Palette.ink)
                                    .accessibilityIdentifier("card.answer")
                            }
                            Spacer(minLength: 0)
                            Button(action: play) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .frame(width: 44, height: 44).background(Palette.sage, in: Circle())
                            }.accessibilityLabel("Play Swedish pronunciation")
                            detailButton
                        }
                        .layoutPriority(1)
                        if premium.hasLesson(word), !word.sentence.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(word.sentence).font(.system(size: compact ? 16 : 18, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                    .accessibilityIdentifier("card.sentence")
                                if !word.sentenceEnglish.isEmpty {
                                    Text(word.sentenceEnglish).font(.system(size: compact ? 13 : 15))
                                        .foregroundStyle(Palette.muted)
                                        .accessibilityIdentifier("card.translation")
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                        }
                        if !premium.hasLesson(word) {
                            LockedLessonView(compact: compact, open: openPremium)
                        } else if store.hasArtwork(for: word) {
                            GeometryReader { area in
                                let side = max(1, min(area.size.width, area.size.height))
                                WordArtworkImage(word: word)
                                    .frame(width: side, height: side)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                                .background(Palette.background, in: RoundedRectangle(cornerRadius: 16))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(width: area.size.width, height: area.size.height)
                            }
                            .accessibilityElement(children: .ignore).accessibilityLabel("Illustration").accessibilityIdentifier("card.artwork")
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, compact ? 14 : 20)
                    .padding(.bottom, 10)
                } else {
                    Button { flip() } label: {
                        VStack(spacing: 16) {
                            Spacer(minLength: 0)
                            Eyebrow(text: englishFirst ? "English" : "Swedish")
                            Text(englishFirst ? word.english : word.swedish)
                                .font(.system(size: 42, weight: .medium, design: .serif))
                                .minimumScaleFactor(0.55).lineLimit(3)
                                .multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                                .accessibilityIdentifier("card.prompt")
                            Spacer(minLength: 0)
                        }
                        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(englishFirst ? "Reveal Swedish" : "Reveal English")
                    .accessibilityIdentifier("card.reveal")
                }
                Button { flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.forest)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Palette.sage.opacity(0.45))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(revealed ? "Show prompt" : "Flip card")
                .accessibilityIdentifier("card.flip")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 27))
        }
    }

    private var detailButton: some View {
        Button(action: openDetail) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44).background(Palette.sage, in: Circle())
        }
        .buttonStyle(.plain).foregroundStyle(Palette.forest)
        .accessibilityLabel("Open word details")
        .accessibilityIdentifier("card.detail")
    }

    private func flip() {
        guard canInteract() else { return }
        withAnimation(.easeInOut(duration: 0.2)) { revealed.toggle() }
    }
}
