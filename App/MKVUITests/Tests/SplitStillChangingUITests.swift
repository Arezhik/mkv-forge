import XCTest

// UIT-P2-01. A file touched in the last minute cannot be Ready.
// The file is non-empty and is not settled. An empty file would report Empty file first.

@MainActor
final class SplitStillChangingUITests: BaseUITest {
    override func prepareFixtures() async throws {
        _ = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "sample.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
    }

    func testFileTouchedInTheLastMinuteCannotBeReady() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source and Output folders") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
            page.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan the Source folder") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "sample is still changing") { _ in
            page.queueRow(stem: "sample").requireExactLabel(
                "sample, Issue, Still changing (modified in the last minute)"
            )
        }

        XCTContext.runActivity(named: "Split stays disabled") { _ in
            page.assertPrimary(titled: "Split", enabled: false)
        }
    }
}
