import Foundation

// Toolbar subtitle, bottom bar and folder field texts (layout contract v2 §1, §3, §6, §7;
// v2.1 §2.1, §2.4). Rules:
// - Subtitle: `Split · 4 of 7 selected`, `Splitting · 2 of 4 complete`, `Finished · 3 of 4
//   succeeded`, `Split · MKVToolNix not found`, `Split · Scanning…`, `Cancelling ·
//   finishing current file`.
// - Bottom bar summary (bold part first): `No files`; **`7 files`**` · 4 selected · 2
//   flagged`; **`2 of 4 complete`**` · Splitting <name>`; **`Finishing <name>, then
//   stopping`**` · 2 of 4 complete`; **`Stopped`**` · 3 of 4 complete`; **`Finished`**` ·
//   3 done (1 with warning) · 2 flagged · 1 failed`. Zero counts are hidden.
// - During a re-scan the bar keeps the previous summary until the new rows swap in.
// - Progress column (152 pt): running = files completed ÷ files in the run. The caption
//   is the time remaining when the estimate is stable, and empty while cancelling.
//   Finished = full bar and `3 .mka saved`. Absent when idle and after a stop.
// - Show in Finder: after a finish or a Cancel that wrote at least one file.

public struct SummaryText: Equatable, Sendable {
    /// Semibold.
    public var bold: String
    /// Regular, starting with ` · ` when not empty.
    public var rest: String

    public init(bold: String, rest: String = "") {
        self.bold = bold
        self.rest = rest
    }

    public var plain: String { bold + rest }
}

public struct ProgressColumn: Equatable, Sendable {
    public var completed: Int
    public var total: Int
    /// Running: time remaining, such as `About 2 minutes left`, or empty when that
    /// estimate is hidden. Cancelling: empty. Finished: `3 .mka saved`.
    public var caption: String
}

public enum StatusLines {
    public static let toolMissingBanner = "MKVToolNix wasn't found."
    public static let toolMissingBannerDetail = "MKVForge needs mkvmerge to scan, split and remux. Install MKVToolNix or show MKVForge where it is."
    public static let downloadURL = "https://mkvtoolnix.download/"

    public static func subtitle(_ workflow: Workflow, _ state: ModeState, toolUsable: Bool) -> String {
        let mode = state.mode.displayName
        switch workflow.activity {
        case .scanning:
            return "\(mode) · Scanning…"
        case .running:
            let verb = state.mode == .split ? "Splitting" : "Remuxing"
            let batch = workflow.batch
            return "\(verb) · \(BatchSummary.progressText(completed: batch?.completed ?? 0, total: batch?.total ?? 0))"
        case .cancelling:
            return "Cancelling · finishing current file"
        case .idle:
            if !toolUsable { return "\(mode) · MKVToolNix not found" }
            if let summary = state.lastSummary {
                if summary.stopped { return "Stopped · \(BatchSummary.progressText(completed: summary.completed, total: summary.filesInRun))" }
                return "Finished · \(summary.done) of \(summary.filesInRun) succeeded"
            }
            if state.scan != nil { return "\(mode) · \(state.checkedCount) of \(state.rows.count) selected" }
            return mode
        }
    }

    public static func summary(_ workflow: Workflow, _ state: ModeState) -> SummaryText {
        switch workflow.activity {
        case .running:
            let batch = workflow.batch
            let progress = BatchSummary.progressText(completed: batch?.completed ?? 0, total: batch?.total ?? 0)
            let verb = state.mode == .split ? "Splitting" : "Remuxing"
            if let name = batch?.currentName { return SummaryText(bold: progress, rest: " · \(verb) \(name)") }
            return SummaryText(bold: progress)
        case .cancelling:
            let batch = workflow.batch
            let progress = BatchSummary.progressText(completed: batch?.completed ?? 0, total: batch?.total ?? 0)
            if let name = batch?.currentName { return SummaryText(bold: "Finishing \(name), then stopping", rest: " · \(progress)") }
            return SummaryText(bold: "Stopping", rest: " · \(progress)")
        case .idle, .scanning:
            return idleSummary(state)
        }
    }

    static func idleSummary(_ state: ModeState) -> SummaryText {
        if let summary = state.lastSummary {
            if summary.stopped {
                return SummaryText(bold: "Stopped", rest: " · \(BatchSummary.progressText(completed: summary.completed, total: summary.filesInRun))")
            }
            let text = summary.text
            let prefix = "Finished"
            return SummaryText(bold: prefix, rest: String(text.dropFirst(prefix.count)))
        }
        guard state.scan != nil else { return SummaryText(bold: "No files") }
        let noun = state.mode == .split ? "file" : "name"
        var rest = " · \(state.checkedCount) selected"
        if state.flaggedCount > 0 { rest += " · \(state.flaggedCount) flagged" }
        return SummaryText(bold: ScanCaption.count(state.rows.count, noun), rest: rest)
    }

