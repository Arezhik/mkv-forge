import XCTest
@testable import MKVForgeCore

final class RunETATests: XCTestCase {
    private func sample(
        _ percent: Int,
        _ elapsed: TimeInterval,
        finished: [TimeInterval] = [],
        queued: Int = 0,
        cancelled: Bool = false
    ) -> RunETA.Sample {
        RunETA.Sample(
            percent: percent,
            elapsed: elapsed,
            finishedDurations: finished,
            queuedAfterCurrent: queued,
            cancelled: cancelled
        )
    }

    func testStableThresholdIsFivePercent() {
        XCTAssertEqual(RunETA.stablePercent, 5)
    }

    func testNoFinishedFilesUsesTheCurrentProjectionForTheQueue() {
        XCTAssertEqual(RunETA.caption(sample(50, 10, queued: 0)), "About 10 seconds left")
        // 50% at 10s projects 20s. Two files still queued add 20s each: 10 + 40.
        XCTAssertEqual(RunETA.caption(sample(50, 10, queued: 2)), "About 50 seconds left")
    }

    func testFinishedFilesUseTheirAverageForTheQueueOnly() {
        // 25% at 10s leaves 30s on this file. The queued file uses the 16s average, not the 40s projection.
        XCTAssertEqual(RunETA.caption(sample(25, 10, finished: [16], queued: 1)), "About 46 seconds left")
        XCTAssertEqual(RunETA.caption(sample(25, 10, finished: [10, 22], queued: 1)), "About 46 seconds left")
        // Nothing queued: the finished average is not applied to the current file.
        XCTAssertEqual(RunETA.caption(sample(25, 10, finished: [16], queued: 0)), "About 30 seconds left")
    }

    func testHideAtZeroUnderTheThresholdAtOneHundredAndAfterCancel() {
        XCTAssertEqual(RunETA.caption(sample(0, 10, queued: 1)), "")
        XCTAssertEqual(RunETA.caption(sample(4, 20, queued: 1)), "")
        XCTAssertEqual(RunETA.caption(sample(5, 20, queued: 0)), "About 6 minutes left")
        XCTAssertEqual(RunETA.caption(sample(100, 10, queued: 1)), "")
        XCTAssertEqual(RunETA.caption(sample(150, 10, queued: 1)), "")
        XCTAssertEqual(RunETA.caption(sample(-2, 10, queued: 1)), "")
        XCTAssertEqual(RunETA.caption(sample(99, 100, queued: 0)), "About 1 second left")
        XCTAssertEqual(RunETA.caption(sample(50, 10, queued: 1, cancelled: true)), "")
        XCTAssertEqual(RunETA.caption(sample(50, 0, queued: 1)), "")
    }

    func testWordingRoundsUnitsAndUsesSingular() {
        XCTAssertEqual(RunETA.caption(sample(50, 12)), "About 12 seconds left")
        XCTAssertEqual(RunETA.caption(sample(50, 1)), "About 1 second left")
        XCTAssertEqual(RunETA.caption(sample(50, 1.4)), "About 1 second left")
        XCTAssertEqual(RunETA.caption(sample(50, 1.5)), "About 2 seconds left")
        XCTAssertEqual(RunETA.caption(sample(5, 0.01)), "About 1 second left", "a rounded 0 seconds is shown as 1")
        XCTAssertEqual(RunETA.caption(sample(50, 59.4)), "About 59 seconds left")
        XCTAssertEqual(RunETA.caption(sample(50, 59.5)), "About 1 minute left")
        XCTAssertEqual(RunETA.caption(sample(50, 60)), "About 1 minute left")
        XCTAssertEqual(RunETA.caption(sample(50, 90)), "About 2 minutes left")
        XCTAssertEqual(RunETA.caption(sample(50, 3600)), "About 1 hour left")
        XCTAssertEqual(RunETA.caption(sample(50, 3660)), "About 1 hour 1 minute left")
        XCTAssertEqual(RunETA.caption(sample(50, 5400)), "About 1 hour 30 minutes left")
        XCTAssertEqual(RunETA.caption(sample(50, 7200)), "About 2 hours left")
    }

    func testEventsThrottleToAboutTenASecondAndHideImmediately() {
        var eta = RunETA()
        let start = Date(timeIntervalSince1970: 10_000)
        let first = eta.event(for: sample(50, 10), at: start)
        XCTAssertEqual(first, .progress(caption: "About 10 seconds left"))
        XCTAssertNil(eta.event(for: sample(60, 12), at: start.addingTimeInterval(0.05)))
        let next = eta.event(for: sample(60, 12), at: start.addingTimeInterval(0.1))
        XCTAssertEqual(next, .progress(caption: "About 8 seconds left"))
        let hide = eta.event(for: sample(100, 20), at: start.addingTimeInterval(0.12))
        XCTAssertEqual(hide, .progress(caption: ""))
        XCTAssertNil(eta.event(for: sample(100, 21), at: start.addingTimeInterval(0.2)))
    }

    func testCancelHidesImmediatelyAndZeroPercentPublishesNothing() {
        var eta = RunETA()
        let start = Date(timeIntervalSince1970: 20_000)
        XCTAssertNil(eta.event(for: sample(0, 10), at: start))
        XCTAssertNil(eta.event(for: sample(4, 10), at: start))
        XCTAssertEqual(
            eta.event(for: sample(50, 10), at: start),
            .progress(caption: "About 10 seconds left")
        )
        XCTAssertEqual(
            eta.event(for: sample(50, 10, cancelled: true), at: start.addingTimeInterval(0.01)),
            .progress(caption: "")
        )
    }
}
