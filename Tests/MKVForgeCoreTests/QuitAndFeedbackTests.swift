import XCTest
@testable import MKVForgeCore

final class QuitFlowTests: XCTestCase {
    private let tail = "Choose Finish Current File to quit when it’s done, or Quit to stop now and delete its unfinished file. Files that are already finished are kept."

    func testIdleAndScanningQuitRightAway() {
        XCTAssertEqual(QuitFlow.decide(Workflow()), .quitNow)
        var w = Workflow()
        _ = w.startScan()
        XCTAssertEqual(QuitFlow.decide(w), .quitNow)
    }

    func testRunningAsksWithTheRunningText() {
        var w = Workflow()
        _ = w.startRun(mode: .split, total: 3)
        w.apply(.started(id: "Show - S01E02", index: 1, total: 3))
        let expected = QuitAlert(title: "A batch is running",
                                 message: "MKVForge is splitting “Show - S01E02”. \(tail)",
                                 buttons: ["Finish Current File", "Quit", "Cancel"])
        XCTAssertEqual(QuitFlow.decide(w), .ask(expected))
    }

    func testRemuxAndNoCurrentName() {
        let alert = QuitFlow.alert(mode: .remux, currentName: nil, cancelling: false)
        XCTAssertEqual(alert.message, "MKVForge is remuxing the current file. \(tail)")
    }

    func testCancellingOrQuittingUsesTheFinishingText() {
        var w = Workflow()
        _ = w.startRun(mode: .remux, total: 3)
        w.apply(.started(id: "A", index: 1, total: 3))
        _ = w.finishThenQuit()
        guard case let .ask(alert) = QuitFlow.decide(w) else { return XCTFail("should ask") }
        XCTAssertEqual(alert.message, "MKVForge is finishing “A”, then stopping. \(tail)")
    }

    func testLongNamesAreMiddleTruncated() {
        let name = String(repeating: "a", count: 30) + String(repeating: "b", count: 30)
        let short = QuitFlow.middleTruncate(name)
        XCTAssertEqual(short.count, 40)
        XCTAssertTrue(short.hasPrefix("aaaa") && short.hasSuffix("bbbb") && short.contains("…"))
        XCTAssertEqual(QuitFlow.middleTruncate("short"), "short")
        XCTAssertEqual(QuitFlow.middleTruncate(String(repeating: "x", count: 40)).count, 40)
    }

    func testButtonIndexes() {
        XCTAssertEqual(QuitChoice(buttonIndex: 0), .finishCurrentFile)
        XCTAssertEqual(QuitChoice(buttonIndex: 1), .quit)
        XCTAssertEqual(QuitChoice(buttonIndex: 2), .cancel)
        XCTAssertEqual(QuitChoice(buttonIndex: 99), .cancel)
        XCTAssertEqual(QuitFlow.willQuitAnnouncement, "MKVForge will quit after this file.")
    }
}

final class BatchEndFeedbackTests: XCTestCase {
    private typealias U = UIFixture

    func testOnlyInTheBackgroundAfterANormalFinish() {
        let summary = U.summary(filesInRun: 2, [.done(outputPath: "/o/A.mka"), .failed(reason: "r", detail: "")])
        let bg = BatchEndFeedback.decide(summary: summary, appIsActive: false, notifyOn: true, bounceOn: true)
        XCTAssertEqual(bg, BatchEndFeedback(notify: true, bounce: true, title: "Batch finished", body: "Finished · 1 done · 1 failed"))
        let fg = BatchEndFeedback.decide(summary: summary, appIsActive: true, notifyOn: true, bounceOn: true)
        XCTAssertFalse(fg.notify || fg.bounce)
    }

    func testEachSwitchIsIndependent() {
        let summary = U.summary(filesInRun: 1, [.done(outputPath: "/o/A.mka")])
        let a = BatchEndFeedback.decide(summary: summary, appIsActive: false, notifyOn: false, bounceOn: true)
        XCTAssertEqual([a.notify, a.bounce], [false, true])
        let b = BatchEndFeedback.decide(summary: summary, appIsActive: false, notifyOn: true, bounceOn: false)
        XCTAssertEqual([b.notify, b.bounce], [true, false])
    }

    func testNeverAfterAStop() {
        let summary = U.summary(filesInRun: 2, [.done(outputPath: "/o/A.mka"), .notRun], stopped: true)
        let f = BatchEndFeedback.decide(summary: summary, appIsActive: false, notifyOn: true, bounceOn: true)
        XCTAssertFalse(f.notify || f.bounce)
    }
}

final class RevealPlanTests: XCTestCase {
    func testSelectsOutputsInTheOutputFolder() {
        let plan = RevealPlan.plan(outputFolder: "/o", outputs: ["/o/A.mka", "/o/B.mka"], exists: { _ in true })
        XCTAssertEqual(plan, .select(["/o/A.mka", "/o/B.mka"]))
        XCTAssertEqual(RevealPlan.plan(outputFolder: "/o/", outputs: ["/o/./A.mka"], exists: { _ in true }), .select(["/o/./A.mka"]))
    }

    func testMissingFilesAreLeftOut() {
        let plan = RevealPlan.plan(outputFolder: "/o", outputs: ["/o/A.mka", "/o/B.mka"], exists: { $0 != "/o/A.mka" })
        XCTAssertEqual(plan, .select(["/o/B.mka"]))
    }

    func testFallsBackToTheFolder() {
        XCTAssertEqual(RevealPlan.plan(outputFolder: "/o", outputs: ["/o/A.mka"], exists: { $0 == "/o" }), .folder("/o"))
        XCTAssertEqual(RevealPlan.plan(outputFolder: "/o", outputs: ["/elsewhere/A.mka"], exists: { _ in true }), .folder("/o"))
        XCTAssertEqual(RevealPlan.plan(outputFolder: "/o", outputs: [], exists: { _ in false }), .nothing(reason: "The Output folder isn't there anymore."))
    }

    func testSingleItem() {
        XCTAssertEqual(RevealPlan.plan(item: "/o/A.mka", exists: { _ in true }), .select(["/o/A.mka"]))
        XCTAssertEqual(RevealPlan.plan(item: "/o/A.mka", exists: { _ in false }), .nothing(reason: "A.mka isn't there anymore."))
    }
}
