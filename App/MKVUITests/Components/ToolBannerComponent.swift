import XCTest

// Component: the MKVToolNix-not-found banner at the top of the main window.
// The title string is the query. Identifier `toolBanner` is the container.
// Do not click Get MKVToolNix or Choose mkvmerge….
//
// `app.windows["MKVForge"]` does not match the SwiftUI main window.
// The title is a static text. The container is a group. No `.any` walk.

/// The banner shown when mkvmerge is missing.
@MainActor
struct ToolBannerComponent {
    let app: XCUIApplication

    func requireMissingToolTitle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = "MKVToolNix wasn't found."
        let banner = UITestQuery.identified("toolBanner", in: app, types: [.group, .other])
        let title = app.staticTexts.matchingLabelOrValue(equalTo: expected).firstMatch
        guard UITestWait.firstExisting(banner + [title], timeout: timeout) != nil else {
            XCTFail("The MKVToolNix-missing banner never showed up", file: file, line: line)
            return
        }
        guard UITestWait.firstExisting([title], timeout: timeout) != nil else {
            XCTFail("The banner title '\(expected)' never showed up", file: file, line: line)
            return
        }
    }
}
