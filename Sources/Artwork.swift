import SwiftUI
import SwiftData
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

@Model
final class ArtworkPrompt {
    @Attribute(.unique) var id: UUID
    var wordID: String
    var text: String
    var memoryHook: String
    var createdAt: Date
    init(wordID: String, text: String, memoryHook: String) {
        id = UUID(); self.wordID = wordID; self.text = text
        self.memoryHook = memoryHook; createdAt = .now
    }
}

@Model
final class ArtworkRevision {
    @Attribute(.unique) var id: UUID
    var wordID: String
    var promptText: String
    var memoryHook: String
    var filename: String
    var thumbnailFilename: String
    var byteCount: Int
    var width: Int
    var height: Int
    var source: String
    var createdAt: Date
    var isActive: Bool
    init(id: UUID, wordID: String, promptText: String, memoryHook: String,
         filename: String, thumbnailFilename: String, byteCount: Int, width: Int, height: Int, source: String) {
        self.id = id; self.wordID = wordID; self.promptText = promptText; self.memoryHook = memoryHook
        self.filename = filename; self.thumbnailFilename = thumbnailFilename
        self.byteCount = byteCount; self.width = width; self.height = height
        self.source = source; createdAt = .now; isActive = true
    }
}

enum ArtworkError: LocalizedError {
    case invalidImage, tooLarge, unableToSave
    var errorDescription: String? {
        switch self {
        case .invalidImage: "This file couldn’t be read as a supported image. Try a JPEG, PNG or HEIC image."
        case .tooLarge: "Choose an image smaller than 30 MB."
        case .unableToSave: "The image couldn’t be saved. Please try again."
        }
    }
}

struct PreparedArtwork: Sendable {
    let full: Data
    let thumbnail: Data
    let width: Int
    let height: Int
}

enum ArtworkFiles {
    static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func prepare(_ data: Data) throws -> PreparedArtwork {
        guard data.count <= 30 * 1024 * 1024 else { throw ArtworkError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw ArtworkError.invalidImage }
        let fullImage = try thumbnail(source, maximum: 768)
        var full = try jpeg(fullImage, quality: 0.82)
        for quality in [0.72, 0.62, 0.52] where full.count > 160_000 {
            full = try jpeg(fullImage, quality: quality)
        }
        let thumb = try jpeg(thumbnail(source, maximum: 160), quality: 0.68)
        return PreparedArtwork(full: full, thumbnail: thumb, width: fullImage.width, height: fullImage.height)
    }

    private static func thumbnail(_ source: CGImageSource, maximum: Int) throws -> CGImage {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                      kCGImageSourceThumbnailMaxPixelSize: maximum]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ArtworkError.invalidImage
        }
        // Flatten transparency onto white for predictable compact JPEG output.
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw ArtworkError.invalidImage }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let flattened = context.makeImage() else { throw ArtworkError.invalidImage }
        return flattened
    }

    private static func jpeg(_ image: CGImage, quality: Double) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ArtworkError.unableToSave
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ArtworkError.unableToSave }
        return data as Data
    }

    static func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }
}

enum BundledArtwork {
    struct Record: Decodable {
        let wordID: String
        let assetID: String
        let filename: String
        let thumbnailFilename: String
        let memoryHook: String
        let prompt: String
    }

    static let records: [String: Record] = {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "BundledArtwork"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Record].self, from: data),
              Set(records.map(\.wordID)).count == records.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.wordID, $0) })
    }()

    private static let directory = Bundle.main.resourceURL?.appending(path: "BundledArtwork", directoryHint: .isDirectory)

    static func preload() { _ = records }

    static func url(for wordID: String, thumbnail: Bool = false) -> URL? {
        guard let record = records[wordID] else { return nil }
        return directory?.appending(path: thumbnail ? record.thumbnailFilename : record.filename)
    }

    static func image(for wordID: String, thumbnail: Bool = false) -> UIImage? {
        url(for: wordID, thumbnail: thumbnail).flatMap { ArtworkFiles.image(at: $0) }
    }
}

