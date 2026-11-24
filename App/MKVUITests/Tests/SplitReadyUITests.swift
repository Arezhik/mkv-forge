import XCTest

// UIT-P0-01, UIT-P0-02, and UIT-P2-02. One settled Split file with audio and subtitles.
// Launch arguments stay `--uitesting`. Locators stay on pages and components.

@MainActor
final class SplitReadyUITests: BaseUITest {
    private static let fileName = "sample.mkv"

    override func prepareFixtures() async throws {
        let source = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: Self.fileName,
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(source)
    }

    /// UIT-P0-01. Scan shows one Ready row and enables Split. Does not run.
    func testSplitScanShowsReadyRowAndEnablesSplit() throws {
        let page = try scanUntilReady()

        XCTContext.runActivity(named: "Split is enabled") { _ in
            page.assertPrimary(titled: "Split", enabled: true)
        }

        XCTContext.runActivity(named: "Scan status counts one MKV") { _ in
            // " · 1 MKV file" does not match " · 11 MKV files". The clock stays unchecked.
            page.assertScanStatus(containing: " \u{00B7} 1 MKV file")
        }
    }

    /// UIT-P0-02. Split finishes Done and writes sample.mka.
    func testSplitRunFinishesDoneAndWritesMKA() throws {
        let source = fixtures.input.appendingPathComponent(Self.fileName)
        let sourceBefore = try Data(contentsOf: source)
        let page = try scanUntilReady()

        XCTContext.runActivity(named: "Run Split") { _ in
            page.clickPrimaryAction(titled: "Split")
        }

        XCTContext.runActivity(named: "Row finishes Done") { _ -> Void in
            page.queueRow(stem: "sample").requireExactLabel("sample, Done", timeout: UITestTimeout.batch)
        }

        XCTContext.runActivity(named: "Bottom bar shows one done") { _ in
            page.bottomBar.assertSummary("Finished \u{00B7} 1 done", timeout: UITestTimeout.batch)
            page.bottomBar.assertProgress(
                value: "1 of 1 complete",
                caption: "1 .mka saved",
                timeout: UITestTimeout.batch
            )
            page.bottomBar.assertShowInFinderVisible(timeout: UITestTimeout.batch)
        }

        try XCTContext.runActivity(named: "sample.mka is written and the source is unchanged") { _ -> Void in
            let output = fixtures.output.appendingPathComponent("sample.mka")
            let written = fixtures.byteCount(at: output)
            XCTAssertGreaterThan(written ?? 0, 0, "sample.mka is missing or empty")
            XCTAssertEqual(try Data(contentsOf: source), sourceBefore, "Split changed the source sample.mkv")
        }
    }

    /// UIT-P2-02. Unchecking the only Ready row disables Split.
    func testUncheckingReadyRowDisablesSplit() throws {
        let page = try scanUntilReady()

        XCTContext.runActivity(named: "Uncheck Include sample") { _ in
            page.queueRow(stem: "sample").clickIncludeCheckbox()
        }

        XCTContext.runActivity(named: "Row stays Ready and Split is disabled") { _ in
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready")
            page.assertPrimary(titled: "Split", enabled: false)
        }

        XCTContext.runActivity(named: "No sample.mka is written") { _ in
            XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("sample.mka")))
        }
    }

    private func scanUntilReady() throws -> SplitPage {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ -> Void in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source folder shows the input fixture") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
        }

        XCTContext.runActivity(named: "Output folder shows the output fixture") { _ in
            page.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan the Source folder") { _ in
            try page.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "sample is Ready") { _ -> Void in
            page.queueRow(stem: "sample").requireExactLabel("sample, Ready")
        }

        return page
    }
}
