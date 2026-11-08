import SwiftUI

struct ProgressViewScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

    @State private var selectedWord: VocabularyWord?

    private var days: [Date] {
        let start = Calendar.current.startOfDay(for: .now)
        return (-6...0).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "Your Swedish, growing")
                            Text("Your progress")
                                .font(.system(size: 31, weight: .semibold, design: .serif))
                                .foregroundStyle(Palette.ink)
                        }
                        Spacer()
                    }
                    resumeCard
                    learningCard
                    masteryCard
                    HStack(spacing: 12) {
                        metric("Learning", value: store.count(.learning), icon: "arrow.triangle.2.circlepath", color: Palette.clay, background: Palette.peach)
                        metric("New words", value: store.count(.new), icon: "sparkle", color: Palette.accent, background: Palette.accentSoft)
                    }
                    weeklyActivity
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Today’s practice").font(.headline).foregroundStyle(Palette.ink)
                            Text("\(reviewLabel(store.todayCount)) · goal: 10")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: store.todayCount >= 10 ? "checkmark.seal.fill" : "sun.max.fill")
                            .font(.system(size: 29)).foregroundStyle(Palette.accent)
                    }
                    .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 23))
                    Button {
                        if store.count(.learning) > 0 { navigation.studyLearningWords() }
                        else {
                            navigation.applyFilters(scope: .remaining, letter: nil, topic: nil)
                            navigation.review(.remaining)
                        }
                    } label: {
                        Label("Keep practising", systemImage: "arrow.right")
                    }
                    .buttonStyle(FilledActionStyle())
                }
                .frame(maxWidth: 580).padding(22).frame(maxWidth: .infinity)
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedWord) { WordDetailView(word: $0) }
            .onChange(of: navigation.request) { _, _ in selectedWord = nil }
        }
    }

    @ViewBuilder private var resumeCard: some View {
        if let session = store.savedSession, !session.remainingIDs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Continue your last session", systemImage: "bookmark.fill")
                    .font(.headline).foregroundStyle(Palette.accent)
                Text(session.topic ?? session.scope.title).font(.subheadline).foregroundStyle(Palette.ink)
                Text("\(session.remainingIDs.count) words remaining · your place is saved")
                    .font(.caption).foregroundStyle(Palette.muted)
                Button { navigation.resumeStudy() } label: {
                    Label("Resume studying", systemImage: "play.fill")
                }.buttonStyle(FilledActionStyle()).accessibilityIdentifier("progress.resume")
            }.padding(18).background(Palette.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 23))
        }
    }

    private var learningCard: some View {
        let words = store.words.filter { $0.status == .learning }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Currently learning").font(.system(size: 23, weight: .semibold, design: .serif))
                Spacer()
                Text("\(words.count)").font(.title2.weight(.semibold))
            }.foregroundStyle(Palette.ink)
            if words.isEmpty {
                Text("Words marked Still learning stay here for your next practice.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                Text("Saved on this device, ready next time.").font(.caption).foregroundStyle(Palette.muted)
                ForEach(words.prefix(5)) { word in
                    Button { selectedWord = word } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(word.swedish).font(.headline).foregroundStyle(Palette.ink)
                                Text(word.english).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.accent)
                        }
                    }.buttonStyle(.plain)
                }
                Button { navigation.studyLearningWords() } label: {
                    Text(words.count == 1 ? "Practise this learning word" : "Practise all \(words.count) learning words").frame(maxWidth: .infinity)
                }.buttonStyle(FilledActionStyle()).accessibilityIdentifier("progress.learningWords")
            }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 23))

    }

    private var masteryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 11) {
                Text("WORDS YOU KNOW").font(.system(size: 10, weight: .bold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(store.count(.known))").font(.system(size: 58, weight: .medium, design: .serif))
                    .accessibilityIdentifier("progress.known")
                Text("of \(store.words.count) words").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .accessibilityIdentifier("progress.total")
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 9)
                Circle().trim(from: 0, to: store.knownFraction)
                    .stroke(Color(red: 0.83, green: 0.91, blue: 0.66), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 3) {
                    Text("\(Int(store.knownFraction * 100))%")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("familiar").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 105, height: 105)
        }
        .foregroundStyle(.white).padding(25)
        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 27))
    }

    private func metric(_ title: String, value: Int, icon: String, color: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon); Spacer(); Text("\(value)").font(.title2.weight(.semibold)) }
            Text(title).font(.subheadline.weight(.medium))
        }
        .foregroundStyle(color).padding(18).frame(maxWidth: .infinity)
        .background(background, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Your week").font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text(reviewLabel(days.reduce(0) { $0 + store.reviews(on: $1) }))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(days, id: \.self) { day in
                    let count = store.reviews(on: day)
                    let maximum = max(days.map { store.reviews(on: $0) }.max() ?? 1, 1)
                    VStack(spacing: 8) {
                        Text("\(count)").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Calendar.current.isDateInToday(day) ? Palette.accent : Palette.accentSoft)
                            .frame(height: max(5, CGFloat(count) / CGFloat(maximum) * 90))
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(count) reviews")
                }
            }
            .frame(height: 127, alignment: .bottom)
        }
        .padding(21).background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private func reviewLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "review" : "reviews")"
    }
}

struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    @Environment(WordReminders.self) private var reminders
    @Environment(AppNavigation.self) private var navigation
    @State private var showingPremium = false
    @State private var showingReminders = false
    @State private var showingOfflineStudy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "Make it yours")
                    Text("Settings").font(.system(size: 31, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
                    premiumCard
                    OfflineStudyRow { showingOfflineStudy = true }
                    reminderCard
                    SettingsSupportSection()
                }.frame(maxWidth: 580).padding(22).frame(maxWidth: .infinity)
            }.accessibilityIdentifier("settings.content")
                .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .sheet(isPresented: $showingReminders) { WordReminderSettingsView(settings: reminders.settings) }
            .sheet(isPresented: $showingOfflineStudy) { OfflineStudyView() }
            .onChange(of: navigation.request) { _, _ in
                showingPremium = false; showingReminders = false; showingOfflineStudy = false
            }
        }
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showingPremium = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: premium.isPremium ? "checkmark.seal.fill" : "sparkles")
                        .font(.title2).frame(width: 44, height: 44).background(Palette.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(premium.isPersonal ? "3000 Swedish Words Personal" : premium.isPremium ? "3000 Swedish Words Premium" : "3000 Swedish Words Free").font(.headline)
                            .accessibilityIdentifier("settings.membership")
                        Text(!premium.checked ? "Checking purchase…" : premium.isPremium ? "All 3,000 complete lessons unlocked" : "211 complete A-set lessons included")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(Palette.accent)
            }.buttonStyle(.plain).accessibilityIdentifier("settings.premium")
            if !premium.isPersonal {
                VStack(spacing: 12) {
                    if !premium.isPremium {
                        Button { showingPremium = true } label: {
                            Label("Go Premium", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(FilledActionStyle()).accessibilityIdentifier("settings.upgrade")
                    }
                    Button("Restore Purchases") { Task { await premium.restore() } }
                        .font(.caption.weight(.medium)).disabled(premium.busy)
                        .accessibilityIdentifier("settings.restore")
                }
            }
            if let message = premium.message {
                Text(message).font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("settings.purchaseMessage")
            }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 23))
    }

    private var reminderCard: some View {
        Button {
            if premium.isPremium { showingReminders = true } else { showingPremium = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bell.badge").font(.title3)
                    .frame(width: 44, height: 44).background(Palette.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Word reminders").font(.headline); if !premium.isPremium { Text("Premium").font(.caption.weight(.semibold)) } }
                    if reminders.settings.enabled, let date = reminders.nextDate {
                        Text("Next: \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        Text(reminders.settings.enabled ? "Check notification settings" : "A little Swedish, throughout your day")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.foregroundStyle(Palette.accent).padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 23))
        }.buttonStyle(.plain).accessibilityIdentifier("settings.reminders")
    }

}
