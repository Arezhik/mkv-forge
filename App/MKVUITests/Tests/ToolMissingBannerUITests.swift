import XCTest

// UIT-P2-03. With mkvmerge missing, the banner is up and Scan does not run.
// Skips when Scan is enabled. No media. Does not click Get MKVToolNix or Choose mkvmerge….

@MainActor
final class ToolMissingBannerUITests: BaseUITest {
    override func prepareFixtures() async throws {
        // Seeded Split folders from BaseUITest. No media.
    }

    func testMissingMKVMergeShowsBannerAndDoesNotScan() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Split chrome") { _ in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source and Output folders are seeded") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
            page.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Skip when mkvmerge is installed") { _ in
            try page.skipWhenScanIsEnabled()
        }

        XCTContext.runActivity(named: "Banner, scan status, and disabled Split") { _ in
            page.toolBanner.requireMissingToolTitle()
            page.assertScanStatus(equalTo: "Scan needs mkvmerge")
            page.assertPrimary(titled: "Split", enabled: false)
        }

        XCTContext.runActivity(named: "No queue rows") { _ in
            page.assertNoQueueRows()
        }
    }
}
