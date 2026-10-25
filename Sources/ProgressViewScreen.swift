import SwiftUI

struct ProgressViewScreen: View {
    @Environment(WordReminders.self) private var reminders
    @Environment(PremiumStore.self) private var premium
    @State private var showingPremium = false
    @State private var showingReminders = false
    @State private var showingSupport = false
    @Environment(StudyStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

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
                        Button { showingSupport = true } label: {
                            Label("Help", systemImage: "questionmark.circle")
                                .font(.subheadline.weight(.medium)).padding(.vertical, 8)
                        }.accessibilityIdentifier("progress.support")
                    }
                    premiumCard
                    reminderCard
                    masteryCard
                    HStack(spacing: 12) {
                        metric("Learning", value: store.count(.learning), icon: "arrow.triangle.2.circlepath", color: Palette.clay, background: Palette.peach)
                        metric("New words", value: store.count(.new), icon: "sparkle", color: Palette.forest, background: Palette.sage)
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
                            .font(.system(size: 29)).foregroundStyle(Palette.forest)
                    }
                    .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 23))
                    Button {
                        navigation.review(store.count(.learning) > 0 ? .learning : .remaining)
                    } label: {
                        Label("Keep practising", systemImage: "arrow.right")
                    }
                    .buttonStyle(FilledActionStyle())
                }
                .frame(maxWidth: 580).padding(22).frame(maxWidth: .infinity)
            }
            .background(Palette.background).toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingReminders) { WordReminderSettingsView(settings: reminders.settings) }
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .sheet(isPresented: $showingSupport) { SupportView() }
            .onChange(of: navigation.request) { _, _ in
                showingReminders = false; showingPremium = false; showingSupport = false
            }
        }
    }

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showingPremium = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: premium.isPremium ? "checkmark.seal.fill" : "sparkles")
                        .font(.title2).frame(width: 44, height: 44).background(Palette.sage, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(premium.isPersonal ? "3000 Swedish Words Personal" : premium.isPremium ? "3000 Swedish Words Premium" : "3000 Swedish Words Free").font(.headline)
                            .accessibilityIdentifier("progress.membership")
                        Text(!premium.checked ? "Checking purchase…" : premium.isPremium ? "Available Swedish lessons unlocked" : "211 A-set words; artwork in progress")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }.foregroundStyle(Palette.forest)
            }.buttonStyle(.plain).accessibilityIdentifier("progress.premium")
            if !premium.isPersonal {
                HStack {
                    if !premium.isPremium {
                        Button("Explore Premium") { showingPremium = true }
                            .font(.subheadline.weight(.semibold)).accessibilityIdentifier("progress.upgrade")
                    }
                    Spacer()
                    Button("Restore Purchases") { Task { await premium.restore() } }
                        .font(.caption.weight(.medium)).disabled(premium.busy)
                        .accessibilityIdentifier("progress.restore")
                }
            }
            if let message = premium.message {
                Text(message).font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("progress.purchaseMessage")
            }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 23))
    }

    private var reminderCard: some View {
        Button { showingReminders = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "bell.badge").font(.title3)
                    .frame(width: 44, height: 44).background(Palette.sage, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Word reminders").font(.headline)
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
            }.foregroundStyle(Palette.forest).padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 23))
        }.buttonStyle(.plain).accessibilityIdentifier("progress.reminders")
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
        .background(Palette.forest, in: RoundedRectangle(cornerRadius: 27))
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
                            .fill(Calendar.current.isDateInToday(day) ? Palette.forest : Palette.sage)
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
