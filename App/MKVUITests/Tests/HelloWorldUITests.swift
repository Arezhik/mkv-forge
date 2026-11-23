import XCTest

/// Dummy files stay in the queue after Scan (empty-file issue) and never need mkvmerge.
/// Launch, the `UITEST_*` environment, and cleanup live on `BaseUITest`.
@MainActor
final class HelloWorldUITests: BaseUITest {
    override func prepareFixtures() async throws {
        // Dummy files stay in the queue after Scan (empty-file issue) and never need mkvmerge.
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mkv")
        try fixtures.createDummyFile(in: fixtures.video, named: "sample.mkv")
        try fixtures.createDummyFile(in: fixtures.audio, named: "sample.mka")
    }

    func testAppOpensMainWindow() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Main window and Split folders") { _ in
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

        XCTContext.runActivity(named: "Queue shows the sample row") { _ in
            // #44: match label OR value with `matching`, never `containing`.
            // The failure message lists observed row labels and values.
            page.queueRow(stem: "sample").requireExists()
        }
    }
}
