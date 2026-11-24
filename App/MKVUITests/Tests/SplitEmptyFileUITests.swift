import XCTest

// UIT-P1-01. A settled empty MKV is one Issue, and Split stays disabled.
// Settling is required. A fresh 0-byte file also gets the still-changing issue.

@MainActor
final class SplitEmptyFileUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let empty = try fixtures.createDummyFile(in: fixtures.input, named: "sample.mkv")
        try fixtures.settle(empty)
    }

    func testSettledEmptyMKVIsOneIssueAndSplitStaysDisabled() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ in
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

        XCTContext.runActivity(named: "Empty file is one Issue") { _ in
            page.queueRow(stem: "sample").requireExactLabel("sample, Issue, Empty file (0 bytes)")
        }

        XCTContext.runActivity(named: "Include sample stays disabled and Split stays disabled") { _ in
            page.queueRow(stem: "sample").assertIncludeCheckbox(enabled: false)
            page.assertPrimary(titled: "Split", enabled: false)
        }

        XCTContext.runActivity(named: "No output file is created") { _ in
            XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("sample.mka")))
        }
    }
}
