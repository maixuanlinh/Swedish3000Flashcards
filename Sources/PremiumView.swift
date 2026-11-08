import SwiftUI

struct PremiumView: View {
    @Environment(LessonMedia.self) private var media
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumStore.self) private var premium
    @Environment(StudyStore.self) private var store
    var preview: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if premium.isPersonal {
                        Label("Personal build · All lessons included", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                            .padding(12).background(Palette.accentSoft, in: Capsule())
                            .accessibilityIdentifier("premium.personalMode")
                    } else if premium.isLocalTesting {
                        Label("Local purchase test · No real charge", systemImage: "testtube.2")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.accent)
                            .padding(12).background(Palette.accentSoft, in: Capsule())
                            .accessibilityIdentifier("premium.testMode")
                    }
                    Text(premium.isPremium ? "Your complete Swedish collection" : "Remember Swedish with the full picture")
                        .font(.system(size: 31, weight: .medium, design: .serif)).foregroundStyle(Palette.ink)
                    Text(premium.isPersonal ? "All 3,000 complete lessons are available for your personal practice. No purchase is needed in this build." : "One purchase. All 3,000 complete lessons. No subscription or ads.")
                        .foregroundStyle(Palette.muted)
                    if let word = store.words.first(where: { $0.english == "apple" }) {
                        WordArtworkImage(word: word).frame(maxWidth: .infinity).frame(height: 210)
                            .background(.white, in: RoundedRectangle(cornerRadius: 22))
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    feature("photo.on.rectangle.angled", "A memory cue for every word", "All 3,000 illustrations and English–Swedish memory links.")
                    feature("text.bubble", "Examples you understand", "Every Swedish example, English translation, and sentence pronunciation.")
                    feature("play.rectangle", "Study without tapping", "Automatic playback for any letter or word selection.")
                    feature("bell.badge", "Words throughout your day", "Premium reminders every 30 minutes, hourly or on your own schedule, with sleep hours.")
                    feature("arrow.down.circle", "Your full collection, offline", "Save images and recordings for all 3,000 lessons.")
                    Text("The 211-word A set includes complete lessons and offline downloads for free. Basic cards and word pronunciation stay free across all 3,000 words. Word reminders and the full offline collection require Premium.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text(premium.isPersonal ? "Personal access belongs to this installed build. Your learning progress stays on this device." : "Restore on iPhone or iPad using the same purchasing Apple Account. Android purchases are separate. Learning progress stays on this device and isn’t restored with the purchase.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    HStack(spacing: 24) {
                        Link("Privacy policy", destination: AppSupport.privacyURL)
                            .accessibilityIdentifier("premium.privacy")
                        Link("Support", destination: AppSupport.emailURL)
                            .accessibilityIdentifier("premium.support")
                    }.font(.footnote)
                    if let preview, !premium.isPremium {
                        Button("Study the free A set") { dismiss(); preview() }
                            .accessibilityIdentifier("premium.preview")
                    }
                }.padding(24).frame(maxWidth: 550).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if premium.isPremium {
                        Label(premium.isPersonal ? "Personal access · All lessons unlocked" : "Premium unlocked", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(Palette.accent)
                            .accessibilityIdentifier("premium.unlocked")
                    } else if let offer = premium.offer {
                        Button { Task { await premium.purchase() } } label: {
                            HStack {
                                if premium.busy { ProgressView().tint(.white) }
                                Text("Unlock Premium · \(offer.price)")
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(FilledActionStyle()).disabled(premium.busy || premium.loadingPrice)
                            .accessibilityIdentifier("premium.buy")
                        Text("One-time purchase").font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        Button { Task { await premium.loadOffer() } } label: {
                            Text(premium.loadingPrice ? "Checking price…" : "Try loading price again").frame(maxWidth: .infinity)
                        }.buttonStyle(FilledActionStyle()).disabled(premium.loadingPrice || premium.busy)
                            .accessibilityIdentifier("premium.price")
                    }
                    if !premium.isPersonal {
                        Button("Restore Purchases") { Task { await premium.restore() } }
                            .font(.subheadline.weight(.medium)).disabled(premium.busy)
                            .accessibilityIdentifier("premium.restore")
                    }
                    if let message = premium.message {
                        Text(message).font(.caption).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center).accessibilityIdentifier("premium.message")
                    }
                }.padding(16).frame(maxWidth: .infinity).background(Palette.background)
            }
            .navigationTitle("3000 Swedish Words Premium").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.accessibilityIdentifier("premium.done")
            } }
            .task { if !premium.isPremium { await premium.loadOffer() } }
            .onAppear { media.premiumOfferAppeared() }
            .onDisappear { media.premiumOfferDisappeared() }
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 30).foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }
}

struct LockedLessonView: View {
    var compact = false
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(spacing: compact ? 10 : 16) {
                Image(systemName: "lock.fill").font(.system(size: compact ? 24 : 32))
                Text("Unlock the complete lesson").font(.headline)
                Text("Illustration, memory cue, example and sentence audio")
                    .font(.subheadline).multilineTextAlignment(.center)
                Text("Explore Premium").font(.subheadline.weight(.semibold))
            }.foregroundStyle(Palette.accent).padding(compact ? 16 : 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.accentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain).accessibilityIdentifier("lesson.locked")
    }
}

struct PremiumLock: View {
    var body: some View {
        Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
            .padding(4).foregroundStyle(Palette.accent).background(Palette.accentSoft, in: Circle())
            .accessibilityLabel("Premium feature")
    }
}
