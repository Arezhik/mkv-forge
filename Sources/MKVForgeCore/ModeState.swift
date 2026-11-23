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
    public var id: String { item.rowID }
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
    /// True when a Remux row is still waiting on Choose Match (v2.2 §B.7).
    public var hasAmbiguousMatch: Bool { rows.contains { $0.item.matchMenu != nil } }
    /// Picks on the current Remux scan. Empty when matching is off or nothing is scanned.
    public var picks: [RemuxPick] { scan?.picks ?? [] }

    public func row(_ id: String) -> QueueRow? { rows.first { $0.id == id } }

    // MARK: Scan

    /// Replaces the queue with a finished scan in one step (v2 §3, v2.1 §2.4).
    /// Match picks are whatever the new result carries, which is none: a scan drops them (v2.2 §B.5).
    public mutating func applyScan(_ result: ScanResult) {
        replaceRows(with: result, resetSummary: true, preserveRunState: false)
    }

    /// Drops the scan, the queue, any match picks and the last summary. Folders stay.
    public mutating func clearScan() {
        scan = nil
        rows = []
        lastSummary = nil
    }

    /// A Match on MKA Name change (v2.2 §A.3). Remux drops its queue. Split is left alone.
    public mutating func matchSettingChanged() {
        guard mode == .remux else { return }
        clearScan()
    }

    /// Re-scores the current Remux scan with these picks. Returns the row id of the last
    /// pick that locked a pair, so the queue can select it. No-op without a matching inventory.
    @discardableResult
    public mutating func applyMatchPicks(_ picks: [RemuxPick]) -> String? {
        guard let current = scan, let inventory = current.inventory, mode == .remux else { return nil }
        let evaluated = RemuxMatcher.items(inventory: inventory, picks: picks)
        let result = ScanResult(mode: .remux, scannedAt: current.scannedAt, items: evaluated.items, inventory: inventory, picks: evaluated.picks)
        replaceRows(with: result, resetSummary: false, preserveRunState: true)
        guard let focus = evaluated.picks.last else { return nil }
        return rows.first { $0.item.sourcePath == focus.videoPath && $0.item.mkaPath == focus.audioPath }?.id
    }

    private mutating func replaceRows(with result: ScanResult, resetSummary: Bool, preserveRunState: Bool) {
        let previous = rows
        let previouslyReady = Set(previous.filter { !$0.isFlagged }.map(\.id))
        let uncheckedReady = Set(previous.filter { !$0.isFlagged && !$0.isChecked }.map(\.id))
        let oldByID = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        rows = result.items.map { item in
            let checked: Bool
            if item.isReady {
                let keepsUnchecked = previouslyReady.contains(item.rowID) && uncheckedReady.contains(item.rowID)
                checked = !keepsUnchecked
            } else {
                checked = false
            }
            var row = QueueRow(item: item, isChecked: checked)
            if preserveRunState, let old = oldByID[item.rowID],
               old.item.sourcePath == item.sourcePath, old.item.mkaPath == item.mkaPath {
                row.runStatus = old.runStatus
                row.wontStart = old.wontStart
            }
            return row
        }
        scan = result
        if resetSummary { lastSummary = nil }
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
