import SwiftUI

enum AppSupport {
    static let emailURL = URL(string: "mailto:support@essaykingapp.com?subject=3000%20Swedish%20Words%20support")!
}

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Help") {
                    Label("Swedish support pages are being prepared.", systemImage: "questionmark.circle")
                        .accessibilityIdentifier("support.website")
                    Link(destination: AppSupport.emailURL) {
                        Label("Email support", systemImage: "envelope")
                    }.accessibilityIdentifier("support.email")
                    Text("support@essaykingapp.com")
                        .font(.footnote).foregroundStyle(Palette.muted).textSelection(.enabled)
                }
                Section("Privacy") {
                    Label("Swedish privacy policy will be available before release.", systemImage: "hand.raised")
                        .accessibilityIdentifier("support.privacy")
                    Text("Study progress and imported artwork are stored in this app on your device. Restoring Premium restores purchase access, not your learning history.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Section("About 3000 Swedish Words") {
                    Text("An independent Swedish vocabulary learning app from Linapps. Not affiliated with an official examination provider.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                       let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                        Text("Version \(version) (\(build))")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("Help and privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("support.done")
                }
            }
        }.tint(Palette.forest)
    }
}