enum ArtworkPromptBuilder {
    private struct Brief: Decodable { let prompt: String; let memoryHook: String }
    private static let curated: [String: Brief] = {
        guard let url = Bundle.main.url(forResource: "artworkBriefs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let briefs = try? JSONDecoder().decode([String: Brief].self, from: data) else { return [:] }
        return briefs
    }()

    static func preload() { _ = curated }

    static func memoryHook(for word: VocabularyWord) -> String { curated[word.id]?.memoryHook ?? "" }

    static func make(for word: VocabularyWord) -> String {
        if let brief = curated[word.id] {
            return brief.prompt + "\nWord ID (metadata): \(word.id)\nSource dictionary alternatives (context only; do not print): \(word.swedish)\nSwedish example: \(word.sentence)"
        }
        return """
        Create ONE memorable square mnemonic artwork for an adult learning Swedish.

        Word ID: \(word.id)
        English: \(word.english)
        Swedish: \(word.swedish)
        Swedish example: \(word.sentence)
        If the word has several meanings, illustrate the meaning used in this example.

        First propose one short, clear memory hook connecting the Swedish word to its English meaning. Use a real Swedish word-family or compound link if reliable, a loose English sound/spelling association if helpful, or a striking visual metaphor. Do not invent an etymology. English sound hooks are memory aids, not Swedish pronunciation.

        Then generate a vivid, surprising surreal editorial illustration showing that specific hook. Use a few large focal objects, impossible scale or an unexpected interaction, tactile realistic materials and cinematic lighting. Keep it readable as a small thumbnail. Avoid a generic dictionary illustration or decorative clutter.

        Include clearly typeset text INSIDE the image: the exact Swedish word, its English meaning, a short explanation of the memory link, and the Swedish example above. Use arrows, highlighted shared letters, tiny fading letters or real word parts when they make the connection clearer. Keep the normal Swedish spelling correct and label playful English spelling/sound cues as “Memory trick”, not pronunciation. If a word is easy, use a clear example scene with bilingual labels instead of forcing a mnemonic. Keep text concise, high-contrast and legible on a phone; preserve Swedish ä, ö and doubled letters. No logos or watermark. Also explain the memory link separately so I can paste it into the app.
        """
    }
}

enum ArtworkImageSource: Hashable, Sendable {
    case file(URL)
    case asset(String)

    func loadForDisplay() -> UIImage? {
        let image: UIImage?
        switch self {
        case .file(let url): image = ArtworkFiles.image(at: url)
        case .asset(let name): image = UIImage(named: name)
        }
        guard let image else { return nil }
        let prepared = image.preparingForDisplay() ?? image
        if case .file(let url) = self {
            ArtworkFiles.cache.setObject(prepared, forKey: url.path as NSString,
                cost: Int(prepared.size.width * prepared.size.height * 4))
        }
        return prepared
    }
}

struct WordArtworkImage: View {
    @Environment(StudyStore.self) private var store
    @Environment(PremiumStore.self) private var premium
    let word: VocabularyWord
    var thumbnail = false
    @State private var image: UIImage?
    @State private var loadedSources: [ArtworkImageSource] = []

    var body: some View {
        let allowed = premium.hasLesson(word)
        let sources = allowed ? store.artworkSources(for: word, thumbnail: thumbnail) : []
        Group {
            if !allowed {
                Image(systemName: "lock.fill").foregroundStyle(Palette.forest)
            } else if loadedSources == sources, let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(Palette.muted)
            }
        }
        .accessibilityLabel("Word illustration")
        .accessibilityValue(loadedSources == sources && image != nil ? "Ready" : "Loading")
        .task(id: sources) {
            guard !Task.isCancelled else { return }
            guard allowed else { image = nil; loadedSources = []; return }
            guard loadedSources != sources || image == nil else { return }
            let request = Task.detached(priority: .userInitiated) {
                for source in sources {
                    if Task.isCancelled { return UIImage?.none }
                    if let image = source.loadForDisplay() { return Optional(image) }
                }
                return UIImage?.none
            }
            let result = await withTaskCancellationHandler {
                await request.value
            } onCancel: { request.cancel() }
            guard !Task.isCancelled else { return }
            loadedSources = sources
            image = result
        }
    }
}

