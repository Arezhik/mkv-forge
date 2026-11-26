import Foundation

// What the window is doing, and what that allows (layout contract v2 §2, §3, §6, §11;
// v2.1 §1, §2.1). Rules:
// - Idle, scanning, running, cancelling. Finished and stopped are idle with a summary.
// - While scanning, running or cancelling: the mode switch, Choose…, the folder fields'
//   menus, Scan, the checkboxes and Select All Ready / Deselect All are disabled.
// - Scan needs every folder of the mode and a working mkvmerge.
// - The primary action needs a scan, a working mkvmerge and at least one checked row.
//   While running it is Cancel; after Cancel it is a disabled Cancelling….
// - Finish Current File (G1) is Cancel plus "quit when the batch stops".
// - Menus read only `CommandFlags`, which the app publishes only when they change (L9).

public enum Activity: Equatable, Sendable {
    case idle
    case scanning(ScanProgress)
    case running
    case cancelling

    public var isScanning: Bool { if case .scanning = self { return true } else { return false } }
    /// A batch is running or cancelling (the G1 alert applies).
    public var isBatch: Bool { self == .running || self == .cancelling }
    public var isBusy: Bool { self != .idle }
}

/// The running batch: files completed out of the files in the run, and the current file.
public struct BatchProgress: Equatable, Sendable {
    public let mode: ScanMode
    public let total: Int
    public var completed = 0
    public var currentName: String?
    /// Time remaining for the file that is running. Empty when the estimate is hidden.
    public var etaCaption = ""

    public init(mode: ScanMode, total: Int) {
        self.mode = mode
        self.total = total
    }

    /// Counts a finished file (Done, Done · warning or Failed), as `BatchSummary.completed` does.
    public mutating func apply(_ event: RunEvent) {
        switch event {
        case let .started(id, _, _):
            currentName = id
            etaCaption = ""
        case let .progress(caption):
            etaCaption = caption
        case let .finished(_, status):
            switch status {
            case .done, .doneWithWarning, .failed: completed += 1
            case .waiting, .working, .notRun, .canceled: break
            }
            etaCaption = ""
        case .batchFinished:
            currentName = nil
            etaCaption = ""
        }
    }
}

/// The toolbar's primary slot (v2 §6).
public enum PrimaryAction: Equatable, Sendable {
    case run(title: String, systemImage: String)
    case cancel
    case cancelling

    public static func run(for mode: ScanMode) -> PrimaryAction {
        switch mode {
        case .split: return .run(title: "Split", systemImage: "scissors")
        case .remux: return .run(title: "Remux", systemImage: "arrow.triangle.merge")
        }
    }

    public var title: String {
        switch self {
        case let .run(title, _): return title
        case .cancel: return "Cancel"
        case .cancelling: return "Cancelling…"
        }
    }

    public var systemImage: String? {
        switch self {
        case let .run(_, image): return image
        case .cancel: return "stop.fill"
        case .cancelling: return nil
        }
    }
}

/// What's enabled, with the reason when it isn't (`.help`).
public struct Enablement: Equatable, Sendable {
    public var modeSwitch: Bool
    public var chooseFolders: Bool
    public var folderMenus: Bool
    public var scan: Bool
    public var scanHelp: String?
    public var checkboxes: Bool
    public var selectAll: Bool
    public var primary: Bool
    public var primaryHelp: String?
}

/// The few values menu commands depend on. The app publishes these only when one changes,
/// so open menus don't rebuild on every progress tick (L9, L11).
public struct CommandFlags: Equatable, Sendable {
    public var mode: ScanMode = .split
    public var canSwitchMode = true
    public var canScan = false
    public var isScanning = false
    public var canRun = false
    public var runTitle = "Split"
    public var canCancel = false
    public var isCancelling = false
    public var canSelect = false
    /// A batch is running or cancelling.
    public var hasActiveWork = false

    public init() {}
}

public struct Workflow: Equatable, Sendable {
    public var activity: Activity = .idle
    public var batch: BatchProgress?
    /// Finish Current File was chosen: quit when the batch stops (v2.1 §1.4–§1.5).
    public private(set) var quitAfterStop = false

    public init() {}

    public static let needsMKVToolNix = "Needs MKVToolNix"
    public static let needsFolders = "Choose every folder first"
    public static let needsScan = "Scan the folders first"
    public static let needsChecked = "Check at least one file"
    /// Nothing is checked, and at least one row is still an Ambiguous match (v2.2 §B.7).
    public static let needsMatchOrCheck = "Choose a match or check a Ready row."
    public static let busyHelp = "Wait for the current scan or batch to end"

