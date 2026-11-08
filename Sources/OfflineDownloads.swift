import Foundation

struct OfflineTransfer: Codable, Sendable {
    let id: String
    let previewKey: String?
    let packFile: String
    let url: URL
    let start: Int64
    let end: Int64
    let packBytes: Int64
    let unitBytes: Int64
    var bytes: Int64 { end - start + 1 }

    func request(wifiOnly: Bool) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        request.allowsCellularAccess = !wifiOnly
        request.networkServiceType = .background
        return request
    }
}

struct OfflineDownloadPlan: Codable, Equatable, Sendable {
    var id = UUID()
    let version: String
    let previewOnly: Bool
    let wifiOnly: Bool
    var paused = false
}

struct OfflineDownloadSnapshot: Sendable {
    var plan: OfflineDownloadPlan?
    var status = LessonMediaStatus()
    var downloading = false
    var message: String?
}

private struct OfflineTaskDescription: Codable, Sendable {
    let planID: UUID
    let transfer: OfflineTransfer
}

private enum OfflineSessionEvent: @unchecked Sendable {
    case file(OfflineTaskDescription, URL, URLResponse?)
    case progress(OfflineTaskDescription, Int64)
    case completed(OfflineTaskDescription, String?)
    case waiting(OfflineTaskDescription)
    case drained
}

private final class OfflineSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let events = AsyncStream<OfflineSessionEvent>.makeStream()
    private let incoming: URL
    init(incoming: URL) { self.incoming = incoming }

    private func description(_ task: URLSessionTask) -> OfflineTaskDescription? {
        task.taskDescription.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(OfflineTaskDescription.self, from: $0) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let description = description(downloadTask) else { return }
        do {
            try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)
            let saved = incoming.appending(path: UUID().uuidString)
            // URLSession deletes its temporary file when this callback returns.
            try FileManager.default.moveItem(at: location, to: saved)
            events.continuation.yield(.file(description, saved, downloadTask.response))
        } catch { events.continuation.yield(.completed(description, error.localizedDescription)) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let description = description(downloadTask) {
            events.continuation.yield(.progress(description, totalBytesWritten))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let description = description(task) else { return }
        // Explicitly cancelled tasks belong to an old plan and are ignored by its ID.
        events.continuation.yield(.completed(description, error?.localizedDescription))
    }

    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        if let description = description(task) { events.continuation.yield(.waiting(description)) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        events.continuation.yield(.drained)
    }
}

@MainActor
final class OfflineBackgroundCompletion {
    static let shared = OfflineBackgroundCompletion()
    private var handlers: [String: () -> Void] = [:]
    func register(_ identifier: String, completion: @escaping () -> Void) { handlers[identifier] = completion }
    func finish(_ identifier: String) { handlers.removeValue(forKey: identifier)?() }
}

