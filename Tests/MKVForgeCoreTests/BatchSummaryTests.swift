import XCTest
@testable import MKVForgeCore

/// Bottom bar text from docs/design/v1-layout-contract_v2.md §6–§7.
final class BatchSummaryTests: XCTestCase {
    private func summary(_ mode: ScanMode = .split, flagged: Int = 0, statuses: [JobStatus]) -> BatchSummary {
        var summary = BatchSummary(mode: mode, filesInRun: statuses.count, flagged: flagged)
        statuses.forEach { summary.record($0) }
        return summary
    }

    func testZeroCountsAreHidden() {
        XCTAssertEqual(summary(statuses: [.done(outputPath: "/a"), .done(outputPath: "/b")]).text, "Finished · 2 done")
        XCTAssertEqual(summary(flagged: 2, statuses: [.done(outputPath: "/a")]).text, "Finished · 1 done · 2 flagged")
        XCTAssertEqual(summary(statuses: [.failed(reason: "x", detail: "")]).text, "Finished · 1 failed")
    }

    func testWarningsAreAParentheticalOnTheDoneCount() {
        let one = summary(flagged: 2, statuses: [.done(outputPath: "/a"), .doneWithWarning(outputPath: "/b", warnings: []), .done(outputPath: "/c"), .failed(reason: "x", detail: "")])
        XCTAssertEqual(one.text, "Finished · 3 done (1 with warning) · 2 flagged · 1 failed")
        let two = summary(statuses: [.doneWithWarning(outputPath: "/a", warnings: []), .doneWithWarning(outputPath: "/b", warnings: [])])
        XCTAssertEqual(two.text, "Finished · 2 done (2 with warnings)")
    }

    func testAStoppedBatchCountsFinishedFiles() {
        var stopped = summary(statuses: [.done(outputPath: "/a"), .failed(reason: "x", detail: ""), .done(outputPath: "/c"), .notRun])
        stopped.stopped = true
        XCTAssertEqual(stopped.text, "Stopped · 3 of 4 complete")
        XCTAssertEqual(stopped.notRun, 1)
    }

    func testProgressAndSavedCaptions() {
        XCTAssertEqual(BatchSummary.progressText(completed: 2, total: 4), "2 of 4 complete")
        let split = summary(statuses: [.done(outputPath: "/a"), .doneWithWarning(outputPath: "/b", warnings: []), .failed(reason: "x", detail: "")])
        XCTAssertEqual(split.savedText, "2 .mka saved")
        XCTAssertEqual(summary(.remux, statuses: [.done(outputPath: "/a")]).savedText, "1 .mkv saved")
        XCTAssertEqual(JobStatus.working.statusText(mode: .split), "Splitting…")
        XCTAssertEqual(JobStatus.working.statusText(mode: .remux), "Remuxing…")
    }
}
