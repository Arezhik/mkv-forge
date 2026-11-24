import XCTest

// Component: the MKVToolNix-not-found banner at the top of the main window.
// The title string is the query. Identifier `toolBanner` is a fallback anchor.
// Do not click Get MKVToolNix or Choose mkvmerge….

/// The banner shown when mkvmerge is missing.
@MainActor
struct ToolBannerComponent {
    let app: XCUIApplication

    private var window: XCUIElement {
        app.windows["MKVForge"]
    }

    func requireMissingToolTitle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let banner = window.descendants(matching: .any)["toolBanner"]
        banner.requireExists(
            timeout: timeout,
            message: "The MKVToolNix-missing banner never showed up",
            file: file,
            line: line
        )
        let expected = "MKVToolNix wasn't found."
        let nested = banner.descendants(matching: .any).matchingLabelOrValue(equalTo: expected).firstMatch
        let titled = window.descendants(matching: .any).matchingLabelOrValue(equalTo: expected).firstMatch
        guard UITestWait.firstExisting([nested, titled], timeout: timeout) != nil else {
            XCTFail("The banner title '\(expected)' never showed up", file: file, line: line)
            return
        }
    }
}