    public func enablement(_ state: ModeState, toolUsable: Bool) -> Enablement {
        let busy = activity.isBusy
        let scanHelp: String?
        if busy { scanHelp = Self.busyHelp }
        else if !state.hasAllFolders { scanHelp = Self.needsFolders }
        else if !toolUsable { scanHelp = Self.needsMKVToolNix }
        else { scanHelp = nil }
        let primaryHelp: String?
        switch activity {
        case .running, .cancelling: primaryHelp = nil
        case .scanning: primaryHelp = Self.busyHelp
        case .idle:
            if !toolUsable { primaryHelp = Self.needsMKVToolNix }
            else if state.scan == nil { primaryHelp = Self.needsScan }
            else if state.checkedCount == 0 {
                primaryHelp = state.hasAmbiguousMatch ? Self.needsMatchOrCheck : Self.needsChecked
            } else { primaryHelp = nil }
        }
        let primary: Bool
        switch activity {
        case .running: primary = true
        case .cancelling, .scanning: primary = false
        case .idle: primary = primaryHelp == nil
        }
        return Enablement(
            modeSwitch: !busy,
            chooseFolders: !busy,
            folderMenus: !busy,
            scan: scanHelp == nil,
            scanHelp: scanHelp,
            checkboxes: !busy,
            selectAll: !busy && !state.rows.isEmpty,
            primary: primary,
            primaryHelp: primaryHelp
        )
    }

    public func primaryAction(_ mode: ScanMode) -> PrimaryAction {
        switch activity {
        case .running: return .cancel
        case .cancelling: return .cancelling
        case .idle, .scanning: return .run(for: mode)
        }
    }

    public func commandFlags(_ state: ModeState, toolUsable: Bool) -> CommandFlags {
        let e = enablement(state, toolUsable: toolUsable)
        var flags = CommandFlags()
        flags.mode = state.mode
        flags.canSwitchMode = e.modeSwitch
        flags.canScan = e.scan
        flags.isScanning = activity.isScanning
        flags.canRun = activity == .idle && e.primary
        flags.runTitle = state.mode.displayName
        flags.canCancel = activity == .running
        flags.isCancelling = activity == .cancelling
        flags.canSelect = e.selectAll
        flags.hasActiveWork = activity.isBatch
        return flags
    }

    // MARK: Transitions

    /// Scan clicked. False when a scan can't start now.
    public mutating func startScan() -> Bool {
        guard activity == .idle else { return false }
        activity = .scanning(.listing)
        return true
    }

    public mutating func scanProgress(_ progress: ScanProgress) {
        guard activity.isScanning else { return }
        activity = .scanning(progress)
    }

    /// The scan ended (finished, failed or stopped with Esc).
    public mutating func scanEnded() {
        if activity.isScanning { activity = .idle }
    }

    /// Split/Remux clicked with `total` jobs.
    public mutating func startRun(mode: ScanMode, total: Int) -> Bool {
        guard activity == .idle, total > 0 else { return false }
        activity = .running
        batch = BatchProgress(mode: mode, total: total)
        quitAfterStop = false
        return true
    }

    public mutating func apply(_ event: RunEvent) {
        batch?.apply(event)
    }

    /// Cancel (⌘. or Esc): finish the current file, then stop. False if not running.
    public mutating func cancel() -> Bool {
        guard activity == .running else { return false }
        activity = .cancelling
        return true
    }

    /// G1 Finish Current File: Cancel if still running, and quit when the batch stops.
    /// Returns true when the runner still needs `requestStop()`.
    public mutating func finishThenQuit() -> Bool {
        guard activity.isBatch else { return false }
        quitAfterStop = true
        return cancel()
    }

    /// The batch ended. Returns what to do next.
    public mutating func batchEnded(_ summary: BatchSummary, appIsActive: Bool, notifyOn: Bool, bounceOn: Bool) -> BatchEndAction {
        let quit = quitAfterStop
        activity = .idle
        batch = nil
        quitAfterStop = false
        if quit { return .quitQuietly }
        return .feedback(BatchEndFeedback.decide(summary: summary, appIsActive: appIsActive, notifyOn: notifyOn, bounceOn: bounceOn))
    }
}

public enum BatchEndAction: Equatable, Sendable {
    /// Finish Current File was chosen: quit now, with no Stopped bar, notification or bounce.
    case quitQuietly
    case feedback(BatchEndFeedback)
}