struct ArtworkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudyStore.self) private var store
    let word: VocabularyWord
    @State private var prompt = ""
    @State private var memoryHook = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pickingFile = false
    @State private var sharing = false
    @State private var shareItems: [Any] = []
    @State private var importing = false
    @State private var message: String?
    @State private var error: String?
    @State private var previewOpen = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                if store.hasArtwork(for: word) {
                    Section {
                        Button { previewOpen = true } label: {
                            WordArtworkImage(word: word).frame(maxWidth: .infinity).frame(height: 190)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Preview artwork")
                        .accessibilityIdentifier("artwork.preview")
                    }
                }
                Section {
                    TextEditor(text: $prompt).frame(height: 190).font(.subheadline)
                        .accessibilityIdentifier("artwork.prompt")
                    Button("Copy prompt", systemImage: "doc.on.doc") { copyPrompt() }
                        .accessibilityIdentifier("artwork.copy")
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Share prompt", systemImage: "square.and.arrow.up") { sharePrompt() }
                        .accessibilityIdentifier("artwork.share")
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Link("Open ChatGPT", destination: URL(string: "https://chatgpt.com/")!)
                } header: { Text("Create in ChatGPT") } footer: {
                    Text("Copy the prompt, generate your image in ChatGPT, then save it to Photos or Files.")
                }
                Section("Add your image") {
                    TextField("Memory hook (optional)", text: $memoryHook, axis: .vertical)
                        .accessibilityIdentifier("artwork.hook")
                    PhotosPicker(selection: $selectedPhoto, matching: .images, preferredItemEncoding: .current) {
                        Label("Choose from Photos", systemImage: "photo")
                    }
                    .accessibilityIdentifier("artwork.photos")
                    Button("Choose from Files", systemImage: "folder") { pickingFile = true }
                        .accessibilityIdentifier("artwork.files")
                    if importing { ProgressView("Saving image…") }
                    if let message { Text(message).font(.caption).foregroundStyle(Palette.forest).accessibilityIdentifier("artwork.message") }
                    if ProcessInfo.processInfo.arguments.contains("-ui-artwork-fixture") {
                        Button("Import test image") {
                            Task {
                                do {
                                    guard let url = Bundle.main.url(forResource: "artwork-test", withExtension: "jpg") else { throw ArtworkError.invalidImage }
                                    await importImage(try Data(contentsOf: url), source: "UI test")
                                } catch { self.error = error.localizedDescription }
                            }
                        }.accessibilityIdentifier("artwork.fixture")
                    }
                }
                if !store.artworkHistory(for: word.id).isEmpty {
                    Section("Image history") {
                        ForEach(store.artworkHistory(for: word.id)) { revision in
                            Button {
                                do {
                                    try store.activateArtwork(revision)
                                    prompt = revision.promptText; memoryHook = revision.memoryHook
                                    message = "Earlier image restored."
                                } catch { self.error = error.localizedDescription }
                            } label: {
                                HStack(spacing: 12) {
                                    if let image = store.artworkImage(revision, thumbnail: true) {
                                        Image(uiImage: image).resizable().scaledToFit().frame(width: 48, height: 48)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(revision.createdAt, format: .dateTime.day().month().hour().minute())
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(revision.byteCount), countStyle: .file))
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    if revision.isActive { Image(systemName: "checkmark.circle.fill") }
                                }
                            }
                            .accessibilityIdentifier("artwork.version.\(revision.id.uuidString)")
                        }
                        Button("Export word artwork", systemImage: "square.and.arrow.up") { exportWord() }
                            .accessibilityIdentifier("artwork.export")
                        Button("Use original card", systemImage: "arrow.uturn.backward") {
                            do { try store.useOriginalArtwork(for: word.id); message = "Original card restored. Images kept in history." }
                            catch { self.error = error.localizedDescription }
                        }
                        .accessibilityIdentifier("artwork.original")
                    }
                }
                let savedPrompts = store.promptHistory(for: word.id)
                if !savedPrompts.isEmpty {
                    Section("Prompt history") {
                        ForEach(savedPrompts) { saved in
                            Button {
                                prompt = saved.text; memoryHook = saved.memoryHook
                                message = "Saved prompt restored."
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(saved.createdAt, format: .dateTime.day().month().hour().minute()).font(.caption)
                                    Text(saved.text).lineLimit(2).font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .disabled(importing)
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("Artwork · \(word.swedish)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("artwork.done") } }
            .onAppear {
                guard !loaded else { return }; loaded = true
                if let saved = store.promptHistory(for: word.id).first {
                    prompt = saved.text; memoryHook = saved.memoryHook
                } else {
                    prompt = ArtworkPromptBuilder.make(for: word)
                    memoryHook = store.activeArtwork(for: word.id)?.memoryHook ?? ArtworkPromptBuilder.memoryHook(for: word)
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo, !importing else { return }
                Task {
                    importing = true
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self) else { throw ArtworkError.invalidImage }
                        await importImage(data, source: "Photos")
                    } catch { importing = false; self.error = error.localizedDescription }
                    selectedPhoto = nil
                }
            }
            .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 30 * 1024 * 1024 else { throw ArtworkError.tooLarge }
                        await importImage(try Data(contentsOf: url, options: .mappedIfSafe), source: "Files")
                    } catch { self.error = error.localizedDescription }
                }
            }
            .sheet(isPresented: $sharing) { ArtworkShareSheet(items: shareItems) }
            .sheet(isPresented: $previewOpen) {
                if let image = store.artworkImage(for: word) { IllustrationViewer(image: image, word: word.swedish) }
            }
            .alert("Couldn’t save artwork", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "Please try again.") }
        }
    }

    private func copyPrompt() {
        do {
            try store.saveArtworkPrompt(for: word.id, text: prompt, memoryHook: memoryHook)
            UIPasteboard.general.string = prompt
            message = "Prompt copied."
        } catch { self.error = error.localizedDescription }
    }
    private func sharePrompt() {
        do {
            try store.saveArtworkPrompt(for: word.id, text: prompt, memoryHook: memoryHook)
            shareItems = [prompt]; sharing = true
        } catch { self.error = error.localizedDescription }
    }
    private func importImage(_ data: Data, source: String) async {
        guard !importing || source == "Photos" else { return }
        importing = true
        defer { importing = false }
        do {
            let revision = try await store.importArtwork(data, for: word, prompt: prompt, memoryHook: memoryHook, source: source)
            message = "Saved locally · \(ByteCountFormatter.string(fromByteCount: Int64(revision.byteCount), countStyle: .file))"
        } catch { self.error = error.localizedDescription }
    }
    private func exportWord() {
        do { shareItems = [try store.exportArtwork(for: word)]; sharing = true }
        catch { self.error = error.localizedDescription }
    }
}

