import XCTest

// UIT-P1-02. An existing .mka is an Issue and is not overwritten.
// keep.mkv is flagged. fresh.mkv runs. The 0-byte keep.mka stays empty.

@MainActor
final class SplitExistingOutputUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let keep = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "keep.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
        let fresh = try fixtures.createValidMediaFile(
            in: fixtures.input,
            named: "fresh.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
        try fixtures.settle(keep)
        try fixtures.settle(fresh)
        _ = try fixtures.createDummyFile(in: fixtures.output, named: "keep.mka")
    }

    func testExistingMKAIsIssueAndIsNotOverwritten() throws {
        let keepOutput = fixtures.output.appendingPathComponent("keep.mka")
        let keepBefore = try Data(contentsOf: keepOutput)
        XCTAssertEqual(keepBefore.count, 0, "The pre-existing keep.mka should be 0 bytes")

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

        XCTContext.runActivity(named: "keep is an existing-output Issue and fresh is Ready") { _ in
            page.queueRow(stem: "keep").requireExactLabel("keep, Issue, keep.mka already exists in Output folder")
            page.queueRow(stem: "fresh").requireExactLabel("fresh, Ready")
        }

        XCTContext.runActivity(named: "Run Split") { _ in
            page.clickPrimaryAction(titled: "Split")
        }

        XCTContext.runActivity(named: "fresh finishes and keep stays flagged") { _ in
            page.queueRow(stem: "fresh").requireExactLabel("fresh, Done", timeout: UITestTimeout.batch)
            page.queueRow(stem: "keep").requireExactLabel(
                "keep, Issue, keep.mka already exists in Output folder",
                timeout: UITestTimeout.batch
            )
        }

        XCTContext.runActivity(named: "Bottom bar counts one done and one flagged") { _ in
            page.bottomBar.assertSummary(
                "Finished \u{00B7} 1 done \u{00B7} 1 flagged",
                timeout: UITestTimeout.batch
            )
        }

        XCTContext.runActivity(named: "keep.mka is unchanged and fresh.mka is written") { _ in
            XCTAssertEqual(try Data(contentsOf: keepOutput), keepBefore)
            let freshOutput = fixtures.output.appendingPathComponent("fresh.mka")
            XCTAssertGreaterThan(fixtures.byteCount(at: freshOutput) ?? 0, 0, "fresh.mka is missing or empty")
        }
    }
}
