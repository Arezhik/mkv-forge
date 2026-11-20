import Foundation
@testable import MKVForgeCore

/// One scripted mkvmerge run.
struct FakeRun: Sendable {
    var status: Int32 = 0
    var output = ""
    /// Write the temp file (the `-o` path) before returning.
    var writesTemp = true
    /// Create the real output file while "running", as another app might.
    var createsOutput = false
    /// Throw instead of running.
    var throwing: ToolFailure?
    /// Call Cancel (requestStop) while this file runs.
    var requestsStop = false
    /// Cancel the running task while this file runs (a hard stop).
    var cancelsTask = false
}

/// Plays scripted runs, keyed by the job's base name, and records every argument list.
final class FakeMKVMerge: MKVMergeRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var runs: [String: FakeRun]
    private var recorded: [[String]] = []
    weak var runner: BatchRunner?

    init(_ runs: [String: FakeRun] = [:]) {
        self.runs = runs
    }

    var calls: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func record(_ arguments: [String], tempName: String) -> (FakeRun, BatchRunner?) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(arguments)
        let key = runs.keys.first { tempName == TempOutput.name(for: $0 + ".mka") || tempName == TempOutput.name(for: $0 + ".mkv") }
        return (key.flatMap { runs[$0] } ?? FakeRun(), runner)
    }

    func run(_ arguments: [String]) async throws -> ToolCommandResult {
        let temp = arguments[arguments.firstIndex(of: "-o")! + 1]
        let tempName = (temp as NSString).lastPathComponent
        let (script, runner) = record(arguments, tempName: tempName)

        if let failure = script.throwing { throw failure }
        if script.writesTemp {
            try Data("new output".utf8).write(to: URL(fileURLWithPath: temp))
        }
        if script.createsOutput {
            let output = (temp as NSString).deletingLastPathComponent + "/" + String(tempName.dropFirst().replacingOccurrences(of: ".partial", with: ""))
            try Data("someone else's file".utf8).write(to: URL(fileURLWithPath: output))
        }
        if script.requestsStop { runner?.requestStop() }
        if script.cancelsTask {
            withUnsafeCurrentTask { $0?.cancel() }
            try Task.checkCancellation()
        }
        return ToolCommandResult(status: script.status, standardOutput: Data(script.output.utf8), standardError: Data())
    }
}

/// A real temporary folder tree with Source, Video, Audio and Output folders.
struct RunFolders {
    let root: String

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-run-\(UUID().uuidString)").path
        for folder in ["Source", "Video", "Audio", "Output"] {
            try FileManager.default.createDirectory(atPath: "\(root)/\(folder)", withIntermediateDirectories: true)
        }
    }

    func path(_ relative: String) -> String { "\(root)/\(relative)" }

    @discardableResult
    func touch(_ relative: String, _ text: String = "input") throws -> String {
        let path = path(relative)
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
        return path
    }

    func names(in folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: path(folder))) ?? []).sorted()
    }

    func contents(_ relative: String) -> String? {
        (try? Data(contentsOf: URL(fileURLWithPath: path(relative)))).map { String(decoding: $0, as: UTF8.self) }
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: root)
    }
}

enum RunFixture {
    static let splitInfo = MediaInfo(containerType: "Matroska", tracks: [
        TrackInfo(id: 0, kind: .video), TrackInfo(id: 1, kind: .audio), TrackInfo(id: 2, kind: .subtitles),
    ])
    static let videoInfo = MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .video)])
    static let mkaInfo = MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .audio), TrackInfo(id: 1, kind: .subtitles)], chapterEditions: 1)

    /// A Split job for `Source/<name>.mkv`, with its input file created.
    static func split(_ name: String, in folders: RunFolders) throws -> RunJob {
        let source = try folders.touch("Source/\(name).mkv")
        return RunJob(mode: .split, baseName: name, sourcePath: source, outputPath: folders.path("Output/\(name).mka"), sourceInfo: splitInfo)
    }

    /// A Remux job for `Video/<name>.mkv` + `Audio/<name>.mka`, with both inputs created.
    static func remux(_ name: String, in folders: RunFolders) throws -> RunJob {
        let video = try folders.touch("Video/\(name).mkv")
        let mka = try folders.touch("Audio/\(name).mka")
        return RunJob(mode: .remux, baseName: name, sourcePath: video, mkaPath: mka, outputPath: folders.path("Output/\(name).mkv"), sourceInfo: videoInfo, mkaInfo: mkaInfo)
    }

    /// An identifier that reports each job's scanned tracks.
    static func identifier(for jobs: [RunJob], overrides: [String: MediaProbe] = [:]) -> FakeIdentifier {
        var probes: [String: MediaProbe] = [:]
        for job in jobs {
            probes[job.sourcePath] = .readable(job.sourceInfo)
            if let mka = job.mkaPath, let info = job.mkaInfo { probes[mka] = .readable(info) }
        }
        probes.merge(overrides) { $1 }
        return FakeIdentifier(probes)
    }
}

/// Collects runner events from any thread.
final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [RunEvent] = []

    func append(_ event: RunEvent) {
        lock.lock()
        stored.append(event)
        lock.unlock()
    }

    var events: [RunEvent] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// The final status of each row, by id.
    var statuses: [String: JobStatus] {
        var result: [String: JobStatus] = [:]
        for case let .finished(id, status) in events { result[id] = status }
        return result
    }
}
