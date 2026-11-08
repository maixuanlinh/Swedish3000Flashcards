import SwiftUI
import UserNotifications

struct WordReminderSettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(WordReminders.self) private var reminders
    @Environment(PremiumStore.self) private var premium
    @State private var showingPremium = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var draft: WordReminderSettings
    @State private var frequency: Int

    init(settings: WordReminderSettings) {
        _draft = State(initialValue: settings)
        let presets = [1: [540], 2: [540, 1020], 4: [540, 780, 1020, 1260]]
        _frequency = State(initialValue: settings.intervalMinutes ?? (presets.first { $0.value == settings.times }?.key ?? 0))
    }

    private var matchingWords: [VocabularyWord] {
        store.words.filter { word in
            (draft.letter == nil || store.initial(for: word) == draft.letter) &&
            (draft.pool == .all || (draft.pool == .learning ? word.status == .learning : word.status != .known))
        }
    }

    var body: some View {
        if premium.isPremium { editor } else { PremiumView() }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Word reminders", isOn: $draft.enabled)
                        .accessibilityIdentifier("reminders.enabled")
                        .accessibilityValue(draft.enabled ? "On" : "Off")
                } footer: {
                    Text("A little Swedish throughout your day. Works offline, even when 3000 Swedish Words is closed.")
                }
                if reminders.authorization == .denied {
                    Section {
                        Text("Notifications are disabled in iPhone Settings.")
                        Button("Open iPhone Settings", systemImage: "arrow.up.forward.app") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.accessibilityIdentifier("reminders.systemSettings")
                    }
                }
                Section {
                    Picker("Frequency", selection: $frequency) {
                        Text("Every 30 minutes").tag(30)
                        Text("Every hour").tag(60)
                        Text("Every 2 hours").tag(120)
                        Text("Every 3 hours").tag(180)
                        Text("Every 4 hours").tag(240)
                        Text("Once a day").tag(1)
                        Text("Twice a day").tag(2)
                        Text("Four times a day").tag(4)
                        Text("Custom times").tag(0)
                    }.accessibilityIdentifier("reminders.frequency")
                    if draft.intervalMinutes == nil {
                        ForEach(draft.times.indices, id: \.self) { index in
                            DatePicker("Reminder \(index + 1)", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                                .accessibilityIdentifier("reminders.time.\(index)")
                        }
                        .onDelete { offsets in
                            guard offsets.count < draft.times.count else { return }
                            draft.times.remove(atOffsets: offsets); frequency = 0
                        }
                        if draft.times.count < 48 {
                            Button("Add time", systemImage: "plus") {
                                var minute = ((draft.times.max() ?? 300) + 240) % 1440
                                while draft.times.contains(minute) { minute = (minute + 30) % 1440 }
                                draft.times.append(minute); frequency = 0
                            }.accessibilityIdentifier("reminders.addTime")
                        }
                    }
                    Text("\(draft.scheduledMinutes.count) reminders per day · repeats daily")
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("reminders.dailyCount")
                } header: { Text("Your schedule") } footer: {
                    Text("Reminders repeat every day with no end date. Words reshuffle when you open the app.")
                }
                Section("Sleep hours") {
                    Toggle("Pause while sleeping", isOn: Binding(get: { draft.sleepStart != nil && draft.sleepEnd != nil }, set: { enabled in
                        draft.sleepStart = enabled ? 22 * 60 : nil
                        draft.sleepEnd = enabled ? 8 * 60 : nil
                    })).accessibilityIdentifier("reminders.sleepEnabled")
                    if draft.sleepStart != nil && draft.sleepEnd != nil {
                        DatePicker("Sleep from", selection: sleepBinding(\.sleepStart, fallback: 22 * 60), displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("reminders.sleepStart")
                        DatePicker("Wake at", selection: sleepBinding(\.sleepEnd, fallback: 8 * 60), displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("reminders.sleepEnd")
                        Text("No word reminders are scheduled during these hours. Times follow your device’s local time zone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Picker("Words to practise", selection: $draft.pool) {
                        ForEach(ReminderPool.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("reminders.pool")
                    Picker("Starting letter", selection: Binding(get: { draft.letter ?? "all" },
                        set: { draft.letter = $0 == "all" ? nil : $0 })) {
                        Text("All letters").tag("all")
                        ForEach(EnglishAlphabet.letters, id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("reminders.letter")
                    Text("\(matchingWords.count) words · shuffled without immediate repeats")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("reminders.matchingCount")
                } header: { Text("Word selection") }
                Section {
                    Picker("Show", selection: $draft.prompt) {
                        ForEach(ReminderPrompt.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("reminders.prompt")
                    Toggle("Artwork thumbnail", isOn: $draft.showArtwork)
                        .accessibilityIdentifier("reminders.artwork")
                    Toggle("Notification sound", isOn: $draft.sound)
                        .accessibilityIdentifier("reminders.sound")
                } header: { Text("Notification") } footer: {
                    Text("Artwork may include the answer. Turn it off for a recall challenge. Notifications use a short chime, not spoken audio.")
                }
                Section("Preview") {
                    if let word = matchingWords.first(where: { $0.english == "apple" }) ?? matchingWords.first {
                        preview(word)
                    } else {
                        Text("No words match. Try another group or letter.").foregroundStyle(.secondary)
                    }
                    Button("Send sample in 5 seconds", systemImage: "bell.badge") {
                        Task { await reminders.sendSample(store: store, draft: draft) }
                    }.disabled(reminders.busy || matchingWords.isEmpty)
                        .accessibilityIdentifier("reminders.sample")
                }
                Section {
                    Text("Your schedule continues while the app is closed. Reopen the app to refresh the words assigned to each time. Sleep hours apply to scheduled reminders; the sample button sends one immediately for testing.")
                    Text("Your iPhone’s Focus and notification settings control when alerts appear. Opening a reminder never marks a word as Known.")
                }.font(.footnote).foregroundStyle(.secondary)
                if let message = reminders.message {
                    Section { Text(message).accessibilityIdentifier("reminders.message") }
                }
                if reminders.missingArtwork > 0 {
                    Section { Text("\(reminders.missingArtwork) reminders use text only because their artwork couldn’t be attached.") }
                }
            }
            .accessibilityIdentifier("reminders.form")
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("Word reminders").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let message = reminders.message {
                        Text(message).font(.caption).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center).accessibilityIdentifier("reminders.status")
                    }
                    Button {
                        Task { if await reminders.save(draft, store: store) { dismiss() } }
                    } label: {
                        HStack {
                            if reminders.busy { ProgressView().tint(.white) }
                            Text(reminders.busy ? "Updating…" : "Save reminders")
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(FilledActionStyle()).disabled(reminders.busy || (draft.enabled && (matchingWords.isEmpty || draft.scheduledMinutes.isEmpty)))
                        .accessibilityIdentifier("reminders.save")
                }.padding(16).background(Palette.background)
            }
            .task { await reminders.checkPermission() }
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reminders.checkPermission() } }
            }
            .onChange(of: frequency) { _, value in
                draft.intervalMinutes = value >= 30 ? value : nil
                if value == 1 { draft.times = [540] }
                else if value == 2 { draft.times = [540, 1020] }
                else if value == 4 { draft.times = [540, 780, 1020, 1260] }
            }
        }
    }

    private func sleepBinding(_ key: WritableKeyPath<WordReminderSettings, Int?>, fallback: Int) -> Binding<Date> {
        Binding(get: {
            let minute = draft[keyPath: key] ?? fallback
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft[keyPath: key] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(get: {
            let minute = draft.times.indices.contains(index) ? draft.times[index] : 540
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            guard draft.times.indices.contains(index) else { return }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft.times[index] = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        })
    }

    private func preview(_ word: VocabularyWord) -> some View {
        let value = ReminderWord(id: word.id, english: word.english, swedish: word.swedish, status: word.statusRaw, thumbnail: nil)
        let text = WordReminderPlan.text(for: value, prompt: draft.prompt)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SWEDISHCARDS").font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
                Text(text.title).font(.subheadline.weight(.semibold))
                Text(text.body).font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if draft.showArtwork {
                WordArtworkImage(word: word, thumbnail: true)
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Word artwork thumbnail")
            }
        }.padding(.vertical, 8).accessibilityIdentifier("reminders.preview")
    }
}
