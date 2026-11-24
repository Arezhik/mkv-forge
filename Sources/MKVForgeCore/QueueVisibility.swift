import Foundation

// Which queue rows the table draws (layout contract v2.3).
// Show Ready is display-only. Scan, checkboxes, the summary and Run keep the
// full queue. Off shows every row. On hides only rows that display as Issue:
// flagged, and not in an active or finished run (`nil`, `notRun`, `canceled`).
// Waiting, Working, Done, Done · warning, Failed and Ready stay on screen.

public enum QueueVisibility {
    /// `showReady` false shows every row. True hides a row only when it would
    /// display as Issue.
    public static func isVisible(_ row: QueueRow, showReady: Bool) -> Bool {
        guard showReady else { return true }
        return !displaysAsIssue(row)
    }

    /// Rows the table shows, in queue order.
    public static func visibleRows(_ rows: [QueueRow], showReady: Bool) -> [QueueRow] {
        guard showReady else { return rows }
        return rows.filter { isVisible($0, showReady: true) }
    }

    /// True only when Show Ready is on and every row is hidden.
    /// An empty queue counts: nothing is left on screen.
    public static func showsEmptyState(rows: [QueueRow], showReady: Bool) -> Bool {
        guard showReady else { return false }
        return rows.allSatisfy { !isVisible($0, showReady: true) }
    }

    /// Same rule as `RowDisplay`: Issue is flagged plus `nil`, `notRun` or `canceled`.
    /// A later run status replaces Issue, so those rows stay visible.
    private static func displaysAsIssue(_ row: QueueRow) -> Bool {
        guard row.isFlagged else { return false }
        switch row.runStatus {
        case nil, .notRun, .canceled:
            return true
        case .waiting, .working, .done, .doneWithWarning, .failed:
            return false
        }
    }
}
