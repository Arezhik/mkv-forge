import Foundation

// How one queue row looks (layout contract v2 §4, §11). Rules:
// - Status is always a symbol plus a word, never color alone.
// - Ready `chevron.forward.circle` (secondary icon); Issue `exclamationmark.triangle`
//   (orange, outline); Waiting `clock`; Splitting…/Remuxing… a small spinner, no per-file
//   %; Done `checkmark.circle.fill` (green); Done · warning `exclamationmark.triangle.fill`
//   (yellow icon); Failed `xmark.octagon.fill` (red).
// - Reason: the issue, the first mkvmerge warning line with `(+N more)`, or the error;
//   a Ready row shows its scan note (`Uses video only, …`); `—` when there's none. The
//   help tag holds the full text.
// - Flagged rows: checkbox unchecked and disabled, `.help("Flagged: <reason>")`, full contrast.
// - VoiceOver: one element `<name>, <status>, <reason>`; checkbox `Include <name>`.

/// System semantic colors the app maps to SwiftUI colors.
public enum StatusTint: String, Equatable, Sendable {
    case secondary, orange, yellow, green, red, accent
}

public struct RowDisplay: Equatable, Sendable {
    public static let noReason = "—"

    public var name: String
    /// Full file name for the Name column's help tag.
    public var nameHelp: String
    /// Nil while the row shows the spinner.
    public var symbol: String?
    public var showsSpinner: Bool
    public var statusText: String
    public var tint: StatusTint
    public var reason: String
    public var reasonHelp: String?
    public var checkboxEnabled: Bool
    public var checkboxLabel: String
    public var checkboxHelp: String?
    /// VoiceOver label for the whole row.
    public var accessibilityLabel: String
    /// VoiceOver label for the row spinner: `Splitting` / `Remuxing`.
    public var spinnerLabel: String?
    /// True for Done rows: their context menu has Show in Finder.
    public var outputPath: String?

    /// `locked` is true while scanning, running or cancelling (checkboxes disabled).
    public init(_ row: QueueRow, mode: ScanMode, locked: Bool) {
        name = row.baseName
        nameHelp = row.item.sourcePath.map { ($0 as NSString).lastPathComponent } ?? row.baseName
        showsSpinner = false
        spinnerLabel = nil
        outputPath = nil
        var reasonText: String?
        switch row.runStatus {
        case nil, .notRun?, .canceled?:
            if row.isFlagged {
                symbol = "exclamationmark.triangle"
                statusText = "Issue"
                tint = .orange
                reasonText = row.item.reasonText
                reasonHelp = row.item.helpText ?? row.item.reasonText
            } else if row.runStatus == .canceled {
                symbol = "xmark.circle"
                statusText = JobStatus.canceled.statusText(mode: mode)
                tint = .secondary
                reasonHelp = nil
            } else {
                symbol = "chevron.forward.circle"
                statusText = "Ready"
                tint = .secondary
                reasonText = row.item.reasonText
                reasonHelp = row.item.helpText
            }
        case .waiting?:
            if row.wontStart {
                symbol = "chevron.forward.circle"
                statusText = "Ready"
                tint = .secondary
                reasonText = JobStatus.wontStartReason
                reasonHelp = JobStatus.wontStartReason
            } else {
                symbol = "clock"
                statusText = "Waiting"
                tint = .secondary
                reasonHelp = nil
            }
        case .working?:
            symbol = nil
            showsSpinner = true
            statusText = JobStatus.working.statusText(mode: mode)
            spinnerLabel = mode == .split ? "Splitting" : "Remuxing"
            tint = .accent
            reasonHelp = nil
        case let .done(path)?:
            symbol = "checkmark.circle.fill"
            statusText = "Done"
            tint = .green
            reasonHelp = nil
            outputPath = path
        case let .doneWithWarning(path, warnings)?:
            symbol = "exclamationmark.triangle.fill"
            statusText = "Done · warning"
            tint = .yellow
            reasonText = MKVMergeOutput.warningReason(warnings)
            reasonHelp = MKVMergeOutput.warningHelp(warnings)
            outputPath = path
        case let .failed(why, detail)?:
            symbol = "xmark.octagon.fill"
            statusText = "Failed"
            tint = .red
            reasonText = why
            reasonHelp = detail.isEmpty ? why : detail
        }
        reason = reasonText ?? Self.noReason
        checkboxEnabled = !locked && !row.isFlagged
        checkboxLabel = "Include \(row.baseName)"
        checkboxHelp = row.isFlagged ? "Flagged: \(row.item.reasonText ?? "")" : nil
        let status = statusText
        if let reasonText {
            accessibilityLabel = "\(row.baseName), \(status), \(reasonText)"
        } else {
            accessibilityLabel = "\(row.baseName), \(status)"
        }
    }
}
