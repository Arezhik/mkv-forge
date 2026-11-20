import Foundation

// Quitting or closing the window while a batch runs (layout contract v2.1 §1). Rules:
// - Idle, scanned, scanning, stopped, finished: quit right away, no alert. A scan just stops.
// - Running, cancelling, or already quitting after Finish Current File: the alert
//   `A batch is running`, as a sheet on the main window, with the running or the
//   cancelling text. Buttons top to bottom: Finish Current File (default, Return),
//   Quit (destructive, no key), Cancel (Esc, ⌘.). Warning style, no suppression box.
// - Finish Current File: answer "don't quit" now, Cancel the batch (v2's Cancelling
//   state) and quit quietly when it stops. Never hold the quit for a whole file.
// - Quit: hard stop (kill mkvmerge, delete the unfinished file), then quit.
// - Cancel: nothing changes; a pending quit stays pending.

public struct QuitAlert: Equatable, Sendable {
    public var title: String
    public var message: String
    public var buttons: [String]
}

public enum QuitDecision: Equatable, Sendable {
    case quitNow
    case ask(QuitAlert)
}

public enum QuitChoice: Equatable, Sendable {
    case finishCurrentFile
    case quit
    case cancel

    /// NSAlert buttons in order: 0 = Finish Current File, 1 = Quit, 2 = Cancel.
    public init(buttonIndex: Int) {
        switch buttonIndex {
        case 0: self = .finishCurrentFile
        case 1: self = .quit
        default: self = .cancel
        }
    }
}

public enum QuitFlow {
    public static let title = "A batch is running"
    public static let buttons = ["Finish Current File", "Quit", "Cancel"]
    public static let nameLimit = 40
    public static let willQuitAnnouncement = "MKVForge will quit after this file."
    static let tail = "Choose Finish Current File to quit when it’s done, or Quit to stop now and delete its unfinished file. Files that are already finished are kept."

    public static func decide(_ workflow: Workflow) -> QuitDecision {
        guard workflow.activity.isBatch else { return .quitNow }
        let mode = workflow.batch?.mode ?? .split
        let name = workflow.batch?.currentName
        let cancelling = workflow.activity == .cancelling || workflow.quitAfterStop
        return .ask(alert(mode: mode, currentName: name, cancelling: cancelling))
    }

    public static func alert(mode: ScanMode, currentName: String?, cancelling: Bool) -> QuitAlert {
        let file = currentName.map { "“\(middleTruncate($0))”" } ?? "the current file"
        let message: String
        if cancelling {
            message = "MKVForge is finishing \(file), then stopping. \(tail)"
        } else {
            message = "MKVForge is \(mode == .split ? "splitting" : "remuxing") \(file). \(tail)"
        }
        return QuitAlert(title: title, message: message, buttons: buttons)
    }

    /// Shortens a long name in the middle to `limit` characters (NSAlert wraps, never truncates).
    public static func middleTruncate(_ text: String, limit: Int = nameLimit) -> String {
        guard text.count > limit, limit > 1 else { return text }
        let keep = limit - 1
        let head = keep / 2
        let tail = keep - head
        return String(text.prefix(head)) + "…" + String(text.suffix(tail))
    }
}
