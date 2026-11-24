import XCTest

// Page: the Settings window (`SettingsView`). A page owns locators and actions.
//
// Opening Settings is the application menu item "Settings…" (SwiftUI `Settings` scene, also ⌘,).
// The navigation title is "MKVForge Settings". The pane has an MKVToolNix section and
// "When a batch finishes" toggles ("Send a notification", "Bounce the Dock icon").
//
// Do not use `app.windows["MKVForge Settings"]` as the only lookup. The window title
// may be "Settings" or empty, with the navigation title as a static text.
// Controls are `app.switches`, `app.checkBoxes`, `app.buttons`, and `app.staticTexts`.
// `descendants(matching: .any)` times out on macOS.

/// Settings window. Locators assume the window is up, except `open(in:)`.
@MainActor
final class SettingsPage: BasePage {
    /// A window whose title or label contains Settings. Not the exact title
    /// `MKVForge Settings`, which the Settings scene does not always expose.
    override var root: XCUIElement {
        app.windows.matching(
            NSPredicate(format: "title CONTAINS[c] %@ OR label CONTAINS[c] %@", "Settings", "Settings")
        ).firstMatch
    }

    /// Opens Settings from the MKVForge application menu and returns this page.
    @discardableResult
    static func open(in app: XCUIApplication) -> SettingsPage {
        let appMenu = app.menuBars.firstMatch.menuBarItems["MKVForge"]
        appMenu.clickWhenReady(message: "The MKVForge application menu never showed up")
        let item = appMenu.menuItems.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", "Settings", "Settings")
        ).firstMatch
        item.clickWhenReady(message: "The Settings menu item never showed up")
        return SettingsPage(app: app)
    }

    /// Section header "MKVToolNix". Exact, so "Get MKVToolNix, opens in browser" does not pass.
    /// SwiftUI `Text` may expose the header as `value`.
    var mkvToolNixSection: XCUIElement {
        app.staticTexts.matchingLabelOrValue(equalTo: "MKVToolNix").firstMatch
    }

    var sendNotificationToggle: XCUIElement {
        control(named: "Send a notification")
    }

    var bounceDockIconToggle: XCUIElement {
        control(named: "Bounce the Dock icon")
    }

    /// The Remux switch. Same lookup as the finish switches.
    var matchOnMKANameToggle: XCUIElement {
        control(named: "Match on MKA Name")
    }

    func clickSendNotification() {
        clickControl(named: "Send a notification", message: "The Send a notification toggle never showed up")
    }

    func clickBounceDockIcon() {
        clickControl(named: "Bounce the Dock icon", message: "The Bounce the Dock icon toggle never showed up")
    }

    func clickMatchOnMKAName() {
        clickControl(named: "Match on MKA Name", message: "The Match on MKA Name toggle never showed up")
    }

    /// Navigation title `MKVForge Settings` is up, either as the window title
    /// or as a static text. Does not walk the window tree.
    func waitForSettingsChrome(timeout: TimeInterval = UITestTimeout.standard) {
        let navigationTitle = app.staticTexts.matchingLabelOrValue(equalTo: "MKVForge Settings").firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Self.windowShowsNavigationTitle(root) || navigationTitle.exists {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let title = root.exists ? root.title : "(no window whose title contains Settings)"
        let label = root.exists ? root.label : ""
        XCTFail(
            "The navigation title MKVForge Settings never showed up. Window title '\(title)' label '\(label)'."
        )
    }

    func requireMKVToolNixSection(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        mkvToolNixSection.requireExists(
            timeout: timeout,
            message: "The MKVToolNix section never showed up",
            file: file,
            line: line
        )
    }

    func requireMatchOnMKANameToggle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireControl(
            named: "Match on MKA Name",
            message: "The Match on MKA Name switch never showed up",
            timeout: timeout,
            file: file,
            line: line
        )
    }

    func requireSendNotificationToggle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireControl(
            named: "Send a notification",
            message: "The Send a notification switch never showed up",
            timeout: timeout,
            file: file,
            line: line
        )
    }

    func requireBounceDockIconToggle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireControl(
            named: "Bounce the Dock icon",
            message: "The Bounce the Dock icon switch never showed up",
            timeout: timeout,
            file: file,
            line: line
        )
    }

    /// `true` is on, `false` is off, `nil` when the control is missing or its value
    /// is not `1`/`0` or `on`/`off`.
    func switchValue(named name: String) -> Bool? {
        let toggle = control(named: name)
        guard toggle.exists else { return nil }
        return toggle.switchIsOn
    }

    /// The Settings bindings write on the next main-actor turn, so this polls.
    func waitUntilSwitch(
        named name: String,
        isOn expected: Bool,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = "missing"
        while Date() < deadline {
            let toggle = control(named: name)
            if toggle.exists {
                latest = toggle.value.map { "\($0)" } ?? "nil"
                if toggle.switchIsOn == expected {
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "\(name) did not read \(expected ? "on" : "off"). Value was \(latest).",
            file: file,
            line: line
        )
    }

    /// Accepts `Found · …` or `Not found`. Does not assert a version number.
    func assertToolStatusFoundOrNotFound(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let foundPrefix = "Found \u{00B7}"
        let found = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", foundPrefix, foundPrefix)
        ).firstMatch
        let missing = app.staticTexts.matchingLabelOrValue(equalTo: "Not found").firstMatch
        guard UITestWait.firstExisting([found, missing], timeout: timeout) != nil else {
            XCTFail(
                "The mkvmerge status did not show Found · or Not found",
                file: file,
                line: line
            )
            return
        }
    }

    /// Enabled only after a chosen override. This launch has none, so it stays disabled.
    /// Does not click the button.
    func assertUseAutomaticDisabled(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let button = UITestWait.firstExisting(buttonCandidates(titled: "Use Automatic"), timeout: timeout) else {
            XCTFail("Use Automatic never showed up", file: file, line: line)
            return
        }
        XCTAssertFalse(button.isEnabled, "Use Automatic enables only after a chosen override", file: file, line: line)
    }

    /// Present so the row is on screen. Does not click it. The ellipsis is U+2026.
    /// Label equality skips the folder-panel buttons, whose label is
    /// `Choose Source folder` and whose title is still `Choose…`.
    func assertChooseButtonPresent(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard UITestWait.firstExisting(buttonCandidates(titled: "Choose…"), timeout: timeout) != nil else {
            XCTFail("Choose… never showed up", file: file, line: line)
            return
        }
    }

    private static func windowShowsNavigationTitle(_ window: XCUIElement) -> Bool {
        guard window.exists else { return false }
        return window.title.contains("MKVForge Settings") || window.label.contains("MKVForge Settings")
    }

    /// Switches and checkboxes only. A caption that contains the name must not pass
    /// as the switch. `matchingLabelOrValue` reads the control's own label or value.
    /// The finish switches include a subtitle in that label, so the match is
    /// `containing` on the control itself, not a raw descendant `containing` query.
    private func controlCandidates(named name: String) -> [XCUIElement] {
        [
            app.switches.matchingLabelOrValue(containing: name).firstMatch,
            app.checkBoxes.matchingLabelOrValue(containing: name).firstMatch,
            app.switches.matching(NSPredicate(format: "title == %@", name)).firstMatch,
            app.checkBoxes.matching(NSPredicate(format: "title == %@", name)).firstMatch,
        ]
    }

    private func control(named name: String) -> XCUIElement {
        let candidates = controlCandidates(named: name)
        return candidates.first { $0.exists } ?? candidates[0]
    }

    private func requireControl(
        named name: String,
        message: String,
        timeout: TimeInterval,
        file: StaticString,
        line: UInt
    ) {
        guard UITestWait.firstExisting(controlCandidates(named: name), timeout: timeout) != nil else {
            XCTFail(message, file: file, line: line)
            return
        }
    }

    private func clickControl(named name: String, message: String) {
        guard let toggle = UITestWait.firstExisting(controlCandidates(named: name), timeout: UITestTimeout.standard) else {
            XCTFail(message)
            return
        }
        toggle.click()
    }

    private func buttonCandidates(titled name: String) -> [XCUIElement] {
        let exactLabel = NSPredicate(format: "label == %@", name)
        let labelOrTitle = NSPredicate(format: "label == %@ OR title == %@", name, name)
        return [
            app.buttons.matching(exactLabel).firstMatch,
            root.buttons.matching(labelOrTitle).firstMatch,
        ]
    }
}
