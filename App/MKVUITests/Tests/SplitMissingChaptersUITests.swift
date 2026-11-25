import XCTest

// Audio and subtitles, no chapters. The row stays Ready, shows the chapters
// warning, and Split is enabled. Launch arguments stay `--uitesting`.
// Locators stay on pages and components.

@MainActor
final class SplitMissingChaptersUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let source = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "sample.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(source)
    }

    func testAudioAndSubtitlesWithoutChaptersIsReady() throws {
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

        XCTContext.runActivity(named: "sample is Ready with no chapters") { _ -> Void in
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready, No chapters found")
        }

        XCTContext.runActivity(named: "Split is enabled") { _ in
            page.assertPrimary(titled: "Split", enabled: true)
        }
    }
}
