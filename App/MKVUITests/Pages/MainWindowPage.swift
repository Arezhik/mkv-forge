import XCTest

// Page: shared chrome of the main window. A page owns locators and actions.
// Navigation returns the next page or component.
//
// Default mode on launch is Split, so Source and Output are the visible folder fields.
// Video and Audio appear after `switchToRemux()`.

/// Window, mode picker, folder fields, Scan, the toolbar primary action, and the queue.
@MainActor
class MainWindowPage: BasePage {
    var modePicker: ModePickerComponent {
        ModePickerComponent(app: app)
    }

    /// Folder-panel Scan button. The title is "Scan".
    /// It is disabled when MKVToolNix is missing. Tests click it through
    /// `clickScanOrSkip()`, which skips when `isEnabled` is false.
    var scanButton: XCUIElement {
        app.buttons["Scan"]
    }

    /// Waits for Scan and clicks it. Skips when the button is disabled
    /// (MKVToolNix is missing) after folder seeding has already been checked.
    /// A missing button fails the test. It does not skip.
    func clickScanOrSkip() throws {
        let scan = scanButton
        guard scan.waitForExistence(timeout: UITestTimeout.standard) else {
            XCTFail("The Scan button never showed up")
            return
        }
        guard scan.isEnabled else {
            throw XCTSkip("Scan is disabled (needs MKVToolNix); folder seeding was verified")
        }
        scan.click()
    }

    /// Toolbar primary action while idle or running.
    ///
    /// Idle titles are "Split" and "Remux", which are also the mode-segment titles.
    /// This query is a toolbar button, not a segment inside the mode picker.
    /// Switching mode is `switchToRemux()` / `ModePickerComponent`, not this button.
    /// Cancel and "Cancelling…" replace the title while a batch runs.
    func primaryActionButton(titled title: String) -> XCUIElement {
        app.toolbars.buttons.matching(
            NSPredicate(format: "label == %@ OR title == %@", title, title)
        ).firstMatch
    }

    func folder(_ identifier: FolderFieldIdentifier) -> FolderFieldComponent {
        FolderFieldComponent(app: app, identifier: identifier)
    }

    var sourceFolder: FolderFieldComponent { folder(.source) }
    var outputFolder: FolderFieldComponent { folder(.output) }
    var videoFolder: FolderFieldComponent { folder(.video) }
    var audioFolder: FolderFieldComponent { folder(.audio) }

    func queueRow(stem: String) -> QueueRowComponent {
        QueueRowComponent(app: app, stem: stem)
    }

    /// Selects the Remux segment and returns the Remux page.
    @discardableResult
    func switchToRemux() -> RemuxPage {
        return modePicker.selectRemux()
    }

    /// Selects the Split segment and returns the Split page.
    @discardableResult
    func switchToSplit() -> SplitPage {
        return modePicker.selectSplit()
    }
}
