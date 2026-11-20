import Foundation

// Run statuses (docs/design/v1-layout-contract_v2.md §4, §6; docs/LESSONS.md L6):
// - The queue is the last scan's rows. A rescan replaces it; MKVForge has no Clear
//   Finished, no row ✕ and no Cancel All. Nothing in the queue ever deletes a file.
// - Cancel finishes the current file, then stops; rows it kept from starting are notRun
//   and show Ready again. A hard stop (quitting with Quit) marks the current row canceled.
// - An empty queue shows the empty state (MKVForge has no drop screen).

/// Where one queued file is. The texts follow docs/design/v1-layout-contract_v2.md §4.
public enum JobStatus: Equatable, Sendable {
    case waiting
    /// The current file. There's no per-file percentage (contract v2 §4).
    case working
    /// mkvmerge exit 0, and the output is in place.
    case done(outputPath: String)
    /// mkvmerge exit 1: the output is in place. `warnings` are mkvmerge's `Warning:` lines.
    case doneWithWarning(outputPath: String, warnings: [String])
    /// `reason` goes in the Reason column; `detail` (raw mkvmerge output) in its help tag.
    case failed(reason: String, detail: String)
    /// Cancel stopped the batch before this row started. The row shows Ready again.
    case notRun
    /// A hard stop (app quit) killed mkvmerge on this row. Its temp file is deleted.
    case canceled

    /// Reason shown on Waiting rows while Cancel waits for the current file.
    public static let wontStartReason = "Won't start: batch cancelled"

    /// Waiting or working: the row is part of the batch that's still running.
    public var isActive: Bool {
        switch self {
        case .waiting, .working: return true
        case .done, .doneWithWarning, .failed, .notRun, .canceled: return false
        }
    }

    /// True when `next` only repeats the working state. Those updates are throttled;
    /// every other change (start, done, failed) is published right away.
    public func isProgressTick(to next: JobStatus) -> Bool {
        self == .working && next == .working
    }

    /// The Status column text. `mode` picks Splitting… or Remuxing….
    public func statusText(mode: ScanMode) -> String {
        switch self {
        case .waiting: return "Waiting"
        case .working: return mode == .split ? "Splitting…" : "Remuxing…"
        case .done: return "Done"
        case .doneWithWarning: return "Done · warning"
        case .failed: return "Failed"
        case .notRun: return "Ready"
        case .canceled: return "Cancelled"
        }
    }

    /// The Reason column. Nil shows as —.
    public var reasonText: String? {
        switch self {
        case let .doneWithWarning(_, warnings): return MKVMergeOutput.warningReason(warnings)
        case let .failed(reason, _): return reason
        case .waiting, .working, .done, .notRun, .canceled: return nil
        }
    }

    /// The Reason help tag: every warning line, or the raw mkvmerge output of a failure.
    public var helpText: String? {
        switch self {
        case let .doneWithWarning(_, warnings): return MKVMergeOutput.warningHelp(warnings)
        case let .failed(reason, detail): return detail.isEmpty ? reason : detail
        case .waiting, .working, .done, .notRun, .canceled: return nil
        }
    }

    /// The written file, for Done and Done · warning rows.
    public var outputPath: String? {
        switch self {
        case let .done(path), let .doneWithWarning(path, _): return path
        default: return nil
        }
    }
}

/// A file and its run status. The window's rows are `QueueRow` (ModeState.swift).
public struct QueueItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var path: String
    public var status: JobStatus

    public init(id: UUID = UUID(), path: String, status: JobStatus = .waiting) {
        self.id = id
        self.path = path
        self.status = status
    }

    public var fileName: String { (path as NSString).lastPathComponent }
}
