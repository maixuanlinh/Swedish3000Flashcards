import SwiftUI

struct OfflineStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LessonMedia.self) private var media
    @Environment(PremiumStore.self) private var premium
    @AppStorage("offlineDownloadWiFiOnly") private var wifiOnly = true
    @State private var confirmRemoval = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: displayStatus.isReady ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 42)).foregroundStyle(Palette.accent)
                        Text(displayStatus.isReady ? "Ready for offline study" : "Download for offline study")
                            .font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
                        Text(premium.isPremium ? "Save the complete collection’s images and pronunciation for studying without internet. Downloaded media occupies storage on this device." : "Save images and pronunciation for the 211 free A-set lessons. Upgrade to Premium for the full 3,000-word offline collection.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(premium.isPremium ? "Complete collection" : "Free A-set lessons", systemImage: "photo.stack")
                                .font(.headline).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(ByteCountFormatter.lessonMedia.string(fromByteCount: displayStatus.totalBytes))
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                        }
                        ProgressView(value: displayStatus.progress).tint(Palette.accent)
                            .accessibilityIdentifier("offline.progress")
                        HStack {
                            Text(progressDescription).foregroundStyle(Palette.muted)
                            Spacer()
                            Text("\(Int(displayStatus.progress * 100))%")
                                .monospacedDigit().foregroundStyle(Palette.muted)
                        }.font(.caption)
                    }
                    .padding(19).background(.white, in: RoundedRectangle(cornerRadius: 23))

                    if premium.isPremium {
                    Toggle(isOn: $wifiOnly) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Download on Wi-Fi only").font(.headline).foregroundStyle(Palette.ink)
                            Text("Avoid using mobile data for lesson downloads.")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                    .tint(Palette.accent).padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 23))
                    .disabled(media.isDownloading)
                    .accessibilityIdentifier("offline.wifiOnly")
                    } else {
                        Text("Your Free lessons download automatically over Wi-Fi or mobile data. You can pause at any time.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    if premium.isPremium && media.isDownloading && media.activePreviewOnly {
                        Text("Your Free lessons are downloading. Pause to switch to the complete collection.")
                            .font(.footnote).foregroundStyle(Palette.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("No download is required to begin", systemImage: "sparkles")
                            .font(.headline).foregroundStyle(Palette.accent)
                        Text(premium.isPremium ? "Starter lessons are included. Other images and recordings load as you reach them and are cached locally." : "Starter media is included. The free offline download saves only A-set images and recordings, including A lessons not bundled with the app.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        Text("Saved while studying: \(ByteCountFormatter.lessonMedia.string(fromByteCount: displayStatus.cachedBytes)). Temporary files may be cleared by iOS when storage is low. Use the offline download to keep your available lessons saved.")
                            .font(.caption).foregroundStyle(Palette.muted)
                        Text("Keep studying while your lessons download. Downloads can continue when you leave the app; iOS manages background timing.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    .padding(18).background(Palette.accentSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 23))

                    if let message = media.message ?? displayStatus.error {
                        Text(message).font(.subheadline).foregroundStyle(displayStatus.isReady ? Palette.accent : Palette.clay)
                            .accessibilityIdentifier("offline.message")
                    }

                    if !media.isDownloading && displayStatus.storageUsedBytes > 0 {
                        Button("Remove offline download", role: .destructive) { confirmRemoval = true }
                            .frame(maxWidth: .infinity).accessibilityIdentifier("offline.remove")
                    }
                }
                .frame(maxWidth: 580).padding(22).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                if !displayStatus.isReady {
                    Button {
                        media.isDownloading ? media.pauseDownload() : media.startOfflineDownload(wifiOnly: premium.isPremium ? wifiOnly : false)
                    } label: {
                        Label(media.isDownloading ? "Pause download" : hasOfflineProgress ? "Continue download" : premium.isPremium ? "Download complete collection" : "Download free A set",
                              systemImage: media.isDownloading ? "pause.fill" : "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledActionStyle()).padding(16).background(Palette.background)
                    .disabled(displayStatus.loading || displayStatus.totalBytes == 0)
                    .accessibilityIdentifier(media.isDownloading ? "offline.pause" : "offline.download")
                }
            }
            .navigationTitle("Offline study").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await media.setPremium(premium.isPremium) }
            .onChange(of: premium.isPremium) { _, value in Task { await media.setPremium(value) } }
            .confirmationDialog("Remove downloaded lessons?", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("Remove downloads", role: .destructive) { Task { await media.removeDownloads() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your learning progress and personal artwork will be kept. Images and audio can load online again when needed.")
            }
        }
    }

    private var displayStatus: LessonMediaStatus {
        if media.isDownloading && media.activePreviewOnly == !premium.isPremium && !media.activeStatus.loading {
            return media.activeStatus
        }
        return media.status
    }

    private var progressDescription: String {
        if displayStatus.isReady { return premium.isPremium ? "Complete collection saved" : "Free A set saved" }
        if displayStatus.partialBytes > 0 || displayStatus.downloadedBytes > 0 {
            return "\(ByteCountFormatter.lessonMedia.string(fromByteCount: displayStatus.remainingBytes)) remaining"
        }
        return "\(ByteCountFormatter.lessonMedia.string(fromByteCount: displayStatus.bundledBytes)) included with the app"
    }

    private var hasOfflineProgress: Bool {
        displayStatus.partialBytes > 0 || displayStatus.downloadedBytes > 0
    }
}

struct OfflineStudyRow: View {
    @Environment(LessonMedia.self) private var media
    @Environment(PremiumStore.self) private var premium
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: media.status.isReady ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.title3).frame(width: 44, height: 44).background(Palette.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download for offline study").font(.headline)
                    Text(media.isDownloading ? "Saving \(media.activePreviewOnly ? "Free lessons" : "all lessons") · \(Int(media.activeStatus.progress * 100))%" : media.status.isReady ? "Your lessons are ready offline" : premium.isPremium ? "All 3,000 lessons · uses device storage" : "211 free A-set lessons · uses device storage")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Palette.accent).padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 23))
        }
        .buttonStyle(.plain).accessibilityIdentifier("settings.offlineStudy")
    }
}

