import XCTest

// Page: the Settings window (`SettingsView`). A page owns locators and actions.
//
// Opening Settings is the application menu item "Settings…" (SwiftUI `Settings` scene, also ⌘,).
// The navigation title is "MKVForge Settings". The pane has an MKVToolNix section and
// "When a batch finishes" toggles ("Send a notification", "Bounce the Dock icon").
//
// If the menu title differs by OS, construct `SettingsPage(app:)` once the window
// is already up and use the locators below. `open(in:)` is the menu path.

/// Settings window. Locators assume the window is up, except `open(in:)`.
@MainActor
final class SettingsPage: BasePage {
    override var root: XCUIElement {
        app.windows.matching(
            NSPredicate(format: "title CONTAINS %@ OR label CONTAINS %@", "Settings", "Settings")
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
        root.descendants(matching: .any).matchingLabelOrValue(equalTo: "MKVToolNix").firstMatch
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
        sendNotificationToggle.clickWhenReady(message: "The Send a notification toggle never showed up")
    }

    func clickBounceDockIcon() {
        bounceDockIconToggle.clickWhenReady(message: "The Bounce the Dock icon toggle never showed up")
    }

    func clickMatchOnMKAName() {
        matchOnMKANameToggle.clickWhenReady(message: "The Match on MKA Name toggle never showed up")
    }

    /// Window title contains Settings, and the navigation title `MKVForge Settings` is up.
    func waitForSettingsChrome(timeout: TimeInterval = UITestTimeout.standard) {
        let window = root.requireExists(timeout: timeout, message: "The Settings window never showed up")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Self.showsSettingsTitle(window), Self.showsNavigationTitle(window) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(
            Self.showsSettingsTitle(window),
            "The Settings window title was '\(window.title)' label '\(window.label)'"
        )
        XCTAssertTrue(
            Self.showsNavigationTitle(window),
            "The navigation title MKVForge Settings never showed up. Window title '\(window.title)'."
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
        matchOnMKANameToggle.requireExists(
            timeout: timeout,
            message: "The Match on MKA Name switch never showed up",
            file: file,
            line: line
        )
    }

    func requireSendNotificationToggle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        sendNotificationToggle.requireExists(
            timeout: timeout,
            message: "The Send a notification switch never showed up",
            file: file,
            line: line
        )
    }

    func requireBounceDockIconToggle(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        bounceDockIconToggle.requireExists(
            timeout: timeout,
            message: "The Bounce the Dock icon switch never showed up",
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
        let found = root.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", foundPrefix, foundPrefix)
        ).firstMatch
        let missing = root.descendants(matching: .any).matchingLabelOrValue(equalTo: "Not found").firstMatch
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
        let button = root.buttons.matching(
            NSPredicate(format: "label == %@ OR title == %@", "Use Automatic", "Use Automatic")
        ).firstMatch
        button.requireExists(
            timeout: timeout,
            message: "Use Automatic never showed up",
            file: file,
            line: line
        )
        XCTAssertFalse(button.isEnabled, "Use Automatic enables only after a chosen override", file: file, line: line)
    }

    /// Present so the row is on screen. Does not click it. The ellipsis is U+2026.
    func assertChooseButtonPresent(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = root.buttons.matching(
            NSPredicate(format: "label == %@ OR title == %@", "Choose…", "Choose…")
        ).firstMatch
        button.requireExists(
            timeout: timeout,
            message: "Choose… never showed up",
            file: file,
            line: line
        )
    }

    private static func showsSettingsTitle(_ window: XCUIElement) -> Bool {
        window.title.contains("Settings") || window.label.contains("Settings")
    }

    private static func showsNavigationTitle(_ window: XCUIElement) -> Bool {
        if window.title.contains("MKVForge Settings") || window.label.contains("MKVForge Settings") {
            return true
        }
        return window.descendants(matching: .any).matchingLabelOrValue(equalTo: "MKVForge Settings").firstMatch.exists
    }

    /// Switches and checkboxes only. A caption that contains the name must not pass
    /// as the switch. `matchingLabelOrValue` reads the control's own label or value.
    /// The finish switches include a subtitle in that label, so the match is
    /// `containing` on the control itself, not a raw descendant `containing` query.
    private func control(named name: String) -> XCUIElement {
        let switches = root.switches.matchingLabelOrValue(containing: name)
        if switches.firstMatch.exists {
            return switches.firstMatch
        }
        let checkBoxes = root.checkBoxes.matchingLabelOrValue(containing: name)
        if checkBoxes.firstMatch.exists {
            return checkBoxes.firstMatch
        }
        let titled = root.switches.matching(NSPredicate(format: "title == %@", name))
        if titled.firstMatch.exists {
            return titled.firstMatch
        }
        return root.switches.matchingLabelOrValue(equalTo: name).firstMatch
    }
}
