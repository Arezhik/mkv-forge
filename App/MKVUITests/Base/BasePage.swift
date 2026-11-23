import XCTest

// Base page. A page owns the locators and actions for one screen.
// Navigation methods return the next page or component.

/// Shared holder for `XCUIApplication` and the screen root.
@MainActor
class BasePage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    /// The screen root. Subclasses override this when they own another window.
    var root: XCUIElement {
        app.windows.firstMatch
    }

    @discardableResult
    func waitUntilLoaded(timeout: TimeInterval = UITestTimeout.standard) -> XCUIElement {
        root.requireExists(timeout: timeout, message: "The window never showed up")
    }
}
