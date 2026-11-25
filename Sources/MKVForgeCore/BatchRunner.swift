import Foundation

// Running Split and Remux (issue #3; docs/scaffold.md, MKVToolNix Integration; Phase 3
// research). Rules:
// - One file at a time, in queue order. A failed file doesn't stop the batch.
// - Right before each file: the Output folder must still exist (mkvmerge would silently
//   create a missing one and exit 0, L29), the inputs must still exist, the output must
//   still be absent, and a fresh `mkvmerge -J` must match the scan. Otherwise the row
//   fails and mkvmerge doesn't run.
// - mkvmerge writes to the hidden temp name (`TempOutput`); a stale temp with that name is
//   replaced. Exit 0 or 1 with the temp present renames it to the output with
//   `FileManager.moveItem`, which refuses to replace an existing file. Everything else
//   deletes the temp. Existing files are never overwritten.
// - Exit 0 = Done, 1 = Done · warning, 2 = Failed. Any other code (a signal) is Failed.
// - Cancel (`requestStop`) lets the current file finish, then the rest are not run.
//   Cancelling the Swift task (a hard stop, such as quitting) kills mkvmerge through
//   `ToolCommand`, deletes the temp, and marks that row cancelled (L5).
// - mkvmerge runs through `ToolCommand`, so it gets the UTF-8 locale (`ToolEnvironment`,
//   L27). Its `Warning:` and `Error:` lines are on standard output, so they're logged
//   here (L28).
// - The mux process is `mkvmerge --gui-mode`. That flag is not added to `mkvmerge -J`
//   or `--version`. `#GUI#progress` becomes a throttled ETA on the batch caption.

/// Runs mkvmerge with arguments. The app uses `MKVMergeProcess`; tests use a fake.
/// `onProgress` is each mux percent (0...100) from `#GUI#progress`.
public protocol MKVMergeRunning: Sendable {
    func run(_ arguments: [String], onProgress: @escaping @Sendable (Int) -> Void) async throws -> ToolCommandResult
}

/// The installed mkvmerge, run through `ToolCommand` (logging, cancel, UTF-8 locale).
public struct MKVMergeProcess: MKVMergeRunning {
    public let executable: String

    public init(executable: String) {
        self.executable = executable
    }

    /// `--gui-mode` is prepended here, not in `MKVMergeCommand`. Identify and version
    /// do not use this type.
    static func muxArguments(_ arguments: [String]) -> [String] {
        ["--gui-mode"] + arguments
    }

    public func run(_ arguments: [String], onProgress: @escaping @Sendable (Int) -> Void) async throws -> ToolCommandResult {
        let parser = GUIParserBox()
        return try await ToolCommand.run(executable: executable, arguments: Self.muxArguments(arguments), onStdoutLine: { line in
            if let percent = parser.percent(in: line) {
                onProgress(percent)
            }
        })
    }
}

/// One stdout reader mutates the parser. The lock keeps that off the runner's task.
private final class GUIParserBox: @unchecked Sendable {
    private let lock = NSLock()
    private var parser = MKVMergeGUIParser()

    func percent(in line: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return parser.progressPercent(in: line)
    }
}

/// What the runner reports while it works.
public enum RunEvent: Equatable, Sendable {
    /// `index` counts from 1.
    case started(id: String, index: Int, total: Int)
    case finished(id: String, status: JobStatus)
    /// The caption under the batch bar. Empty hides it. Throttled to about 10 a second.
    case progress(caption: String)
    case batchFinished(BatchSummary)
}

public final class BatchRunner: Sendable {
    private let tool: any MKVMergeRunning
    private let identifier: any TrackIdentifying
    private let stopFlag = StopFlag()
    /// ETA clock. Tests pass a fixed clock; the app uses the wall clock.
    private let clock: @Sendable () -> Date

    public init(tool: any MKVMergeRunning, identifier: any TrackIdentifying, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.tool = tool
        self.identifier = identifier
        self.clock = clock
    }

    /// The installed mkvmerge for both running and identifying.
    public convenience init(executable: String, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.init(tool: MKVMergeProcess(executable: executable), identifier: MKVMergeIdentifier(executable: executable), clock: clock)
    }

    /// Cancel: finish the current file, then stop. Safe from any thread.
    public func requestStop() {
        stopFlag.set()
    }

    public var isStopRequested: Bool { stopFlag.isSet }

