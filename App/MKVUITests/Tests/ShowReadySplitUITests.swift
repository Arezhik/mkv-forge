import XCTest

// Show Ready in Split. One settled empty MKV is Issue. One settled sample (audio and
// subtitles, no chapters) is Ready with Reason `No chapters found`.
// Launch arguments stay `--uitesting`. Locators stay on the page and the bottom bar.

@MainActor
final class ShowReadySplitUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let empty = try fixtures.createDummyFile(in: fixtures.input, named: "empty.mkv")
        let sample = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "sample.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(empty)
        try fixtures.settle(sample)
    }

    func testShowReadyHidesTheIssueRowAndKeepsTheReadyRow() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ -> Void in
            page.waitForSplitChrome()
        }

        try XCTContext.runActivity(named: "Scan the Source folder") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Issue and Ready are both visible") { _ -> Void in
            page.queueRow(stem: "empty").requireExactLabel("empty, Issue, Empty file (0 bytes)")
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready, No chapters found")
        }

        XCTContext.runActivity(named: "Turn Show Ready on") { _ in
            page.setShowReady(true)
        }

        XCTContext.runActivity(named: "Issue is hidden and Ready stays") { _ -> Void in
            page.queueRow(stem: "empty").assertExactLabelAbsent("empty, Issue, Empty file (0 bytes)")
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready, No chapters found")
        }

        XCTContext.runActivity(named: "Turn Show Ready off") { _ in
            page.setShowReady(false)
        }

        XCTContext.runActivity(named: "Issue returns") { _ -> Void in
            page.queueRow(stem: "empty").requireExactLabel("empty, Issue, Empty file (0 bytes)")
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready, No chapters found")
        }
    }
}
