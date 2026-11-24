import XCTest

// Page: shared chrome of the main window. A page owns locators and actions.
// Navigation returns the next page or component.
//
// Default mode on launch is Split, so Source and Output are the visible folder fields.
// Video and Audio appear after `switchToRemux()`.
//
// `root` is the window titled `MKVForge`. Settings uses another window, and
// `windows.firstMatch` becomes that window while it is key.

/// Window, mode picker, folder fields, Scan, the toolbar primary action, and the queue.
@MainActor
class MainWindowPage: BasePage {
    /// The main window. Settings is a different window titled with "Settings".
    override var root: XCUIElement {
        app.windows["MKVForge"]
    }

    var modePicker: ModePickerComponent {
        ModePickerComponent(app: app)
    }

    /// Folder-panel Scan button. The title is "Scan".
    /// It is disabled when MKVToolNix is missing. Tests click it through
    /// `clickScanOrSkip()`, which skips when `isEnabled` is false.
    var scanButton: XCUIElement {
        root.buttons["Scan"]
    }

    /// Toolbar primary action. Identifier `primaryAction` is on the button, so
    /// this does not match the mode segment that is also titled Split or Remux.
    var primaryAction: XCUIElement {
        root.descendants(matching: .any)["primaryAction"]
    }

    /// Scan-row caption. Label is `Scan status`. The caption is the value.
    var scanStatus: XCUIElement {
        root.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "scanStatus", "Scan status")
        ).firstMatch
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

    /// UIT-P2-03. Skips when mkvmerge is installed and Scan can run.
    /// A missing Scan button fails the test.
    func skipWhenScanIsEnabled() throws {
        let scan = scanButton
        guard scan.waitForExistence(timeout: UITestTimeout.standard) else {
            XCTFail("The Scan button never showed up")
            return
        }
        if scan.isEnabled {
            throw XCTSkip("mkvmerge is installed and Scan is enabled; this scenario only runs when Scan is disabled")
        }
    }

    /// Brings the MKVForge window forward. Clicks the Output folder field, which
    /// is on screen in both modes and does not scan, run, or switch mode.
    /// A title-bar percentage can land on the centered mode picker when the
    /// window is tall.
    @discardableResult
    func activateMainWindow(timeout: TimeInterval = UITestTimeout.standard) -> Self {
        let window = root
        window.requireExists(timeout: timeout, message: "The MKVForge window never showed up")
        let field = outputFolder.element
        if field.waitForExistence(timeout: timeout) {
            field.click()
            return self
        }
        let midX = window.frame.width / 2
        window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: midX, dy: 12))
            .click()
        return self
    }

    /// Toolbar primary action while idle or running.
    ///
    /// Idle titles are "Split" and "Remux", which are also the mode-segment titles.
    /// This query is identifier `primaryAction`, not a segment inside the mode picker.
    /// Switching mode is `switchToRemux()` / `ModePickerComponent`, not this button.
    func primaryActionButton(titled title: String) -> XCUIElement {
        primaryAction(titled: title)
    }

    func primaryAction(titled title: String) -> XCUIElement {
        root.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@ AND (label == %@ OR title == %@ OR value == %@)",
                "primaryAction", title, title, title
            )
        ).firstMatch
    }

    func assertPrimary(
        titled title: String,
        enabled: Bool,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = primaryAction
        button.requireExists(
            timeout: timeout,
            message: "The primary action never showed up",
            file: file,
            line: line
        )
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if button.exists, button.isEnabled == enabled, Self.titleMatches(button, title) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "primaryAction was \(Self.describe(button)), expected title \(title) enabled \(enabled)",
            file: file,
            line: line
        )
    }

    func clickPrimaryAction(
        titled title: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertPrimary(titled: title, enabled: true, timeout: timeout, file: file, line: line)
        primaryAction.click()
    }

    /// The caption is `accessibilityValue`. `label` stays `Scan status`.
    func assertScanStatus(
        containing fragment: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let observed = waitForScanStatusValue(timeout: timeout, file: file, line: line) { value in
            value.contains(fragment)
        }
        if let observed, observed.contains(fragment) {
            return
        }
        XCTFail("Scan status value '\(observed ?? "")' did not contain '\(fragment)'", file: file, line: line)
    }

    func assertScanStatus(
        equalTo expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let observed = waitForScanStatusValue(timeout: timeout, file: file, line: line) { value in
            value == expected
        }
        if observed == expected {
            return
        }
        XCTFail("Scan status value '\(observed ?? "")' was not '\(expected)'", file: file, line: line)
    }

    func assertNoQueueRows(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rows = root.descendants(matching: .any).matching(identifier: "queueRow")
        XCTAssertEqual(rows.count, 0, "Expected no queue rows, saw \(rows.count)", file: file, line: line)
    }

    func requireExactQueueLabel(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        queueRow(stem: expected).requireExactLabel(expected, timeout: timeout, file: file, line: line)
    }

    func folder(_ identifier: FolderFieldIdentifier) -> FolderFieldComponent {
        FolderFieldComponent(app: app, identifier: identifier)
    }

    var sourceFolder: FolderFieldComponent { folder(.source) }
    var outputFolder: FolderFieldComponent { folder(.output) }
    var videoFolder: FolderFieldComponent { folder(.video) }
    var audioFolder: FolderFieldComponent { folder(.audio) }

    var bottomBar: BottomBarComponent { BottomBarComponent(app: app) }

    var toolBanner: ToolBannerComponent { ToolBannerComponent(app: app) }

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

    private func waitForScanStatusValue(
        timeout: TimeInterval,
        file: StaticString,
        line: UInt,
        until matches: (String) -> Bool
    ) -> String? {
        let status = scanStatus
        guard status.waitForExistence(timeout: timeout) else {
            XCTFail("Scan status never showed up", file: file, line: line)
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        var latest = Self.captionValue(status)
        while Date() < deadline {
            latest = Self.captionValue(status)
            if matches(latest) {
                return latest
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return latest
    }

    private static func captionValue(_ element: XCUIElement) -> String {
        if let text = element.value as? String, !text.isEmpty {
            return text
        }
        return element.label
    }

    /// The button's own label is the title (`Split`, `Remux`, `Cancel`, `Cancelling…`).
    /// A child that merely contains the word does not count: `contains` would accept
    /// `Splitting` or a help string for the wrong title.
    /// An empty label still accepts an exact child string, which is how SwiftUI
    /// sometimes exposes a `Label`.
    private static func titleMatches(_ element: XCUIElement, _ title: String) -> Bool {
        if element.label == title || element.title == title {
            return true
        }
        if let text = element.value as? String, text == title {
            return true
        }
        let own = [element.label, element.title, (element.value as? String) ?? ""].filter { !$0.isEmpty }
        if !own.isEmpty {
            return false
        }
        return element.descendants(matching: .any).matchingLabelOrValue(equalTo: title).firstMatch.exists
    }

    private static func describe(_ element: XCUIElement) -> String {
        let value = element.value.map { "\($0)" } ?? ""
        return "label='\(element.label)' title='\(element.title)' value='\(value)' enabled=\(element.isEnabled)"
    }
}
