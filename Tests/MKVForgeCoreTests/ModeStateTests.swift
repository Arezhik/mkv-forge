import XCTest
@testable import MKVForgeCore

final class ModeStateTests: XCTestCase {
    private typealias U = UIFixture

    func testRolesPerMode() {
        XCTAssertEqual(ModeState.roles(for: .split), [.source, .output])
        XCTAssertEqual(ModeState.roles(for: .remux), [.video, .audio, .output])
    }

    func testReadyRowsStartCheckedAndFlaggedRowsCantBeChecked() {
        var state = U.state([U.ready("A"), U.flagged("B")])
        XCTAssertEqual(state.rows.map(\.isChecked), [true, false])
        XCTAssertFalse(state.setChecked("B", true))
        XCTAssertFalse(state.row("B")!.isChecked)
        XCTAssertTrue(state.setChecked("A", false))
        XCTAssertEqual(state.checkedCount, 0)
        XCTAssertEqual(state.flaggedCount, 1)
    }

    func testRescanKeepsAStillReadyRowsCheckbox() {
        var state = U.state([U.ready("A"), U.ready("B"), U.flagged("C")])
        state.setChecked("A", false)
        state.applyScan(U.scan([U.ready("A"), U.ready("B"), U.ready("C"), U.ready("D")]))
        XCTAssertEqual(state.rows.map(\.id), ["A", "B", "C", "D"])
        XCTAssertEqual(state.rows.map(\.isChecked), [false, true, true, true], "A stays unchecked; C was flagged, now Ready, starts checked")
    }

    func testChangingAFolderDropsTheScan() {
        var state = U.state([U.ready("A")])
        state.setFolder("/elsewhere", for: .source)
        XCTAssertNil(state.scan)
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertEqual(state.folder(.source), "/elsewhere")
        state.setFolder("/x", for: .video)
        XCTAssertNil(state.folder(.video), "Split has no Video folder")
    }

    func testSettingTheSameFolderKeepsTheScan() {
        var state = U.state([U.ready("A")])
        state.setFolder("/source", for: .source)
        XCTAssertNotNil(state.scan)
    }

    func testToggleSelectAllAndDeselectAll() {
        var state = U.state([U.ready("A"), U.ready("B"), U.flagged("C")])
        state.toggle(["A", "B"])
        XCTAssertEqual(state.checkedCount, 0)
        state.toggle(["A", "C"])
        XCTAssertEqual(state.checkedIDs, ["A"])
        state.selectAllReady()
        XCTAssertEqual(state.checkedIDs, ["A", "B"])
        state.deselectAll()
        XCTAssertEqual(state.checkedCount, 0)
    }

    func testJobsAreTheCheckedReadyRows() {
        var state = U.state([U.ready("A"), U.ready("B"), U.flagged("C")])
        state.setChecked("B", false)
        XCTAssertEqual(state.jobs().map(\.id), ["A"])
        XCTAssertEqual(ModeState(mode: .split).jobs(), [])
    }

    func testRunStatusesAndFinish() {
        var state = U.state([U.ready("A"), U.ready("B"), U.ready("C"), U.flagged("D")])
        let jobs = state.jobs()
        state.beginRun(jobs)
        XCTAssertEqual(state.rows.map(\.runStatus), [.waiting, .waiting, .waiting, nil])
        state.apply(.started(id: "A", index: 1, total: 3))
        XCTAssertEqual(state.row("A")?.runStatus, .working)
        state.apply(.finished(id: "A", status: .done(outputPath: "/o/A.mka")))
        state.apply(.finished(id: "B", status: .doneWithWarning(outputPath: "/o/B.mka", warnings: ["Warning: x"])))
        state.apply(.finished(id: "C", status: .failed(reason: "r", detail: "d")))
        let summary = U.summary(filesInRun: 3, flagged: 1, [.done(outputPath: "/o/A.mka"), .doneWithWarning(outputPath: "/o/B.mka", warnings: ["Warning: x"]), .failed(reason: "r", detail: "d")])
        state.apply(.batchFinished(summary))
        XCTAssertEqual(state.rows.map(\.isChecked), [false, false, true, false], "Done rows unchecked, Failed stays checked")
        XCTAssertEqual(state.lastSummary, summary)
        XCTAssertEqual(state.jobs().map(\.id), ["C"], "the next run retries only the failed row")
    }

