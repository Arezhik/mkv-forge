import XCTest
@testable import MKVForgeCore

final class RowDisplayTests: XCTestCase {
    private typealias U = UIFixture

    private func row(_ item: ScanItem, _ status: JobStatus? = nil, checked: Bool = true) -> QueueRow {
        QueueRow(item: item, isChecked: checked, runStatus: status)
    }

    func testReadyRow() {
        let d = RowDisplay(row(U.ready("A")), mode: .split, locked: false)
        XCTAssertEqual(d.symbol, "chevron.forward.circle")
        XCTAssertEqual(d.statusText, "Ready")
        XCTAssertEqual(d.tint, .secondary)
        XCTAssertEqual(d.reason, "—")
        XCTAssertNil(d.reasonHelp)
        XCTAssertTrue(d.checkboxEnabled)
        XCTAssertEqual(d.checkboxLabel, "Include A")
        XCTAssertNil(d.checkboxHelp)
        XCTAssertEqual(d.accessibilityLabel, "A, Ready")
        XCTAssertEqual(d.nameHelp, "A.mkv")
        XCTAssertNil(d.outputPath)
    }

    func testFlaggedRowIsOrangeAndCantBeChecked() {
        let item = U.flagged("B", [.outputExists(fileName: "B.mka")])
        let d = RowDisplay(row(item, checked: false), mode: .split, locked: false)
        XCTAssertEqual(d.symbol, "exclamationmark.triangle")
        XCTAssertEqual(d.statusText, "Issue")
        XCTAssertEqual(d.tint, .orange)
        let reason = try? XCTUnwrap(item.reasonText)
        XCTAssertEqual(d.reason, reason)
        XCTAssertFalse(d.checkboxEnabled)
        XCTAssertEqual(d.checkboxHelp, "Flagged: \(reason ?? "")")
        XCTAssertEqual(d.accessibilityLabel, "B, Issue, \(reason ?? "")")
    }

    func testLockedRowsDisableTheCheckbox() {
        XCTAssertFalse(RowDisplay(row(U.ready("A")), mode: .split, locked: true).checkboxEnabled)
    }

    func testWaitingAndWontStart() {
        var r = row(U.ready("A"), .waiting)
        XCTAssertEqual(RowDisplay(r, mode: .split, locked: true).symbol, "clock")
        XCTAssertEqual(RowDisplay(r, mode: .split, locked: true).statusText, "Waiting")
        r.wontStart = true
        let d = RowDisplay(r, mode: .split, locked: true)
        XCTAssertEqual(d.statusText, "Ready")
        XCTAssertEqual(d.reason, JobStatus.wontStartReason)
    }

    func testWorkingShowsASpinnerWithoutASymbol() {
        let split = RowDisplay(row(U.ready("A"), .working), mode: .split, locked: true)
        XCTAssertNil(split.symbol)
        XCTAssertTrue(split.showsSpinner)
        XCTAssertEqual(split.statusText, "Splitting…")
        XCTAssertEqual(split.spinnerLabel, "Splitting")
        let remux = RowDisplay(row(U.ready("A", mode: .remux), .working), mode: .remux, locked: true)
        XCTAssertEqual(remux.statusText, "Remuxing…")
        XCTAssertEqual(remux.spinnerLabel, "Remuxing")
    }

    func testDoneRowsCarryTheirOutput() {
        let d = RowDisplay(row(U.ready("A"), .done(outputPath: "/o/A.mka")), mode: .split, locked: false)
        XCTAssertEqual(d.symbol, "checkmark.circle.fill")
        XCTAssertEqual(d.tint, .green)
        XCTAssertEqual(d.outputPath, "/o/A.mka")
        XCTAssertEqual(d.reason, "—")
    }

    func testDoneWithWarningsShowsTheFirstLineAndCount() {
        let warnings = ["Warning: first thing", "Warning: second thing", "Warning: third"]
        let d = RowDisplay(row(U.ready("A"), .doneWithWarning(outputPath: "/o/A.mka", warnings: warnings)), mode: .split, locked: false)
        XCTAssertEqual(d.symbol, "exclamationmark.triangle.fill")
        XCTAssertEqual(d.tint, .yellow)
        XCTAssertEqual(d.statusText, "Done · warning")
        XCTAssertEqual(d.reason, MKVMergeOutput.warningReason(warnings))
        XCTAssertTrue(d.reason.contains("(+2 more)"), d.reason)
        XCTAssertEqual(d.reasonHelp, MKVMergeOutput.warningHelp(warnings))
    }

    func testFailedRowShowsTheReasonWithDetailInHelp() {
        let d = RowDisplay(row(U.ready("A"), .failed(reason: "mkvmerge stopped", detail: "Error: x")), mode: .split, locked: false)
        XCTAssertEqual(d.symbol, "xmark.octagon.fill")
        XCTAssertEqual(d.tint, .red)
        XCTAssertEqual(d.reason, "mkvmerge stopped")
        XCTAssertEqual(d.reasonHelp, "Error: x")
        let noDetail = RowDisplay(row(U.ready("A"), .failed(reason: "r", detail: "")), mode: .split, locked: false)
        XCTAssertEqual(noDetail.reasonHelp, "r")
        XCTAssertEqual(noDetail.accessibilityLabel, "A, Failed, r")
    }
}

