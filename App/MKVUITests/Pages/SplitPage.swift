import XCTest

// Page: Split mode of the main window. A page owns locators and actions.
// This is the mode on launch. Source and Output are on screen.
// Shared chrome (Scan, queue, mode picker) lives on `MainWindowPage`.

/// Split mode. Scan reads the Source folder.
@MainActor
final class SplitPage: MainWindowPage {
    /// Waits for the main window and the two Split folder fields.
    @discardableResult
    func waitForSplitChrome(timeout: TimeInterval = UITestTimeout.standard) -> SplitPage {
        waitUntilLoaded(timeout: timeout)
        _ = sourceFolder.requireExists(timeout: timeout)
        _ = outputFolder.requireExists(timeout: timeout)
        return self
    }
}
