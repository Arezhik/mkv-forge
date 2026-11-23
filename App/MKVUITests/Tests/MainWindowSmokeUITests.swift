import XCTest

// Thin test. Launch, fixtures, and teardown live on `BaseUITest`.
// This check only asserts the main window and the seeded Split folder fields.
// It does not click Scan (Scan is disabled without MKVToolNix).

/// Window and seeded Source / Output fields. Default mode is Split.
@MainActor
final class MainWindowSmokeUITests: BaseUITest {
    func testMainWindowShowsSeededSplitFolders() {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Main window appears") { _ in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source folder shows the input fixture") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
        }

        XCTContext.runActivity(named: "Output folder shows the output fixture") { _ in
            page.outputFolder.assertShowsPathFragment("output")
        }
    }
}
