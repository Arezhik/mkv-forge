import Foundation

// Batch counts and the bottom bar text (docs/design/v1-layout-contract_v2.md §6–§7). Rules:
// - Zero counts are hidden. Warnings are a parenthetical on the done count, because a
//   warning row is done: `3 done (1 with warning)`.
// - Flagged rows aren't in the run; their count comes from the scan.
// - `N of M complete` counts finished files (Done, Done · warning or Failed) out of the
//   files checked into this run.

public struct BatchSummary: Equatable, Sendable {
    public let mode: ScanMode
    /// Files checked into this run.
    public let filesInRun: Int
    /// Rows flagged at scan (not in the run).
    public let flagged: Int
    /// Done rows, including the ones with a warning.
    public internal(set) var done = 0
    public internal(set) var withWarning = 0
    public internal(set) var failed = 0
    /// Rows Cancel kept from starting.
    public internal(set) var notRun = 0
    /// Rows a hard stop interrupted.
    public internal(set) var canceled = 0
    /// True when Cancel or a hard stop ended the batch early.
    public internal(set) var stopped = false
    /// Files written this run, in run order.
    public internal(set) var outputPaths: [String] = []

    public init(mode: ScanMode, filesInRun: Int, flagged: Int) {
        self.mode = mode
        self.filesInRun = filesInRun
        self.flagged = flagged
    }

    /// Files that finished (Done, Done · warning or Failed).
    public var completed: Int { done + failed }

    mutating func record(_ status: JobStatus) {
        switch status {
        case let .done(path):
            done += 1
            outputPaths.append(path)
        case let .doneWithWarning(path, _):
            done += 1
            withWarning += 1
            outputPaths.append(path)
        case .failed:
            failed += 1
        case .notRun:
            notRun += 1
        case .canceled:
            canceled += 1
        case .waiting, .working, .skipped:
            break
        }
    }

    /// The bottom bar summary after the batch: `Finished · …` or `Stopped · N of M complete`.
    public var text: String {
        if stopped { return "Stopped · \(Self.progressText(completed: completed, total: filesInRun))" }
        var parts: [String] = []
        if done > 0 {
            var part = "\(done) done"
            if withWarning > 0 { part += " (\(withWarning) with \(withWarning == 1 ? "warning" : "warnings"))" }
            parts.append(part)
        }
        if flagged > 0 { parts.append("\(flagged) flagged") }
        if failed > 0 { parts.append("\(failed) failed") }
        return (["Finished"] + parts).joined(separator: " · ")
    }

    /// The progress caption after a finish: `3 .mka saved` / `3 .mkv saved`.
    public var savedText: String {
        "\(outputPaths.count) \(mode == .split ? ".mka" : ".mkv") saved"
    }

    /// `2 of 4 complete`.
    public static func progressText(completed: Int, total: Int) -> String {
        "\(completed) of \(total) complete"
    }
}
