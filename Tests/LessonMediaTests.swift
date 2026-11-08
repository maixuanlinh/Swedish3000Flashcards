import XCTest
import AVFoundation
import UIKit
@testable import SwedishCards

final class LessonMediaTests: XCTestCase {
    func testDownloadDecisionsPersistWithoutRepeatingThePremiumPrompt() throws {
        let name = "OfflinePolicy-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let policy = OfflineDownloadPreferences(defaults: defaults)
        XCTAssertTrue(policy.automaticFreeEnabled)
        XCTAssertFalse(policy.shouldOfferPremium(premium: false, ready: false))
        XCTAssertTrue(policy.shouldOfferPremium(premium: true, ready: false))
        XCTAssertFalse(policy.shouldOfferPremium(premium: true, ready: true))
        policy.premiumPromptHandled = true
        policy.automaticFreeEnabled = false
        let reopened = OfflineDownloadPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: name)))
        XCTAssertFalse(reopened.automaticFreeEnabled)
        XCTAssertFalse(reopened.shouldOfferPremium(premium: true, ready: false))
    }

    func testBackgroundFreePlanContainsOnlyExactAllowedRangesAndAllowsMobileData() async throws {
        let root = URL.temporaryDirectory.appending(path: "OfflinePlan-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try LessonMediaRepository(bundle: .main, baseURL: URL(string: "https://example.invalid/")!, storageRoot: root)
        let transfers = try await repository.offlineTransfers(previewOnly: true)
        let catalog = await repository.catalog
        let free = await repository.previewKeys
        XCTAssertFalse(transfers.isEmpty)
        XCTAssertEqual(Set(transfers.map(\.id)).count, transfers.count)
        for transfer in transfers {
            let key = try XCTUnwrap(transfer.previewKey)
            let item = try XCTUnwrap(catalog.itemByKey[key])
            XCTAssertTrue(free.contains(key))
            XCTAssertEqual(transfer.start, item.offset)
            XCTAssertEqual(transfer.bytes, Int64(item.bytes))
            XCTAssertTrue(transfer.request(wifiOnly: false).allowsCellularAccess)
            XCTAssertFalse(transfer.request(wifiOnly: true).allowsCellularAccess)
            XCTAssertEqual(transfer.request(wifiOnly: false).value(forHTTPHeaderField: "Range"), "bytes=\(transfer.start)-\(transfer.end)")
        }
    }

    func testFreeBackgroundReceiverRejectsAnEntireMixedPack() async throws {
        let root = URL.temporaryDirectory.appending(path: "OfflineReceive-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try LessonMediaRepository(bundle: .main, baseURL: URL(string: "https://example.invalid/")!, storageRoot: root)
        let full = try await repository.offlineTransfers(previewOnly: false)
        let transfer = try XCTUnwrap(full.first)
        let file = root.appending(path: "untrusted-download")
        try Data(count: Int(transfer.bytes)).write(to: file)
        let response = try XCTUnwrap(HTTPURLResponse(url: transfer.url, statusCode: 206, httpVersion: nil,
            headerFields: ["Content-Range": "bytes \(transfer.start)-\(transfer.end)/\(transfer.packBytes)"]))
        do {
            try await repository.acceptOfflineTransfer(transfer, file: file, response: response, previewOnly: true)
            XCTFail("A Free download must never accept a mixed Premium pack")
        } catch LessonMediaError.unavailable { }
        let state = await repository.status()
        XCTAssertEqual(state.downloadedBytes, 0)
    }


    @MainActor
    func testFreeOfflineAssetsCoverOnlyThe211ASetLessons() async throws {
        let root = URL.temporaryDirectory.appending(path: "PreviewAccess-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try LessonMediaRepository(bundle: .main, baseURL: URL(string: "https://example.invalid/")!, storageRoot: root)
        let keys = await repository.previewKeys
        let aIDs = Set(try StudyStore.readSeeds().filter { PremiumAccess.isPreview($0.english) }.map(\.id))
        XCTAssertEqual(aIDs.count, 211)
        let imageKeys = keys.filter { $0.hasPrefix("image/") }
        XCTAssertEqual(imageKeys.count, 211) // Swedish full-size/thumbnail keys share a WebP.
        XCTAssertTrue(imageKeys.allSatisfy { key in aIDs.contains(String(key.dropFirst(6).prefix(7))) })
        let preview = await repository.status(previewOnly: true)
        let full = await repository.status()
        XCTAssertGreaterThan(preview.totalBytes, 0)
        XCTAssertLessThan(preview.totalBytes, full.totalBytes)
        do {
            try await repository.downloadPreviewAsset("image/sv-1454-r001.jpg", allowsCellular: false)
            XCTFail("Paid assets must not be downloaded by the free offline path")
        } catch LessonMediaError.unavailable { }
        let after = await repository.status(previewOnly: true)
        XCTAssertEqual(after.downloadedBytes, preview.downloadedBytes)
    }

    func testRecordingKeyMatchesPublishedManifestConvention() {
        XCTAssertEqual(lessonMediaHash(Data("apple".utf8)),
                       "3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b")
        XCTAssertEqual(lessonRecordingKey(language: "en-US", text: "apple"),
                       "audio/en-US/3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b")
    }

    func testCatalogAcceptsVerifiedPackAndBoundedAsset() throws {
        let hash = String(repeating: "a", count: 64)
        let manifest = LessonMediaManifest(format: "sisu-lesson-media-v1",
            packs: [LessonMediaPack(file: "pack-\(hash).bin", bytes: 10, sha256: hash, starter: true)],
            assets: [LessonMediaItem(key: "image/example.jpg", offset: 2, bytes: 4,
                                           sha256: String(repeating: "b", count: 64), pack: "pack-\(hash).bin")],
            version: String(repeating: "c", count: 64))
        let catalog = try manifest.validated()
        XCTAssertEqual(catalog.packs.count, 1)
        XCTAssertEqual(catalog.itemByKey["image/example.jpg"]?.offset, 2)
    }

    func testCatalogRejectsTraversalAndOutOfBoundsAsset() {
        let hash = String(repeating: "a", count: 64)
        let pack = LessonMediaPack(file: "pack-\(hash).bin", bytes: 10, sha256: hash, starter: false)
        let invalid = LessonMediaManifest(format: "sisu-lesson-media-v1", packs: [pack],
            assets: [LessonMediaItem(key: "../progress.store", offset: 8, bytes: 4,
                                           sha256: String(repeating: "b", count: 64), pack: pack.file)],
            version: String(repeating: "c", count: 64))
        XCTAssertThrowsError(try invalid.validated())
    }

    func testStatusCountsBundledAndDownloadedProgress() {
        let status = LessonMediaStatus(totalBytes: 100, bundledBytes: 20, downloadedBytes: 30,
                                       cachedBytes: 4, partialBytes: 10, readyPacks: 2,
                                       packCount: 4, loading: false)
        XCTAssertEqual(status.remainingBytes, 40)
        XCTAssertEqual(status.storageUsedBytes, 44)
        XCTAssertEqual(status.progress, 0.6, accuracy: 0.0001)
        XCTAssertFalse(status.isReady)
    }

    func testCatalogRejectsDuplicateKeysAndOverflowingOffsets() {
        let hash = String(repeating: "a", count: 64)
        let pack = LessonMediaPack(file: "pack-\(hash).bin", bytes: 10, sha256: hash, starter: false)
        let item = LessonMediaItem(key: "image/example.jpg", offset: 0, bytes: 4, sha256: hash, pack: pack.file)
        XCTAssertThrowsError(try LessonMediaManifest(format: "sisu-lesson-media-v1", packs: [pack, pack],
            assets: [item], version: hash).validated())
        XCTAssertThrowsError(try LessonMediaManifest(format: "sisu-lesson-media-v1", packs: [pack],
            assets: [item, item], version: hash).validated())
        let overflow = LessonMediaItem(key: item.key, offset: Int64.max, bytes: 4, sha256: hash, pack: pack.file)
        XCTAssertThrowsError(try LessonMediaManifest(format: "sisu-lesson-media-v1", packs: [pack],
            assets: [overflow], version: hash).validated())
    }

    @MainActor
    func testEveryCatalogWordAndSentenceHasReadyMadeRecordings() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "lesson-media", withExtension: "json"))
        let catalog = try JSONDecoder().decode(LessonMediaManifest.self, from: Data(contentsOf: url)).validated()
        let seeds = try StudyStore.readSeeds()
        for seed in seeds {
            for (language, text) in [("en-US", seed.english), ("sv-SE", seed.swedish), ("sv-SE", seed.sentence)] where !text.isEmpty {
                XCTAssertNotNil(catalog.itemByKey[lessonRecordingKey(language: language, text: text)], "Missing \(seed.id): \(text)")
            }
        }
    }
}