    /// Nil when the column is absent (idle, scanning a first time, after a stop).
    public static func progressColumn(_ workflow: Workflow, _ state: ModeState) -> ProgressColumn? {
        switch workflow.activity {
        case .running:
            guard let batch = workflow.batch else { return nil }
            return ProgressColumn(completed: batch.completed, total: batch.total, caption: batch.etaCaption)
        case .cancelling:
            guard let batch = workflow.batch else { return nil }
            return ProgressColumn(completed: batch.completed, total: batch.total, caption: "")
        case .idle, .scanning:
            guard let summary = state.lastSummary, !summary.stopped else { return nil }
            return ProgressColumn(completed: summary.filesInRun, total: max(summary.filesInRun, 1), caption: summary.savedText)
        }
    }

    /// Show in Finder appears after a finish or a Cancel that wrote at least one file.
    public static func showsShowInFinder(_ workflow: Workflow, _ state: ModeState) -> Bool {
        guard !workflow.activity.isBatch, let summary = state.lastSummary else { return false }
        return !summary.outputPaths.isEmpty
    }

    /// VoiceOver value of the bar: `2 of 4 complete`.
    public static func progressAccessibilityValue(_ column: ProgressColumn) -> String {
        BatchSummary.progressText(completed: column.completed, total: column.total)
    }
}

// MARK: Folder rows (v2 §3)

public enum FolderDisplay {
    public static let emptyText = "No folder chosen"

    /// The 10.5 pt line under the label: what the folder holds.
    public static func holds(_ role: FolderRole, mode: ScanMode) -> String {
        switch (mode, role) {
        case (.split, .source): return "MKV files"
        case (.split, .output): return ".mka files"
        case (.remux, .video): return ".mkv files"
        case (.remux, .audio): return ".mka files"
        case (.remux, .output): return "Finished .mkv"
        default: return ""
        }
    }

    public static func label(_ role: FolderRole) -> String { "\(role.displayName):" }

    public static func name(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }

    /// The path with the home folder as `~`.
    public static func abbreviated(_ path: String, home: String) -> String {
        guard !home.isEmpty, home != "/" else { return path }
        if path == home { return "~" }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        return path.hasPrefix(prefix) ? "~/" + path.dropFirst(prefix.count) : path
    }

    /// VoiceOver: `Source folder, Rips, ~/Movies/Rips`, or `Source folder, No folder chosen`.
    public static func accessibilityLabel(_ role: FolderRole, path: String?, home: String) -> String {
        guard let path else { return "\(role.displayName) folder, \(emptyText)" }
        return "\(role.displayName) folder, \(name(path)), \(abbreviated(path, home: home))"
    }

    /// `Choose Source folder`.
    public static func chooseLabel(_ role: FolderRole) -> String { "Choose \(role.displayName) folder" }
}

// MARK: Empty states (v2 §4, v2.1 §2.4)

public struct EmptyState: Equatable, Sendable {
    public var title: String
    public var message: String
    /// Shows the `esc Stop Scan` key hint (first scan only).
    public var showsStopScanHint: Bool

    public static func make(_ workflow: Workflow, _ state: ModeState, toolUsable: Bool) -> EmptyState? {
        guard state.rows.isEmpty else { return nil }
        if workflow.activity.isScanning {
            let title = state.mode == .split ? "Scanning the Source folder" : "Scanning the Video and Audio folders"
            return EmptyState(title: title, message: "MKVForge reads each MKV file with mkvmerge. Files appear here when the scan is done.", showsStopScanHint: true)
        }
        if !toolUsable {
            return EmptyState(title: "Can't scan yet", message: "MKVForge needs mkvmerge to scan. Install MKVToolNix or choose mkvmerge in Settings.", showsStopScanHint: false)
        }
        if state.scan != nil {
            let what = state.mode == .split ? "No MKV files in the Source folder." : "No .mkv or .mka files in the Video and Audio folders."
            return EmptyState(title: "No files found", message: what, showsStopScanHint: false)
        }
        if state.hasAllFolders {
            return EmptyState(title: "Ready to scan", message: "Click Scan to read the folders.", showsStopScanHint: false)
        }
        return EmptyState(title: "No files yet", message: "Choose the folders, then click Scan.", showsStopScanHint: false)
    }
}