    /// Runs `jobs` one at a time and returns the summary. `flaggedCount` is the scan's
    /// flagged rows, for the summary. `onEvent` may arrive from the runner's task or,
    /// for a progress caption, from the tool's stdout reader.
    @discardableResult
    public func run(_ jobs: [RunJob], flaggedCount: Int, onEvent: @escaping @Sendable (RunEvent) -> Void = { _ in }) async -> BatchSummary {
        stopFlag.clear()
        let mode = jobs.first?.mode ?? .split
        var summary = BatchSummary(mode: mode, filesInRun: jobs.count, flagged: flaggedCount)
        var finishedDurations: [TimeInterval] = []
        let modeName = mode == .split ? "Split" : "Remux"
        DebugLog.shared.record(.queue, "Run \(modeName) started: \(jobs.count) files")
        for (offset, job) in jobs.enumerated() {
            let index = offset + 1
            if stopFlag.isSet || Task.isCancelled {
                summary.stopped = true
                summary.record(.notRun)
                onEvent(.finished(id: job.id, status: .notRun))
                continue
            }
            onEvent(.started(id: job.id, index: index, total: jobs.count))
            DebugLog.shared.record(.work, "File \(index) of \(jobs.count) started")
            let publisher = ETAPublisher(
                finished: finishedDurations,
                queuedAfterCurrent: jobs.count - index,
                isCancelled: { [stopFlag] in stopFlag.isSet },
                onEvent: onEvent
            )
            let status: JobStatus
            do {
                status = try await runOne(job, publisher: publisher)
            } catch {
                // Only cancellation reaches here: a hard stop.
                status = .canceled
                summary.stopped = true
            }
            if let duration = publisher.muxDuration {
                finishedDurations.append(duration)
            }
            log(status, index: index, total: jobs.count)
            summary.record(status)
            onEvent(.finished(id: job.id, status: status))
        }
        if stopFlag.isSet { summary.stopped = true }
        DebugLog.shared.record(.queue, "Run \(modeName) \(summary.stopped ? "stopped" : "finished"): \(summary.text)")
        onEvent(.batchFinished(summary))
        return summary
    }

    // MARK: One file

    /// Pre-checks, then mkvmerge. Throws only `CancellationError` (a hard stop).
    func runOne(_ job: RunJob, publisher: ETAPublisher? = nil) async throws -> JobStatus {
        if let failure = try await precheck(job) { return failure }
        return try await execute(job, sourceTracks: job.sourceInfo.tracks, publisher: publisher)
    }

    /// Nil when the job can run. Otherwise the Failed status it gets instead.
    func precheck(_ job: RunJob) async throws -> JobStatus? {
        let files = FileManager.default
        var isFolder: ObjCBool = false
        if !files.fileExists(atPath: job.outputFolder, isDirectory: &isFolder) || !isFolder.boolValue {
            return .failed(
                reason: "Output folder is missing",
                detail: "The Output folder \(job.outputFolder) isn't there anymore (unplugged drive, or renamed?). mkvmerge would create it again, so this file didn't run. Choose the folder again, then scan."
            )
        }
        var inputs = [(job.sourcePath, job.sourceInfo)]
        if let mka = job.mkaPath, let info = job.mkaInfo { inputs.append((mka, info)) }
        for (path, _) in inputs where !files.fileExists(atPath: path) {
            let name = (path as NSString).lastPathComponent
            return .failed(reason: "\(name) is missing", detail: "\(name) was moved or deleted after the scan. Scan again.")
        }
        if files.fileExists(atPath: job.outputPath) {
            let issue = ScanIssue.outputExists(fileName: job.outputName)
            return .failed(reason: issue.reason, detail: issue.detail)
        }
        for (path, scanned) in inputs {
            let probe: MediaProbe
            do {
                probe = try await identifier.identify(path)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .failed(reason: "mkvmerge could not be started", detail: error.localizedDescription)
            }
            try Task.checkCancellation()
            if probe != .readable(scanned) {
                let name = (path as NSString).lastPathComponent
                return .failed(
                    reason: "Changed since the scan. Scan again.",
                    detail: "\(name) changed after the scan: its tracks are different now, or mkvmerge can't read it. Scan again before running it."
                )
            }
        }
        return nil
    }

