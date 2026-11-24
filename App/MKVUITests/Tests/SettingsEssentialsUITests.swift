import XCTest

// UIT-P0-05. Settings shows the tool, the match switch, and the finish switches.
// No media. `--uitesting` clears the defaults, so the three switches start on.
// Does not click Choose…, Get MKVToolNix, or Open System Settings….

@MainActor
final class SettingsEssentialsUITests: BaseUITest {
    override func prepareFixtures() async throws {
        // No media. The cleared UI-test defaults are the fixture.
    }

    func testSettingsShowsToolMatchSwitchAndFinishSwitches() throws {
        let settings = XCTContext.runActivity(named: "Open Settings") { _ in
            SettingsPage.open(in: app)
        }

        XCTContext.runActivity(named: "Settings window and navigation title") { _ in
            settings.waitForSettingsChrome()
        }

        XCTContext.runActivity(named: "MKVToolNix section and status") { _ in
            settings.requireMKVToolNixSection()
            settings.assertToolStatusFoundOrNotFound()
            settings.assertUseAutomaticDisabled()
            settings.assertChooseButtonPresent()
        }

        XCTContext.runActivity(named: "Match on MKA Name is on screen") { _ in
            settings.requireMatchOnMKANameToggle()
        }

        XCTContext.runActivity(named: "Finish switches are on screen") { _ in
            settings.requireSendNotificationToggle()
            settings.requireBounceDockIconToggle()
        }

        XCTContext.runActivity(named: "Send a notification toggles off and back on") { _ in
            settings.clickSendNotification()
            settings.waitUntilSwitch(named: "Send a notification", isOn: false)
            settings.clickSendNotification()
            settings.waitUntilSwitch(named: "Send a notification", isOn: true)
        }
    }
}
