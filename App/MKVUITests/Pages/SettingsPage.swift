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

    /// Section header "MKVToolNix". SwiftUI `Text` may expose it as `value`.
    var mkvToolNixSection: XCUIElement {
        root.staticTexts.matchingLabelOrValue(containing: "MKVToolNix").firstMatch
    }

    var sendNotificationToggle: XCUIElement {
        control(named: "Send a notification")
    }

    var bounceDockIconToggle: XCUIElement {
        control(named: "Bounce the Dock icon")
    }

    func clickSendNotification() {
        sendNotificationToggle.clickWhenReady(message: "The Send a notification toggle never showed up")
    }

    func clickBounceDockIcon() {
        bounceDockIconToggle.clickWhenReady(message: "The Bounce the Dock icon toggle never showed up")
    }

    private func control(named name: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@ OR title CONTAINS %@",
            name, name, name
        )
        let switches = root.switches.matching(predicate)
        if switches.firstMatch.exists {
            return switches.firstMatch
        }
        let checkBoxes = root.checkBoxes.matching(predicate)
        if checkBoxes.firstMatch.exists {
            return checkBoxes.firstMatch
        }
        return root.descendants(matching: .any).matching(predicate).firstMatch
    }
}
