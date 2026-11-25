import XCTest

// Audio only: no subtitles and no chapters. The row stays Ready. Reason shows
// the subtitles note plus one more. Split is enabled. Launch arguments stay
// `--uitesting`. Locators stay on pages and components.

@MainActor
final class SplitAudioOnlyUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let source = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "sample.mkv",
            includeAudio: true,
            includeSubtitles: false
        )
        try fixtures.settle(source)
    }

    func testAudioOnlyIsReadyWithBothWarnings() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ -> Void in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source and Output folders") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
            page.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan the Source folder") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "sample is Ready and names both missing pieces") { _ -> Void in
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready, No subtitle tracks found (+1 more)")
        }

        XCTContext.runActivity(named: "Split is enabled") { _ in
            page.assertPrimary(titled: "Split", enabled: true)
        }
    }
}
