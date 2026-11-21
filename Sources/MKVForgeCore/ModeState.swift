import Foundation

// One mode's folders, scan and queue (layout contract v2 §2–§7; v2.1 §2.4). Rules:
// - Each mode keeps its own folders, scan result, checkboxes and last summary.
// - Changing a folder drops that mode's scan and queue (they no longer match the folders).
// - A scan's rows replace the queue in one step. Ready rows start checked; a row that was
//   Ready before and is still Ready keeps its checkbox. Flagged rows are unchecked and
//   can't be checked in v1.
// - Run: checked Ready rows go Waiting, then Splitting…/Remuxing…, then Done, Done ·
//   warning or Failed. Cancel shows Waiting rows as Ready with `Won't start: batch
//   cancelled` until the stop completes; then they show Ready with `—` again.
// - After a finish or a stop, Done and Done · warning rows are unchecked; Failed rows
//   stay checked, so the next run retries only them.

/// One queue row: a scan item plus its checkbox and run status.
public struct QueueRow: Identifiable, Equatable, Sendable {
    public var id: String { item.baseName }
    public let item: ScanItem
    public var isChecked: Bool
    /// Nil until the row is part of a run: it shows its scan state (Ready or Issue).
    public var runStatus: JobStatus?
    /// Cancel was clicked while this row was Waiting.
    public var wontStart = false

    public init(item: ScanItem, isChecked: Bool, runStatus: JobStatus? = nil) {
        self.item = item
        self.isChecked = isChecked
        self.runStatus = runStatus
    }

    public var baseName: String { item.baseName }
    public var isFlagged: Bool { !item.isReady }
}

public struct ModeState: Equatable, Sendable {
    public let mode: ScanMode
    public private(set) var folders: [FolderRole: String] = [:]
    public private(set) var scan: ScanResult?
    public private(set) var rows: [QueueRow] = []
    /// The last finished or stopped batch, until the next scan, run or folder change.
    public private(set) var lastSummary: BatchSummary?

    public init(mode: ScanMode, folders: [FolderRole: String] = [:]) {
        self.mode = mode
        for role in Self.roles(for: mode) {
            if let path = folders[role], !path.isEmpty { self.folders[role] = path }
        }
    }

    /// Folder rows, top to bottom: Split = Source, Output; Remux = Video, Audio, Output.
    public static func roles(for mode: ScanMode) -> [FolderRole] {
        switch mode {
        case .split: return [.source, .output]
        case .remux: return [.video, .audio, .output]
        }
    }

    public var roles: [FolderRole] { Self.roles(for: mode) }

    public func folder(_ role: FolderRole) -> String? { folders[role] }

    public var hasAllFolders: Bool { roles.allSatisfy { folders[$0] != nil } }

    /// Choose…: sets one folder and drops the scan and queue of this mode.
    public mutating func setFolder(_ path: String?, for role: FolderRole) {
        guard roles.contains(role) else { return }
        let new = (path?.isEmpty ?? true) ? nil : path
        guard folders[role] != new else { return }
        folders[role] = new
        scan = nil
        rows = []
        lastSummary = nil
    }

    // MARK: Counts

    public var checkedCount: Int { rows.filter(\.isChecked).count }
    public var flaggedCount: Int { rows.filter(\.isFlagged).count }
    public var checkedIDs: Set<String> { Set(rows.filter(\.isChecked).map(\.id)) }

    public func row(_ id: String) -> QueueRow? { rows.first { $0.id == id } }

    // MARK: Scan

    /// Replaces the queue with a finished scan in one step (v2 §3, v2.1 §2.4).
    public mutating func applyScan(_ result: ScanResult) {
        let previouslyReady = Set(rows.filter { !$0.isFlagged }.map(\.id))
        let uncheckedReady = Set(rows.filter { !$0.isFlagged && !$0.isChecked }.map(\.id))
        rows = result.items.map { item in
            guard item.isReady else { return QueueRow(item: item, isChecked: false) }
            let keepsUnchecked = previouslyReady.contains(item.baseName) && uncheckedReady.contains(item.baseName)
            return QueueRow(item: item, isChecked: !keepsUnchecked)
        }
        scan = result
        lastSummary = nil
    }

    // MARK: Checkboxes

    /// Flagged rows can't be checked (v2 §4). Returns false when nothing changed.
    @discardableResult
    public mutating func setChecked(_ id: String, _ checked: Bool) -> Bool {
        guard let index = rows.firstIndex(where: { $0.id == id }), !rows[index].isFlagged,
              rows[index].isChecked != checked else { return false }
        rows[index].isChecked = checked
        return true
    }

    /// Space on the selected rows: if any of them is unchecked, check them all; else uncheck.
    public mutating func toggle(_ ids: Set<String>) {
        let targets = rows.filter { ids.contains($0.id) && !$0.isFlagged }
        guard !targets.isEmpty else { return }
        let check = targets.contains { !$0.isChecked }
        for row in targets { setChecked(row.id, check) }
    }

    public mutating func selectAllReady() {
        for index in rows.indices where !rows[index].isFlagged { rows[index].isChecked = true }
    }

    public mutating func deselectAll() {
        for index in rows.indices { rows[index].isChecked = false }
    }

    // MARK: Run

    /// The checked Ready rows as jobs, in queue order.
    public func jobs() -> [RunJob] {
        guard let scan else { return [] }
        return RunJob.jobs(from: scan, checked: checkedIDs)
    }

    /// Marks the jobs' rows Waiting and clears the previous run's statuses.
    public mutating func beginRun(_ jobs: [RunJob]) {
        let ids = Set(jobs.map(\.id))
        for index in rows.indices {
            rows[index].wontStart = false
            rows[index].runStatus = ids.contains(rows[index].id) ? .waiting : nil
        }
        lastSummary = nil
    }

    public mutating func apply(_ event: RunEvent) {
        switch event {
        case let .started(id, _, _):
            update(id) { $0.runStatus = .working; $0.wontStart = false }
        case let .finished(id, status):
            update(id) { row in
                row.wontStart = false
                // A row Cancel kept from starting shows Ready again, with `—`.
                row.runStatus = status == .notRun ? nil : status
            }
        case let .batchFinished(summary):
            finishBatch(summary)
        }
    }

    /// Cancel was clicked: Waiting rows show Ready with `Won't start: batch cancelled`.
    public mutating func markCancelling() {
        for index in rows.indices where rows[index].runStatus == .waiting {
            rows[index].wontStart = true
        }
    }

    /// After a finish or a stop: Done rows unchecked, Failed rows kept checked (v2 §4, §6).
    public mutating func finishBatch(_ summary: BatchSummary) {
        for index in rows.indices {
            rows[index].wontStart = false
            switch rows[index].runStatus {
            case .done?, .doneWithWarning?:
                rows[index].isChecked = false
            case .waiting?, .notRun?:
                rows[index].runStatus = nil
            default:
                break
            }
        }
        lastSummary = summary
    }

    private mutating func update(_ id: String, _ change: (inout QueueRow) -> Void) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        change(&rows[index])
    }
}
