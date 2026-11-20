import XCTest
@testable import MKVForgeCore

final class WorkflowTests: XCTestCase {
    private typealias U = UIFixture

    func testIdleEnablement() {
        let w = Workflow()
        let state = U.state([U.ready("A"), U.flagged("B")])
        let e = w.enablement(state, toolUsable: true)
        XCTAssertTrue(e.modeSwitch && e.chooseFolders && e.folderMenus && e.scan && e.checkboxes && e.selectAll && e.primary)
        XCTAssertNil(e.primaryHelp)
        XCTAssertEqual(w.primaryAction(.split), .run(title: "Split", systemImage: "scissors"))
        XCTAssertEqual(w.primaryAction(.remux).title, "Remux")
    }

    func testPrimaryNeedsToolScanAndACheckedRow() {
        let w = Workflow()
        var state = ModeState(mode: .split)
        XCTAssertEqual(w.enablement(state, toolUsable: true).scanHelp, Workflow.needsFolders)
        state.setFolder("/s", for: .source)
        state.setFolder("/o", for: .output)
        XCTAssertEqual(w.enablement(state, toolUsable: false).scanHelp, "Needs MKVToolNix")
        XCTAssertEqual(w.enablement(state, toolUsable: false).primaryHelp, "Needs MKVToolNix")
        XCTAssertEqual(w.enablement(state, toolUsable: true).primaryHelp, Workflow.needsScan)
        state.applyScan(U.scan([U.ready("A")]))
        state.setChecked("A", false)
        XCTAssertFalse(w.enablement(state, toolUsable: true).primary)
        XCTAssertEqual(w.enablement(state, toolUsable: true).primaryHelp, Workflow.needsChecked)
    }

    func testScanningLocksEverything() {
        var w = Workflow()
        XCTAssertTrue(w.startScan())
        XCTAssertFalse(w.startScan())
        XCTAssertEqual(w.activity, .scanning(.listing))
        w.scanProgress(.reading(current: 3, total: 9))
        XCTAssertEqual(w.activity, .scanning(.reading(current: 3, total: 9)))
        let e = w.enablement(U.state([U.ready("A")]), toolUsable: true)
        XCTAssertFalse(e.modeSwitch || e.chooseFolders || e.folderMenus || e.scan || e.checkboxes || e.selectAll || e.primary)
        let flags = w.commandFlags(U.state([U.ready("A")]), toolUsable: true)
        XCTAssertTrue(flags.isScanning)
        XCTAssertFalse(flags.canRun || flags.canScan || flags.canSwitchMode || flags.hasActiveWork)
        w.scanEnded()
        XCTAssertEqual(w.activity, .idle)
        w.scanProgress(.listing)
        XCTAssertEqual(w.activity, .idle, "progress after the end is ignored")
    }

    func testRunCancelAndEnd() {
        var w = Workflow()
        XCTAssertFalse(w.startRun(mode: .split, total: 0))
        XCTAssertTrue(w.startRun(mode: .split, total: 2))
        XCTAssertEqual(w.primaryAction(.split), .cancel)
        let state = U.state([U.ready("A"), U.ready("B")])
        let e = w.enablement(state, toolUsable: true)
        XCTAssertTrue(e.primary, "Cancel is enabled")
        XCTAssertFalse(e.modeSwitch || e.scan || e.checkboxes)
        var flags = w.commandFlags(state, toolUsable: true)
        XCTAssertTrue(flags.canCancel && flags.hasActiveWork)
        XCTAssertFalse(flags.canRun)
        w.apply(.started(id: "A", index: 1, total: 2))
        w.apply(.finished(id: "A", status: .failed(reason: "r", detail: "")))
        XCTAssertEqual(w.batch?.completed, 1)
        XCTAssertEqual(w.batch?.currentName, "A")
        XCTAssertTrue(w.cancel())
        XCTAssertFalse(w.cancel())
        XCTAssertEqual(w.primaryAction(.split), .cancelling)
        XCTAssertFalse(w.enablement(state, toolUsable: true).primary)
        flags = w.commandFlags(state, toolUsable: true)
        XCTAssertTrue(flags.isCancelling && flags.hasActiveWork)
        XCTAssertFalse(flags.canCancel)
        let action = w.batchEnded(U.summary(filesInRun: 2, [.failed(reason: "r", detail: ""), .notRun], stopped: true), appIsActive: false, notifyOn: true, bounceOn: true)
        XCTAssertEqual(action, .feedback(BatchEndFeedback(notify: false, bounce: false, title: "Batch finished", body: "Stopped · 1 of 2 complete")))
        XCTAssertEqual(w.activity, .idle)
        XCTAssertNil(w.batch)
    }

    func testFinishThenQuitReusesCancellingAndQuitsQuietly() {
        var w = Workflow()
        XCTAssertFalse(w.finishThenQuit(), "nothing to finish when idle")
        _ = w.startRun(mode: .remux, total: 3)
        XCTAssertTrue(w.finishThenQuit(), "the runner still needs requestStop")
        XCTAssertEqual(w.activity, .cancelling)
        XCTAssertTrue(w.quitAfterStop)
        XCTAssertFalse(w.finishThenQuit(), "already cancelling: no second stop request")
        let action = w.batchEnded(U.summary(.remux, filesInRun: 3, [.done(outputPath: "/o/A.mkv"), .notRun, .notRun], stopped: true), appIsActive: false, notifyOn: true, bounceOn: true)
        XCTAssertEqual(action, .quitQuietly)
        XCTAssertFalse(w.quitAfterStop)
    }

    func testCancelThenFinishCurrentFileAddsTheQuit() {
        var w = Workflow()
        _ = w.startRun(mode: .split, total: 2)
        XCTAssertTrue(w.cancel())
        XCTAssertFalse(w.finishThenQuit())
        XCTAssertTrue(w.quitAfterStop)
    }

    func testNormalFinishInTheBackgroundNotifiesAndBounces() {
        var w = Workflow()
        _ = w.startRun(mode: .split, total: 1)
        let summary = U.summary(filesInRun: 1, flagged: 2, [.done(outputPath: "/o/A.mka")])
        let action = w.batchEnded(summary, appIsActive: false, notifyOn: true, bounceOn: false)
        XCTAssertEqual(action, .feedback(BatchEndFeedback(notify: true, bounce: false, title: "Batch finished", body: "Finished · 1 done · 2 flagged")))
    }

    func testCommandFlagsTrackModeAndTitle() {
        let flags = Workflow().commandFlags(U.state([U.ready("A")], mode: .remux), toolUsable: true)
        XCTAssertEqual(flags.mode, .remux)
        XCTAssertEqual(flags.runTitle, "Remux")
        XCTAssertTrue(flags.canRun && flags.canScan && flags.canSelect && flags.canSwitchMode)
        XCTAssertEqual(Workflow().commandFlags(ModeState(mode: .split), toolUsable: true).canSelect, false)
    }

    func testPrimaryActionSymbols() {
        XCTAssertEqual(PrimaryAction.run(for: .remux).systemImage, "arrow.triangle.merge")
        XCTAssertEqual(PrimaryAction.cancel.systemImage, "stop.fill")
        XCTAssertEqual(PrimaryAction.cancel.title, "Cancel")
        XCTAssertNil(PrimaryAction.cancelling.systemImage)
        XCTAssertEqual(PrimaryAction.cancelling.title, "Cancelling…")
    }
}
