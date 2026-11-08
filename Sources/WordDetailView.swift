import SwiftUI
import AVFoundation

struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    let word: VocabularyWord
    @State private var imageOpen = false
    @State private var showingPremium = false
    @State private var speech: SpeechPlayer?
    @AppStorage("speechRate") private var speechRate = 0.42
    @State private var error: String?
    @State private var artworkEditorOpen = false
    @State private var displayedArtwork: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        StatusBadge(status: word.status)
                    }
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(word.swedish)
                                .font(.system(size: 39, weight: .medium, design: .serif))
                                .foregroundStyle(Palette.ink)
                                .accessibilityIdentifier("detail.swedish")
                            Text(word.english).font(.title3).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button { play(word.swedish) } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .frame(width: 48, height: 48)
                                .background(Palette.accentSoft, in: Circle())
                        }
                        .accessibilityLabel("Play Swedish word").accessibilityIdentifier("detail.playWord")
                    }

                    if !premium.hasLesson(word) {
                        LockedLessonView(open: { showingPremium = true }).frame(minHeight: 220)
                    } else if store.hasArtwork(for: word) {
                        VStack(spacing: 4) {
                            WordArtworkImage(word: word, onLoad: { displayedArtwork = $0 })
                                .frame(maxWidth: .infinity).frame(height: 340)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .accessibilityIdentifier("detail.artworkImage")
                            Button { if displayedArtwork != nil { imageOpen = true } } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 48, height: 44)
                                    .background(Palette.accentSoft, in: Capsule())
                            }
                            .buttonStyle(.plain).accessibilityLabel("Open full-screen illustration")
                            .accessibilityIdentifier("detail.image")
                            .disabled(displayedArtwork == nil)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    let memoryHook = store.artworkMemoryHook(for: word)
                    if premium.hasLesson(word), !memoryHook.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Memory hook")
                            Text(memoryHook).foregroundStyle(Palette.ink)
                                .accessibilityIdentifier("detail.memoryHook")
                        }
                    }

                    if premium.hasLesson(word), !word.sentence.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Eyebrow(text: "In a sentence")
                                Spacer()
                                Button { play(word.sentence) } label: {
                                    Image(systemName: "speaker.wave.2").frame(width: 30, height: 25)
                                }.accessibilityLabel("Play Swedish sentence").accessibilityIdentifier("detail.playSentence")
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(word.sentence)
                                    .font(.system(size: 25, weight: .medium, design: .serif))
                                    .foregroundStyle(Palette.ink)
                                    .accessibilityIdentifier("detail.sentence")
                                if !word.sentenceEnglish.isEmpty {
                                    Text(word.sentenceEnglish).font(.subheadline).foregroundStyle(Palette.muted)
                                        .accessibilityIdentifier("detail.translation")
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Your learning")
                        HStack(spacing: 10) {
                            ForEach(LearningStatus.allCases) { status in
                                Button {
                                    do { try store.rate(word, as: status) }
                                    catch { self.error = error.localizedDescription }
                                } label: {
                                    Text(status.title).font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                                        .foregroundStyle(word.status == status ? .white : Palette.accent)
                                        .background(word.status == status ? Palette.accent : Palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .accessibilityIdentifier("detail.status.\(status.rawValue)")
                            }
                        }
                    }
                }
                .frame(maxWidth: 600).padding(24).frame(maxWidth: .infinity)
            }
            .onDisappear { speech?.stop() }
            .background(Palette.background)
            .navigationTitle("Word detail").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if premium.hasLesson(word) { artworkEditorOpen = true } else { showingPremium = true }
                    } label: { Label("Artwork", systemImage: premium.hasLesson(word) ? "photo.badge.plus" : "lock.fill") }
                        .accessibilityIdentifier("detail.artwork")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("detail.done") }
            }
            .sheet(isPresented: $showingPremium) { PremiumView() }
            .onChange(of: premium.isPremium) { _, owns in
                if !owns { imageOpen = false; artworkEditorOpen = false; speech?.stop() }
            }
            .sheet(isPresented: $artworkEditorOpen) { ArtworkEditor(word: word) }
            .fullScreenCover(isPresented: $imageOpen) {
                if premium.hasLesson(word), let image = displayedArtwork { IllustrationViewer(image: image, word: word.swedish) }
            }
            .alert("Couldn’t complete that action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "Please try again.") }
        }
    }

    private func play(_ text: String) {
        if speech == nil { speech = SpeechPlayer() }
        guard let speech else { return }
        Task {
            do { try await speech.speakAndWait(text, language: "sv-SE", rate: Float(speechRate)) }
            catch is CancellationError {}
            catch { self.error = error.localizedDescription }
        }
    }
}

struct IllustrationViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let word: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoomableImage(image: image)
                    .accessibilityLabel("Illustration for \(word). Pinch or double-tap to zoom.")
            }
            .background(Palette.background)
            .navigationTitle(word).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("illustration.done")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("illustration.viewer")
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ImageScrollView {
        let scroll = ImageScrollView()
        scroll.imageView.image = image
        return scroll
    }
    func updateUIView(_ uiView: ImageScrollView, context: Context) {}
}

private final class ImageScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()
    private var previousSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != previousSize {
            setZoomScale(1, animated: false)
            imageView.frame = CGRect(origin: .zero, size: bounds.size)
            contentSize = bounds.size
            previousSize = bounds.size
        }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    @objc private func doubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > 1.05 { setZoomScale(1, animated: true) }
        else {
            let point = recognizer.location(in: imageView)
            let width = bounds.width / 2.5
            let height = bounds.height / 2.5
            zoom(to: CGRect(x: point.x-width/2, y: point.y-height/2, width: width, height: height), animated: true)
        }
    }
}
