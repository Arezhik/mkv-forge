import XCTest
@testable import MKVForgeCore

final class QueueVisibilityTests: XCTestCase {
    private func ready(_ name: String, _ status: JobStatus? = nil) -> QueueRow {
        QueueRow(item: UIFixture.ready(name), isChecked: true, runStatus: status)
    }

    private func issue(_ name: String, _ status: JobStatus? = nil) -> QueueRow {
        QueueRow(item: UIFixture.flagged(name), isChecked: false, runStatus: status)
    }

    func testOffShowsEveryRow() {
        let rows = [issue("Empty"), ready("Sample"), ready("Done", .done(outputPath: "/o/Done.mka"))]
        XCTAssertEqual(QueueVisibility.visibleRows(rows, showReady: false), rows)
        XCTAssertTrue(rows.allSatisfy { QueueVisibility.isVisible($0, showReady: false) })
    }

    func testOnHidesIssueAndKeepsReady() {
        let rows = [issue("Empty"), ready("Sample")]
        let visible = QueueVisibility.visibleRows(rows, showReady: true)
        XCTAssertEqual(visible.map(\.baseName), ["Sample"])
        XCTAssertFalse(QueueVisibility.isVisible(rows[0], showReady: true))
        XCTAssertTrue(QueueVisibility.isVisible(rows[1], showReady: true))
    }

    func testOnKeepsDoneWarningAndFailed() {
        let done = ready("Done", .done(outputPath: "/o/Done.mka"))
        let warning = ready("Warn", .doneWithWarning(outputPath: "/o/Warn.mka", warnings: ["Warning: x"]))
        let failed = ready("Fail", .failed(reason: "mkvmerge failed", detail: "exit 2"))
        // A finished status replaces Issue, even when the scan item is still flagged.
        let flaggedDone = issue("FlagDone", .done(outputPath: "/o/FlagDone.mka"))
        let rows = [issue("Empty"), done, warning, failed, flaggedDone]
        XCTAssertEqual(
            QueueVisibility.visibleRows(rows, showReady: true).map(\.baseName),
            ["Done", "Warn", "Fail", "FlagDone"]
        )
    }

    func testOnKeepsActiveReadyAndNonIssueTerminalRows() {
        let waiting = ready("Wait", .waiting)
        let working = ready("Work", .working)
        let notRun = ready("Again", .notRun)
        let canceled = ready("Hard", .canceled)
        // Flagged + not started is Issue. Flagged + Waiting is still Waiting.
        let notRunIssue = issue("Skip", .notRun)
        let canceledIssue = issue("Stop", .canceled)
        let flaggedWaiting = issue("FlagWait", .waiting)
        let rows = [waiting, working, notRun, canceled, notRunIssue, canceledIssue, flaggedWaiting, issue("Empty")]
        XCTAssertEqual(
            QueueVisibility.visibleRows(rows, showReady: true).map(\.baseName),
            ["Wait", "Work", "Again", "Hard", "FlagWait"]
        )
    }

    func testShowsEmptyStateOnlyWhenOnAndEveryRowIsHidden() {
        let issues = [issue("A"), issue("B")]
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: issues, showReady: false))
        XCTAssertTrue(QueueVisibility.showsEmptyState(rows: issues, showReady: true))
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: [], showReady: false))
        XCTAssertTrue(QueueVisibility.showsEmptyState(rows: [], showReady: true))
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: [ready("C")], showReady: true))
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: issues + [ready("C")], showReady: true))
        let done = ready("D", .done(outputPath: "/o/D.mka"))
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: issues + [done], showReady: true))
    }

    func testMixedQueueKeepsReadyAndTerminalRows() {
        let rows = [
            issue("Empty"),
            ready("Sample"),
            ready("Done", .done(outputPath: "/o/Done.mka")),
            ready("Warn", .doneWithWarning(outputPath: "/o/Warn.mka", warnings: ["Warning: late"])),
            ready("Fail", .failed(reason: "mkvmerge failed", detail: "")),
            issue("Other"),
        ]
        XCTAssertEqual(
            QueueVisibility.visibleRows(rows, showReady: true).map(\.baseName),
            ["Sample", "Done", "Warn", "Fail"]
        )
        XCTAssertFalse(QueueVisibility.showsEmptyState(rows: rows, showReady: true))
    }
}
