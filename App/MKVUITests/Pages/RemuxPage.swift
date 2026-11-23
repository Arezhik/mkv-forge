import XCTest

// Page: Remux mode of the main window. A page owns locators and actions.
// `switchToRemux()` uses `ModePickerComponent` and returns this page.
//
// Locators (inherited from `MainWindowPage`, visible only after the mode switch):
// `videoFolder`, `audioFolder`, `outputFolder`, `scanButton`, `primaryActionButton(titled:)`,
// and `queueRow(stem:)`. The toolbar button titled "Remux" starts a batch.
// The segment inside the mode picker is what changes mode.

/// Remux mode. Scan reads the Video and Audio folders.
@MainActor
final class RemuxPage: MainWindowPage {
    /// Clicks the Remux segment via `ModePickerComponent` and returns this page.
    @discardableResult
    override func switchToRemux() -> RemuxPage {
        return modePicker.selectRemux()
    }

    /// Waits until Video, Audio, and Output are on screen.
    /// Call `switchToRemux()` first. Those fields are not in the Split layout.
    @discardableResult
    func waitForRemuxFolders(timeout: TimeInterval = UITestTimeout.standard) -> RemuxPage {
        _ = videoFolder.requireExists(timeout: timeout)
        _ = audioFolder.requireExists(timeout: timeout)
        _ = outputFolder.requireExists(timeout: timeout)
        return self
    }
}
