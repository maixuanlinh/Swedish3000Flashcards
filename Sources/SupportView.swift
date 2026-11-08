import SwiftUI

enum AppSupport {
    static let websiteURL = URL(string: "https://yki.essaykingapp.com/")!
    static let privacyURL = URL(string: "https://yki.essaykingapp.com/swedish3000/privacy.html")!
    static let email = "support@essaykingapp.com"
    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }
    static var emailURL: URL {
        var url = URLComponents()
        url.scheme = "mailto"
        url.path = email
        url.queryItems = [
            URLQueryItem(name: "subject", value: "3000 Swedish Words: Report or feedback"),
            URLQueryItem(name: "body", value: "Tell us about a problem or share your feedback:\n\n\nIf reporting a bug, what happened and what did you expect?\n\n\n" + version)
        ]
        return url.url!
    }
}

struct SettingsSupportSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Link(destination: AppSupport.websiteURL) {
                HStack(spacing: 14) {
                    Image(systemName: "globe").font(.title3)
                        .frame(width: 44, height: 44).background(Palette.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visit our website").font(.headline)
                        Text("yki.essaykingapp.com").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }.foregroundStyle(Palette.accent).padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 23))
            }.accessibilityIdentifier("settings.website")

            VStack(alignment: .leading, spacing: 10) {
                Text("Help & support").font(.headline).foregroundStyle(Palette.ink)
                Link(destination: AppSupport.emailURL) {
                    HStack(spacing: 12) {
                        Label("Report a problem", systemImage: "envelope")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption)
                    }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.accessibilityIdentifier("settings.report")
                Text("Found a bug or have an idea? Send us an email.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Text(AppSupport.email).font(.footnote).foregroundStyle(Palette.muted).textSelection(.enabled)
            }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 23))

            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy & about").font(.headline).foregroundStyle(Palette.ink)
                Link(destination: AppSupport.privacyURL) {
                    HStack {
                        Label("Privacy policy", systemImage: "hand.raised")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption)
                    }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.foregroundStyle(Palette.accent).accessibilityIdentifier("settings.privacy")
                Text("Study progress and imported artwork are stored in this app on your device. Restoring Premium restores purchase access, not your learning history.")
                Text("An independent Swedish vocabulary learning app from Linapps. Not affiliated with an official examination provider.")
                Text(AppSupport.version)
            }.font(.footnote).foregroundStyle(Palette.muted)
                .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 23))
        }.tint(Palette.accent)
    }
}