actor OfflineDownloadManager {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "com.linapps.swedish3000") + ".offline-media.v1" }
    private let repository: LessonMediaRepository
    private let stateURL: URL
    private let delegate: OfflineSessionDelegate
    private let configuration: URLSessionConfiguration
    private var worker: Task<Void, Never>?
    private var listeners: [UUID: AsyncStream<OfflineDownloadSnapshot>.Continuation] = [:]
    private var snapshot = OfflineDownloadSnapshot()
    private var progress: [String: Int64] = [:]
    private var accepted = Set<String>()
    private var lastPublish = Date.distantPast
    private var preparing = false
    private var buffered: [OfflineSessionEvent] = []
    private var commandID = UUID()
    private var authorizedPremium = false
    private lazy var session: URLSession = {
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }()

    init(repository: LessonMediaRepository, root: URL, configuration: URLSessionConfiguration? = nil) {
        self.repository = repository
        stateURL = root.appending(path: "plan.json")
        delegate = OfflineSessionDelegate(incoming: root.appending(path: "Incoming"))
        let config = configuration ?? URLSessionConfiguration.background(withIdentifier: Self.identifier)
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForResource = 7 * 24 * 3600
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.configuration = config
        if let data = try? Data(contentsOf: stateURL), let plan = try? JSONDecoder().decode(OfflineDownloadPlan.self, from: data) {
            snapshot.plan = plan
        }
    }

    func updates() -> AsyncStream<OfflineDownloadSnapshot> {
        startEvents()
        let id = UUID()
        return AsyncStream { continuation in
            listeners[id] = continuation; continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in Task { await self?.removeListener(id) } }
        }
    }

    private func removeListener(_ id: UUID) { listeners.removeValue(forKey: id) }

    func startEvents() {
        guard worker == nil else { return }
        let events = delegate.events.stream
        _ = session
        worker = Task { [weak self] in
            for await event in events { await self?.receive(event) }
        }
    }

    private func tasks() async -> [URLSessionTask] {
        await withCheckedContinuation { continuation in session.getAllTasks { continuation.resume(returning: $0) } }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let plan = snapshot.plan { try JSONEncoder().encode(plan).write(to: stateURL, options: .atomic) }
        else { try? FileManager.default.removeItem(at: stateURL) }
        var root = stateURL.deletingLastPathComponent()
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? root.setResourceValues(values)
    }

    private func publish(force: Bool = true) {
        if !force && Date.now.timeIntervalSince(lastPublish) < 0.4 { return }
        lastPublish = .now
        var value = snapshot
        value.status.partialBytes += progress.values.reduce(0, +)
        for listener in listeners.values { listener.yield(value) }
    }

    func currentSnapshot() -> OfflineDownloadSnapshot {
        var value = snapshot
        value.status.partialBytes += progress.values.reduce(0, +)
        return value
    }

    func restore(premium: Bool) async {
        authorizedPremium = premium
        startEvents()
        guard let plan = snapshot.plan else { return }
        if !plan.previewOnly && !premium { await cancel(); return }
        guard plan.version == repository.catalog.version else { await cancel(); return }
        if plan.paused {
            snapshot.downloading = false
            snapshot.status = await repository.status(previewOnly: plan.previewOnly)
            publish(); return
        }
        await enqueueMissing()
    }

    func begin(previewOnly: Bool, wifiOnly: Bool) async {
        guard previewOnly || authorizedPremium else { return }
        if let plan = snapshot.plan, plan.version == repository.catalog.version,
           plan.previewOnly == previewOnly, plan.wifiOnly == wifiOnly {
            snapshot.plan?.paused = false
            do { try persist(); await enqueueMissing() }
            catch { snapshot.message = error.localizedDescription; publish() }
            return
        }
        commandID = UUID()
        let command = commandID
        await clearPlan()
        guard commandID == command, previewOnly || authorizedPremium else { return }
        snapshot.plan = OfflineDownloadPlan(version: repository.catalog.version, previewOnly: previewOnly, wifiOnly: wifiOnly)
        snapshot.message = nil
        do { try persist(); await enqueueMissing() }
        catch { snapshot.message = error.localizedDescription; snapshot.downloading = false; publish() }
    }

    private func enqueueMissing() async {
        guard !preparing, let plan = snapshot.plan, !plan.paused else { return }
        preparing = true
        do {
            snapshot.status = await repository.status(previewOnly: plan.previewOnly)
            let capacity = await repository.availableCapacity()
            if capacity > 0 && capacity < snapshot.status.remainingBytes + 50_000_000 { throw LessonMediaError.insufficientStorage }
            let transfers = try await repository.offlineTransfers(previewOnly: plan.previewOnly)
            let existing = await tasks()
            snapshot.status = await repository.status(previewOnly: plan.previewOnly)
            guard snapshot.plan?.id == plan.id, snapshot.plan?.paused == false else {
                preparing = false
                await drainBufferedEvents()
                return
            }
            let queued = Set(existing.compactMap { task -> String? in
                guard let value = task.taskDescription?.data(using: .utf8),
                      let info = try? JSONDecoder().decode(OfflineTaskDescription.self, from: value), info.planID == plan.id else { return nil }
                if task.state == .suspended { task.resume() }
                return info.transfer.id
            })
            for transfer in transfers where !queued.contains(transfer.id) && !accepted.contains(transfer.id) {
                let task = session.downloadTask(with: transfer.request(wifiOnly: plan.wifiOnly))
                task.taskDescription = String(decoding: try JSONEncoder().encode(OfflineTaskDescription(planID: plan.id, transfer: transfer)), as: UTF8.self)
                task.priority = URLSessionTask.lowPriority
                task.resume()
            }
            snapshot.downloading = !snapshot.status.isReady
            snapshot.message = snapshot.status.isReady ? "Your lessons are ready offline." : nil
            publish()
        } catch {
            if snapshot.plan?.id == plan.id {
                snapshot.downloading = false; snapshot.message = error.localizedDescription; publish()
            }
        }
        preparing = false
        await drainBufferedEvents()
    }

    private func drainBufferedEvents() async {
        let events = buffered; buffered.removeAll()
        for event in events { await receive(event) }
    }

    func pause() async {
        guard snapshot.plan != nil else { return }
        snapshot.plan?.paused = true; snapshot.downloading = false
        do { try persist() } catch { snapshot.message = error.localizedDescription }
        publish()
        for task in await tasks() { task.suspend() }
    }

    func cancel() async {
        commandID = UUID()
        await clearPlan()
    }

    private func clearPlan() async {
        snapshot.plan = nil; snapshot.downloading = false
        progress.removeAll(); accepted.removeAll()
        try? persist()
        for task in await tasks() { task.cancel() }
        publish()
    }

    private func receive(_ event: OfflineSessionEvent) async {
        if preparing { buffered.append(event); return }
        switch event {
        case let .waiting(info):
            guard snapshot.plan?.id == info.planID else { return }
            snapshot.message = snapshot.plan?.wifiOnly == true ? "Waiting for Wi-Fi. You can keep studying." : "Waiting for a connection. You can keep studying."
            publish()
        case .drained:
            // The serial event stream drains only after verified files have been saved.
            await OfflineBackgroundCompletion.shared.finish(Self.identifier)
        case let .progress(info, bytes):
            guard snapshot.plan?.id == info.planID, !accepted.contains(info.transfer.id) else { return }
            progress[info.transfer.id] = min(bytes, info.transfer.bytes)
            if snapshot.message?.hasPrefix("Waiting for") == true { snapshot.message = nil }
            publish(force: false)
        case let .file(info, file, response):
            defer { try? FileManager.default.removeItem(at: file) }
            guard snapshot.plan?.id == info.planID, !accepted.contains(info.transfer.id) else { return }
            accepted.insert(info.transfer.id)
            do {
                try await repository.acceptOfflineTransfer(info.transfer, file: file, response: response,
                                                           previewOnly: snapshot.plan?.previewOnly ?? true)
                guard snapshot.plan?.id == info.planID else { return }
                progress.removeValue(forKey: info.transfer.id)
                snapshot.status.downloadedBytes += info.transfer.unitBytes
                if info.transfer.previewKey == nil { snapshot.status.partialBytes -= info.transfer.start }
                snapshot.status.readyPacks += 1
                if snapshot.status.isReady {
                    snapshot.downloading = false; snapshot.message = "Your lessons are ready offline."
                }
                publish(force: snapshot.status.isReady)
            } catch {
                accepted.remove(info.transfer.id); progress.removeValue(forKey: info.transfer.id)
                snapshot.message = error.localizedDescription
                await pause()
            }
        case let .completed(info, error):
            guard snapshot.plan?.id == info.planID, let error else { return }
            snapshot.message = error
            // Keep completed files; explicitly continuing will queue only missing files.
            await pause()
        }
    }
}