final class StatusLinesTests: XCTestCase {
    private typealias U = UIFixture

    func testIdleSummaryHidesZeroFlagged() {
        var state = U.state([U.ready("A"), U.ready("B"), U.flagged("C")])
        XCTAssertEqual(StatusLines.summary(Workflow(), state), SummaryText(bold: "3 files", rest: " · 2 selected · 1 flagged"))
        state = U.state([U.ready("A")])
        XCTAssertEqual(StatusLines.summary(Workflow(), state).plain, "1 file · 1 selected")
        XCTAssertEqual(StatusLines.summary(Workflow(), U.state([U.ready("A", mode: .remux)], mode: .remux)).plain, "1 name · 1 selected")
        XCTAssertEqual(StatusLines.summary(Workflow(), ModeState(mode: .split)).plain, "No files")
    }

    func testRunningAndCancellingSummaries() {
        var w = Workflow()
        let state = U.state([U.ready("A"), U.ready("B"), U.ready("C"), U.ready("D")])
        _ = w.startRun(mode: .split, total: 4)
        w.apply(.started(id: "A", index: 1, total: 4))
        w.apply(.finished(id: "A", status: .done(outputPath: "/o/A.mka")))
        w.apply(.finished(id: "B", status: .done(outputPath: "/o/B.mka")))
        w.apply(.started(id: "C", index: 3, total: 4))
        XCTAssertEqual(StatusLines.summary(w, state), SummaryText(bold: "2 of 4 complete", rest: " · Splitting C"))
        XCTAssertEqual(StatusLines.subtitle(w, state, toolUsable: true), "Splitting · 2 of 4 complete")
        XCTAssertEqual(StatusLines.progressColumn(w, state), ProgressColumn(completed: 2, total: 4, caption: ""))
        _ = w.cancel()
        XCTAssertEqual(StatusLines.summary(w, state), SummaryText(bold: "Finishing C, then stopping", rest: " · 2 of 4 complete"))
        XCTAssertEqual(StatusLines.subtitle(w, state, toolUsable: true), "Cancelling · finishing current file")
    }

    func testFinishedSummaryHidesZeroCounts() {
        var state = U.state([U.ready("A"), U.ready("B"), U.ready("C"), U.ready("D"), U.flagged("E"), U.flagged("F")])
        state.beginRun(state.jobs())
        let summary = U.summary(filesInRun: 4, flagged: 2, [.done(outputPath: "/o/A.mka"), .done(outputPath: "/o/B.mka"),
                                                            .doneWithWarning(outputPath: "/o/C.mka", warnings: ["w"]), .failed(reason: "r", detail: "")])
        state.finishBatch(summary)
        XCTAssertEqual(StatusLines.summary(Workflow(), state), SummaryText(bold: "Finished", rest: " · 3 done (1 with warning) · 2 flagged · 1 failed"))
        XCTAssertEqual(StatusLines.subtitle(Workflow(), state, toolUsable: true), "Finished · 3 of 4 succeeded")
        XCTAssertEqual(StatusLines.progressColumn(Workflow(), state), ProgressColumn(completed: 4, total: 4, caption: "3 .mka saved"))
        XCTAssertTrue(StatusLines.showsShowInFinder(Workflow(), state))

        var clean = U.state([U.ready("A")])
        clean.beginRun(clean.jobs())
        clean.finishBatch(U.summary(filesInRun: 1, [.done(outputPath: "/o/A.mka")]))
        XCTAssertEqual(StatusLines.summary(Workflow(), clean).plain, "Finished · 1 done")
    }

    func testStoppedHasNoProgressColumn() {
        var state = U.state([U.ready("A"), U.ready("B")])
        state.beginRun(state.jobs())
        state.finishBatch(U.summary(filesInRun: 2, [.done(outputPath: "/o/A.mka"), .notRun], stopped: true))
        XCTAssertEqual(StatusLines.summary(Workflow(), state), SummaryText(bold: "Stopped", rest: " · 1 of 2 complete"))
        XCTAssertEqual(StatusLines.subtitle(Workflow(), state, toolUsable: true), "Stopped · 1 of 2 complete")
        XCTAssertNil(StatusLines.progressColumn(Workflow(), state))
        XCTAssertTrue(StatusLines.showsShowInFinder(Workflow(), state), "a Cancel that wrote a file")
    }

    func testStoppedWithNothingWrittenHidesShowInFinder() {
        var state = U.state([U.ready("A")])
        state.beginRun(state.jobs())
        state.finishBatch(U.summary(filesInRun: 1, [.notRun], stopped: true))
        XCTAssertFalse(StatusLines.showsShowInFinder(Workflow(), state))
    }