struct ArtworkShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ArtworkPack: Decodable, Sendable {
    struct Record: Decodable, Sendable {
        let assetID: String
        let wordID: String
        let prompt: String
        let memoryHook: String
        let jpegBase64: String
    }
    let format: String
    let records: [Record]

    static func read(_ data: Data) throws -> ArtworkPack {
        guard data.count <= 150 * 1024 * 1024 else { throw PackError.tooLarge }
        let pack = try JSONDecoder().decode(ArtworkPack.self, from: data)
        guard pack.format == "swedish-cards-artwork-pack-v1", !pack.records.isEmpty,
              pack.records.count <= 500,
              Set(pack.records.map(\.wordID)).count == pack.records.count,
              Set(pack.records.map(\.assetID)).count == pack.records.count else { throw PackError.invalid }
        for record in pack.records {
            guard !record.assetID.isEmpty, !record.wordID.isEmpty,
                  let image = Data(base64Encoded: record.jpegBase64), image.count <= 30 * 1024 * 1024,
                  let source = CGImageSourceCreateWithData(image as CFData, nil),
                  CGImageSourceGetCount(source) > 0 else { throw PackError.invalid }
        }
        return pack
    }
    enum PackError: LocalizedError {
        case invalid, tooLarge, unknownWord
        var errorDescription: String? {
            switch self {
            case .invalid: "This file is not a valid 3000 Swedish Words artwork pack."
            case .tooLarge: "Choose an artwork pack smaller than 150 MB."
            case .unknownWord: "This pack contains a word that is not in your vocabulary collection."
            }
        }
    }
}

struct ArtworkPackImporter: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StudyStore.self) private var store
    @State private var picking = false
    @State private var importing = false
    @State private var completed = 0
    @State private var total = 0
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Choose artwork pack", systemImage: "folder.badge.plus") { picking = true }
                        .accessibilityIdentifier("artwork.pack.choose")
                        .disabled(importing)
                } footer: {
                    Text("Choose a 3000 Swedish Words artwork JSON pack from Files. Pictures are stored on this device; your learning progress stays saved. Existing pictures stay in image history.")
                }
                if importing {
                    Section {
                        ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        Text("\(completed) of \(total) words")
                    }
                }
                if let message { Text(message).foregroundStyle(Palette.forest).accessibilityIdentifier("artwork.pack.message") }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("Import artwork").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(importing) } }
            .interactiveDismissDisabled(importing)
            .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
                Task {
                    importing = true; message = nil; completed = 0; total = 0
                    defer { importing = false }
                    do {
                        let url = try result.get()
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 150 * 1024 * 1024 else {
                            throw ArtworkPack.PackError.tooLarge
                        }
                        let data = try Data(contentsOf: url, options: .mappedIfSafe)
                        let counts = try await store.importArtworkPack(data) { done, count in completed = done; total = count }
                        message = "Added \(counts.imported) images. \(counts.skipped) already imported."
                    } catch {
                        self.error = error.localizedDescription + (completed > 0 ? " \(completed) words processed. Saved images are kept; you can retry the pack." : "")
                    }
                }
            }
            .alert("Couldn’t import artwork", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "Please try again.") }
        }
    }
}
