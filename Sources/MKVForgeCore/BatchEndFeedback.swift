import Foundation

// Batch end (layout contract v2 §7, §13; v2.1 §1.5). Rules:
// - Only after a normal finish, never after a completed Cancel or a quit.
// - Only when MKVForge is in the background. Each has its own Settings switch (on by default).
// - Notification: title `Batch finished`, body = the summary string. Dock: bounce once.

public struct BatchEndFeedback: Equatable, Sendable {
    public var notify: Bool
    public var bounce: Bool
    public var title: String
    public var body: String

    public static let notificationTitle = "Batch finished"

    public static func decide(summary: BatchSummary, appIsActive: Bool, notifyOn: Bool, bounceOn: Bool) -> BatchEndFeedback {
        let allowed = !summary.stopped && !appIsActive
        return BatchEndFeedback(
            notify: allowed && notifyOn,
            bounce: allowed && bounceOn,
            title: notificationTitle,
            body: summary.text
        )
    }
}
