import SwiftUI

struct AutoStudyOptions: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recallSeconds") private var recall = 3.0
    @AppStorage("answerSeconds") private var answer = 2.0
    @AppStorage("readPrompt") private var readPrompt = true
    @AppStorage("readAnswer") private var readAnswer = true
    @AppStorage("readSentence") private var readSentence = true
    @AppStorage("speechRate") private var rate = 0.42
    let start: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Recall the word, hear the answer, then move on automatically.")
                    Text("Listening does not mark words as Known. Use manual study when you want to rate them.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Pace") {
                    Stepper("Recall pause: \(Int(recall)) seconds", value: $recall, in: 1...15, step: 1).accessibilityIdentifier("playback.recall")
                    Stepper("Pause after audio: \(Int(answer)) seconds", value: $answer, in: 1...15, step: 1).accessibilityIdentifier("playback.answerPause")
                }
                Section("Pronunciation") {
                    Toggle("Read the prompt", isOn: $readPrompt).accessibilityIdentifier("playback.promptAudio").accessibilityValue(readPrompt ? "On" : "Off")
                    Toggle("Read the answer", isOn: $readAnswer).accessibilityIdentifier("playback.answerAudio").accessibilityValue(readAnswer ? "On" : "Off")
                    Toggle("Read the Swedish sentence", isOn: $readSentence).accessibilityIdentifier("playback.sentenceAudio").accessibilityValue(readSentence ? "On" : "Off")
                    Picker("Voice speed", selection: $rate) {
                        Text("Slow").tag(0.32)
                        Text("Natural").tag(0.42)
                        Text("Brisk").tag(0.50)
                    }
                    Text("Uses your device’s speech voices. Install a Swedish voice for offline pronunciation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

            }
            .accessibilityIdentifier("playback.form")
            .safeAreaInset(edge: .bottom) {
                Button { dismiss(); start() } label: {
                    Label("Start automatic study", systemImage: "play.fill").frame(maxWidth: .infinity)
                }.buttonStyle(FilledActionStyle()).accessibilityIdentifier("playback.start")
                    .padding(16).background(Palette.background)
            }
            .navigationTitle("Automatic study").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