    /// Writes the temp file with mkvmerge and renames it on success. `sourceTracks` are
    /// the source's tracks (the video's, for Remux). No pre-checks.
    func execute(_ job: RunJob, sourceTracks: [TrackInfo], publisher: ETAPublisher? = nil) async throws -> JobStatus {
        let files = FileManager.default
        let temp = job.tempPath
        removeIfPresent(temp)
        let arguments: [String]
        do {
            switch job.mode {
            case .split:
                arguments = try MKVMergeCommand.split(source: job.sourcePath, output: temp, tracks: sourceTracks)
            case .remux:
                arguments = try MKVMergeCommand.remux(video: job.sourcePath, mka: job.mkaPath ?? "", output: temp, videoTracks: sourceTracks)
            }
        } catch {
            return .failed(reason: "Couldn't build the mkvmerge command", detail: error.localizedDescription)
        }

        let result: ToolCommandResult
        let started = publisher == nil ? nil : clock()
        let readClock = clock
        do {
            result = try await tool.run(arguments) { percent in
                guard let publisher, let started else { return }
                publisher.receive(percent: percent, elapsed: readClock().timeIntervalSince(started))
            }
        } catch is CancellationError {
            removeIfPresent(temp)
            throw CancellationError()
        } catch {
            removeIfPresent(temp)
            return .failed(reason: "mkvmerge could not be started", detail: error.localizedDescription)
        }
        if let publisher, let started {
            publisher.noteDuration(readClock().timeIntervalSince(started))
        }
        if Task.isCancelled {
            removeIfPresent(temp)
            throw CancellationError()
        }

        let output = MKVMergeOutput(result: result)
        for line in output.warnings + output.errors {
            DebugLog.shared.record(.tool, "mkvmerge said \(Self.cut(line))", isError: line.hasPrefix("Error:"))
        }
        switch result.status {
        case 0, 1:
            guard files.fileExists(atPath: temp) else {
                return .failed(reason: "mkvmerge finished but wrote no file", detail: output.rawText)
            }
            do {
                try files.moveItem(atPath: temp, toPath: job.outputPath)
            } catch {
                removeIfPresent(temp)
                if files.fileExists(atPath: job.outputPath) {
                    let issue = ScanIssue.outputExists(fileName: job.outputName)
                    return .failed(reason: issue.reason, detail: issue.detail + " It appeared while this file was running, so the new copy was deleted.")
                }
                return .failed(reason: "Couldn't rename the finished file", detail: error.localizedDescription)
            }
            return result.status == 0 ? .done(outputPath: job.outputPath) : .doneWithWarning(outputPath: job.outputPath, warnings: output.warnings)
        case 2:
            removeIfPresent(temp)
            return .failed(reason: output.failureReason(status: 2), detail: output.rawText)
        default:
            removeIfPresent(temp)
            return .failed(reason: "mkvmerge stopped unexpectedly (code \(result.status))", detail: output.rawText)
        }
    }

    private func removeIfPresent(_ path: String) {
        let files = FileManager.default
        guard files.fileExists(atPath: path) else { return }
        do {
            try files.removeItem(atPath: path)
        } catch {
            DebugLog.shared.record(.error, "Couldn't delete a temp file: \(error.localizedDescription)", isError: true)
        }
    }

    private func log(_ status: JobStatus, index: Int, total: Int) {
        let prefix = "File \(index) of \(total)"
        switch status {
        case .done: DebugLog.shared.record(.work, "\(prefix) done")
        case let .doneWithWarning(_, warnings): DebugLog.shared.record(.work, "\(prefix) done with \(warnings.count) warning(s)")
        case let .failed(reason, _): DebugLog.shared.record(.error, "\(prefix) failed: \(Self.cut(reason))", isError: true)
        case .canceled: DebugLog.shared.record(.work, "\(prefix) cancelled (hard stop)")
        case .notRun, .waiting, .working: break
        }
    }

    static func cut(_ text: String, limit: Int = 2000) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }
}

/// Turns mux percents into a throttled ETA caption. One instance per file.
final class ETAPublisher: @unchecked Sendable {
    private let lock = NSLock()
    private var eta = RunETA()
    private let finished: [TimeInterval]
    private let queuedAfterCurrent: Int
    private let isCancelled: @Sendable () -> Bool
    private let onEvent: @Sendable (RunEvent) -> Void
    private var duration: TimeInterval?

    init(
        finished: [TimeInterval],
        queuedAfterCurrent: Int,
        isCancelled: @escaping @Sendable () -> Bool,
        onEvent: @escaping @Sendable (RunEvent) -> Void
    ) {
        self.finished = finished
        self.queuedAfterCurrent = queuedAfterCurrent
        self.isCancelled = isCancelled
        self.onEvent = onEvent
    }

    func receive(percent: Int, elapsed: TimeInterval) {
        let sample = RunETA.Sample(
            percent: percent,
            elapsed: elapsed,
            finishedDurations: finished,
            queuedAfterCurrent: queuedAfterCurrent,
            cancelled: isCancelled()
        )
        let now = Date(timeIntervalSinceReferenceDate: elapsed)
        lock.lock()
        let event = eta.event(for: sample, at: now)
        lock.unlock()
        if let event {
            onEvent(event)
        }
    }

    func noteDuration(_ value: TimeInterval) {
        lock.lock()
        duration = value
        lock.unlock()
    }

    var muxDuration: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return duration
    }
}

/// The Cancel flag. Set from the main thread, read by the runner's task.
private final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func clear() {
        lock.lock()
        value = false
        lock.unlock()
    }
}
