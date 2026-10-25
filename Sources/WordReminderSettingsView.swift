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
        _frequency = State(initialValue: presets.first { $0.value == settings.times }?.key ?? 0)
    }

    private var matchingWords: [VocabularyWord] {
        store.words.filter { word in
            (draft.letter == nil || store.initial(for: word) == draft.letter) &&
            (draft.pool == .all || (draft.pool == .learning ? word.status == .learning : word.status != .known))
        }
    }

    var body: some View {
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
                        Text("Once a day").tag(1)
                        Text("Twice a day").tag(2)
                        Text("Four times a day").tag(4)
                        Text("Custom times").tag(0)
                    }.accessibilityIdentifier("reminders.frequency")
                    ForEach(draft.times.indices, id: \.self) { index in
                        DatePicker("Reminder \(index + 1)", selection: timeBinding(index), displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("reminders.time.\(index)")
                    }
                    .onDelete { offsets in
                        guard offsets.count < draft.times.count else { return }
                        draft.times.remove(atOffsets: offsets); frequency = 0
                    }
                    if draft.times.count < 4 {
                        Button("Add time", systemImage: "plus") {
                            var minute = ((draft.times.max() ?? 300) + 240) % 1440
                            while draft.times.contains(minute) { minute = (minute + 60) % 1440 }
                            draft.times.append(minute); frequency = 0
                        }.accessibilityIdentifier("reminders.addTime")
                    }
                } header: { Text("Your schedule") } footer: {
                    Text("Up to four reminders a day, at your local time. Choose times that suit your waking hours.")
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
                if !premium.isPremium {
                    Section {
                        Button { showingPremium = true } label: {
                            Label("Unlock artwork reminders for B–Z", systemImage: "lock.fill")
                        }
                        Text("Word reminders stay free for every letter. A-set reminders include artwork for free.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
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
                    Text("We prepare the next 14 days of words and refresh them whenever you open 3000 Swedish Words. After a long break, a final reminder invites you back to refill the schedule.")
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
                    }.buttonStyle(FilledActionStyle()).disabled(reminders.busy || (draft.enabled && matchingWords.isEmpty))
                        .accessibilityIdentifier("reminders.save")
                }.padding(16).background(Palette.background)
            }
            .task { await reminders.checkPermission() }
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reminders.checkPermission() } }
            }
            .onChange(of: frequency) { _, value in
                if value == 1 { draft.times = [540] }
                else if value == 2 { draft.times = [540, 1020] }
                else if value == 4 { draft.times = [540, 780, 1020, 1260] }
            }
        }
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
