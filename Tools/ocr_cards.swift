import Foundation
import Vision

// Fresh OCR evidence; this does not certify grammar or semantic accuracy.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let limit = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 3000
let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Content/catalog.json"))) as! [String: Any]
let entries = catalog["entries"] as! [[String: Any]]
let selectedIDs = CommandLine.arguments.count > 4 ? Set(CommandLine.arguments[4].split(separator: ",").map(String.init)) : Set<String>()
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Resources/BundledArtwork/manifest.json"))) as! [[String: Any]]
let filenames = Dictionary(uniqueKeysWithValues: manifest.map { ($0["wordID"] as! String, $0["filename"] as! String) })
let lock = NSLock()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
if !FileManager.default.fileExists(atPath: output.path) { FileManager.default.createFile(atPath: output.path, contents: nil) }
let prior = (try? String(contentsOf: output, encoding: .utf8)) ?? ""
let done = Set(prior.split(separator: "\n").compactMap { line -> String? in
    guard let data = line.data(using: .utf8), let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return row["error"] == nil ? row["id"] as? String : nil
})
let handle = try FileHandle(forWritingTo: output)
try handle.seekToEnd()
let queue = OperationQueue()
queue.maxConcurrentOperationCount = 2
var completed = done.count
for entry in entries.prefix(limit) where !done.contains(entry["id"] as! String) && (selectedIDs.isEmpty || selectedIDs.contains(entry["id"] as! String)) {
    queue.addOperation {
        autoreleasepool {
            let id = entry["id"] as! String
            let url = root.appendingPathComponent("Resources/BundledArtwork/\(filenames[id]!)")
            var row: [String: Any] = ["id": id]
            do {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesCPUOnly = true
                request.recognitionLanguages = ["sv-SE", "en-US"]
                request.usesLanguageCorrection = false
                request.minimumTextHeight = 0.007
                try VNImageRequestHandler(url: url).perform([request])
                row["observations"] = (request.results ?? []).compactMap { result -> [String: Any]? in
                    guard let text = result.topCandidates(1).first else { return nil }
                    let box = result.boundingBox
                    return ["text": text.string, "confidence": text.confidence, "x": box.minX, "y": box.minY, "width": box.width, "height": box.height]
                }
            } catch { row["error"] = String(describing: error) }
            lock.lock()
            defer { lock.unlock() }
            do {
                let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: Data([10]))
                completed += 1
                if completed % 50 == 0 { print("OCR \(completed)/\(limit)"); fflush(stdout) }
            } catch { print("WRITE ERROR: \(id): \(error)"); fflush(stdout) }
        }
    }
}
queue.waitUntilAllOperationsAreFinished()
try handle.close()
print("OCR complete: \(completed) records. Language and scene review still required.")