struct PremiumOfflineDownloadPrompt: View {
    @Environment(LessonMedia.self) private var media

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 44)).foregroundStyle(Palette.accent)
                Text("Learn anywhere, even offline")
                    .font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Palette.ink)
                Text("Save images and audio for all 3,000 lessons. You can keep studying while they download.")
                    .foregroundStyle(Palette.muted)
                Text("About \(ByteCountFormatter.lessonMedia.string(fromByteCount: media.status.remainingBytes)) to download · uses device storage")
                    .font(.footnote).foregroundStyle(Palette.muted).accessibilityIdentifier("offlinePrompt.size")
                Button { media.choosePremiumDownload(wifiOnly: true) } label: {
                    Label("Download on Wi-Fi", systemImage: "wifi").frame(maxWidth: .infinity)
                }.buttonStyle(FilledActionStyle()).accessibilityIdentifier("offlinePrompt.wifi")
                Button { media.choosePremiumDownload(wifiOnly: false) } label: {
                    Text("Download now").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 48)
                }.foregroundStyle(Palette.accent).background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("offlinePrompt.now")
                Text("Download now uses your current connection, including mobile data.")
                    .font(.caption).foregroundStyle(Palette.muted)
                Button("Later") { media.choosePremiumDownload(wifiOnly: nil) }
                    .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(Palette.accent)
                    .accessibilityIdentifier("offlinePrompt.later")
                Text("You can manage downloads anytime in Settings.").font(.footnote).foregroundStyle(Palette.muted)
            }.padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }.background(Palette.background).presentationDetents([.large])
            .accessibilityIdentifier("offlinePrompt")
    }
}

struct DownloadStudyNotice: View {
    @Environment(LessonMedia.self) private var media
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle")
                Text("Saving \(media.activePreviewOnly ? "Free lessons" : "all lessons") · keep studying")
                    .font(.caption).lineLimit(2)
                Spacer(minLength: 0)
                Text("\(Int(media.activeStatus.progress * 100))%").font(.caption.monospacedDigit())
                Image(systemName: "chevron.right").font(.caption2)
            }.foregroundStyle(Palette.accent).padding(.horizontal, 12).frame(minHeight: 44)
                .background(Palette.accentSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).accessibilityIdentifier("study.downloadProgress")
    }
}