    func testReScanKeepsThePreviousSummary() {
        var w = Workflow()
        let state = U.state([U.ready("A"), U.flagged("B")])
        _ = w.startScan()
        XCTAssertEqual(StatusLines.summary(w, state).plain, "2 files · 1 selected · 1 flagged")
        XCTAssertEqual(StatusLines.subtitle(w, state, toolUsable: true), "Split · Scanning…")
        XCTAssertNil(StatusLines.progressColumn(w, state))
    }

    func testIdleSubtitles() {
        XCTAssertEqual(StatusLines.subtitle(Workflow(), ModeState(mode: .remux), toolUsable: false), "Remux · MKVToolNix not found")
        XCTAssertEqual(StatusLines.subtitle(Workflow(), ModeState(mode: .remux), toolUsable: true), "Remux")
        var state = U.state([U.ready("A"), U.ready("B")])
        state.setChecked("B", false)
        XCTAssertEqual(StatusLines.subtitle(Workflow(), state, toolUsable: true), "Split · 1 of 2 selected")
    }

    func testBannerAndAccessibilityStrings() {
        XCTAssertEqual(StatusLines.toolMissingBanner, "MKVToolNix wasn't found.")
        XCTAssertEqual(StatusLines.downloadURL, "https://mkvtoolnix.download/")
        XCTAssertEqual(StatusLines.progressAccessibilityValue(ProgressColumn(completed: 2, total: 4, caption: "")), "2 of 4 complete")
    }
}

final class FolderDisplayTests: XCTestCase {
    func testLabelsAndHolds() {
        XCTAssertEqual(FolderDisplay.label(.source), "Source:")
        XCTAssertEqual(FolderDisplay.holds(.source, mode: .split), "MKV files")
        XCTAssertEqual(FolderDisplay.holds(.output, mode: .split), ".mka files")
        XCTAssertEqual(FolderDisplay.holds(.output, mode: .remux), "Finished .mkv")
        XCTAssertEqual(FolderDisplay.chooseLabel(.audio), "Choose Audio folder")
        XCTAssertEqual(FolderDisplay.emptyText, "No folder chosen")
    }

    func testAbbreviatedPathsUseTilde() {
        XCTAssertEqual(FolderDisplay.abbreviated("/Users/a/Movies/Rips", home: "/Users/a"), "~/Movies/Rips")
        XCTAssertEqual(FolderDisplay.abbreviated("/Users/a", home: "/Users/a"), "~")
        XCTAssertEqual(FolderDisplay.abbreviated("/Users/ab/x", home: "/Users/a"), "/Users/ab/x")
        XCTAssertEqual(FolderDisplay.abbreviated("/Volumes/Media", home: "/Users/a"), "/Volumes/Media")
    }

    func testAccessibilityLabels() {
        XCTAssertEqual(FolderDisplay.accessibilityLabel(.source, path: "/Users/a/Movies/Rips", home: "/Users/a"), "Source folder, Rips, ~/Movies/Rips")
        XCTAssertEqual(FolderDisplay.accessibilityLabel(.video, path: nil, home: "/Users/a"), "Video folder, No folder chosen")
    }
}

final class EmptyStateTests: XCTestCase {
    private typealias U = UIFixture

    func testFirstScanShowsTheStopHint() {
        var w = Workflow()
        var state = ModeState(mode: .split)
        state.setFolder("/s", for: .source)
        state.setFolder("/o", for: .output)
        _ = w.startScan()
        let empty = EmptyState.make(w, state, toolUsable: true)
        XCTAssertEqual(empty?.title, "Scanning the Source folder")
        XCTAssertEqual(empty?.showsStopScanHint, true)
        XCTAssertEqual(EmptyState.make(w, ModeState(mode: .remux), toolUsable: true)?.title, "Scanning the Video and Audio folders")
    }

    func testReScanKeepsRowsSoNoEmptyState() {
        var w = Workflow()
        _ = w.startScan()
        XCTAssertNil(EmptyState.make(w, U.state([U.ready("A")]), toolUsable: true))
    }

    func testIdleEmptyStates() {
        XCTAssertEqual(EmptyState.make(Workflow(), ModeState(mode: .split), toolUsable: false)?.title, "Can't scan yet")
        XCTAssertEqual(EmptyState.make(Workflow(), ModeState(mode: .split), toolUsable: true)?.title, "No files yet")
        var state = ModeState(mode: .split)
        state.setFolder("/s", for: .source)
        state.setFolder("/o", for: .output)
        XCTAssertEqual(EmptyState.make(Workflow(), state, toolUsable: true)?.title, "Ready to scan")
        state.applyScan(U.scan([]))
        XCTAssertEqual(EmptyState.make(Workflow(), state, toolUsable: true)?.title, "No files found")
        XCTAssertEqual(EmptyState.make(Workflow(), state, toolUsable: true)?.showsStopScanHint, false)
    }
}