    func testCancelShowsWaitingRowsAsWontStartThenReady() {
        var state = U.state([U.ready("A"), U.ready("B"), U.ready("C")])
        state.beginRun(state.jobs())
        state.apply(.started(id: "A", index: 1, total: 3))
        state.markCancelling()
        XCTAssertEqual(state.rows.map(\.wontStart), [false, true, true])
        state.apply(.finished(id: "A", status: .done(outputPath: "/o/A.mka")))
        state.apply(.finished(id: "B", status: .notRun))
        XCTAssertNil(state.row("B")?.runStatus)
        XCTAssertFalse(state.row("B")!.wontStart)
        state.apply(.finished(id: "C", status: .notRun))
        state.apply(.batchFinished(U.summary(filesInRun: 3, [.done(outputPath: "/o/A.mka"), .notRun, .notRun], stopped: true)))
        XCTAssertEqual(state.rows.map(\.isChecked), [false, true, true])
        XCTAssertEqual(state.rows.map(\.runStatus), [.done(outputPath: "/o/A.mka"), nil, nil])
        XCTAssertTrue(state.lastSummary?.stopped ?? false)
    }

    /// Cancel after one file finishes, then run again: the finished row stays finished
    /// and unchecked, and only the remaining Ready rows go Waiting (#30).
    func testResumeAfterCancelKeepsFinishedRows() {
        func resume(keeping status: JobStatus, output: String) {
            var state = U.state([U.ready("A"), U.ready("B"), U.ready("C")])
            state.beginRun(state.jobs())
            state.apply(.finished(id: "A", status: status))
            state.markCancelling()
            state.apply(.finished(id: "B", status: .notRun))
            state.apply(.finished(id: "C", status: .notRun))
            state.finishBatch(U.summary(filesInRun: 3, [status, .notRun, .notRun], stopped: true))
            XCTAssertEqual(state.row("A")?.runStatus, status)
            XCTAssertFalse(state.row("A")!.isChecked)
            XCTAssertNotNil(state.lastSummary)

            let jobs = state.jobs()
            XCTAssertEqual(jobs.map(\.id), ["B", "C"])
            XCTAssertFalse(jobs.map(\.outputPath).contains(output))
            state.beginRun(jobs)
            XCTAssertNil(state.lastSummary)
            XCTAssertEqual(state.row("A")?.runStatus, status)
            XCTAssertFalse(state.row("A")!.isChecked)
            XCTAssertEqual(state.row("B")?.runStatus, .waiting)
            XCTAssertEqual(state.row("C")?.runStatus, .waiting)
            XCTAssertFalse(state.rows.contains(where: \.wontStart))
            XCTAssertEqual(state.jobs().map(\.outputPath), ["/o/B.mka", "/o/C.mka"])
        }

        resume(keeping: .done(outputPath: "/o/A.mka"), output: "/o/A.mka")
        resume(
            keeping: .doneWithWarning(outputPath: "/o/A.mka", warnings: ["Warning: x"]),
            output: "/o/A.mka"
        )
    }

    func testANewScanOrRunClearsTheLastSummary() {
        var state = U.state([U.ready("A")])
        state.beginRun(state.jobs())
        state.finishBatch(U.summary(filesInRun: 1, [.done(outputPath: "/o/A.mka")]))
        XCTAssertNotNil(state.lastSummary)
        state.beginRun([])
        XCTAssertNil(state.lastSummary)
        state.finishBatch(U.summary(filesInRun: 1, [.done(outputPath: "/o/A.mka")]))
        state.applyScan(U.scan([U.ready("A")]))
        XCTAssertNil(state.lastSummary)
    }
}