// Run explicitly when validating a release; this suite uses the live Bluehost service.
final class HostedLessonMediaTests: XCTestCase {
    func testFreeASetAssetDownloadPersistsAndReopensWithoutNetwork() async throws {
        let directory = URL.temporaryDirectory.appending(path: "FreeOffline-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let online = try LessonMediaRepository(bundle: .main, baseURL: URL(string: "https://yki.essaykingapp.com/swedish3000/v1/")!, storageRoot: directory)
        let candidates = await online.previewMissingKeys()
        let key = try XCTUnwrap(candidates.first)
        try await online.downloadPreviewAsset(key, allowsCellular: true)
        let data = try await online.data(for: key)
        XCTAssertFalse(data.isEmpty)
        let offline = try LessonMediaRepository(bundle: .main, baseURL: URL(string: "https://example.invalid/")!, storageRoot: directory)
        let stored = try await offline.data(for: key)
        XCTAssertEqual(stored, data)
        let remaining = await offline.previewMissingKeys()
        XCTAssertFalse(remaining.contains(key))
        let status = await offline.status(previewOnly: true)
        XCTAssertGreaterThan(status.downloadedBytes, 0)
    }

    func testHostedImageAudioCacheAndDurableOfflinePack() async throws {
        let directory = URL.temporaryDirectory.appending(path: "HostedMedia-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = Bundle.main
        let repository = try LessonMediaRepository(bundle: bundle,
            baseURL: URL(string: "https://yki.essaykingapp.com/swedish3000/v1/")!, storageRoot: directory)
        let key = try XCTUnwrap(BundledArtwork.mediaKey(for: "sv-0316"))
        let image = try await repository.data(for: key)
        XCTAssertNotNil(UIImage(data: image))
        let audioKey = lessonRecordingKey(language: "sv-SE", text: "en flaska")
        let audio = try await repository.data(for: audioKey)
        let player = try AVAudioPlayer(data: audio)
        XCTAssertTrue(player.prepareToPlay())
        XCTAssertGreaterThan(player.duration, 0)
        let cachedStatus = await repository.status()
        XCTAssertGreaterThanOrEqual(cachedStatus.cachedBytes, Int64(image.count + audio.count))

        let cachedOnly = try LessonMediaRepository(bundle: bundle,
            baseURL: URL(string: "https://example.invalid/")!, storageRoot: directory)
        let cachedImage = try await cachedOnly.data(for: key)
        XCTAssertEqual(cachedImage, image)

        let catalog = await repository.catalog
        let item = try XCTUnwrap(catalog.itemByKey[key])
        let pack = try XCTUnwrap(catalog.packByFile[item.pack])
        try await repository.download(pack, allowsCellular: true)
        let status = await repository.status()
        XCTAssertEqual(status.downloadedBytes, pack.bytes)
        let offline = try LessonMediaRepository(bundle: bundle,
            baseURL: URL(string: "https://example.invalid/")!, storageRoot: directory)
        let savedImage = try await offline.data(for: key)
        XCTAssertEqual(savedImage, image)
        try await offline.removeDownloadedMedia()
        let removed = await offline.status()
        XCTAssertEqual(removed.downloadedBytes, 0)
        XCTAssertEqual(removed.cachedBytes, 0)
    }
}
