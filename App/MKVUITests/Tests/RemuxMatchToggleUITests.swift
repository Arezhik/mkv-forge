import XCTest

// UIT-P1-05. Turning Match on MKA Name off clears Remux and exact-matches only.
// Split stays unscanned. No Run.

@MainActor
final class RemuxMatchToggleUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let exactVideo = try fixtures.createValidMediaFile(in: fixtures.video, named: "Exact.mkv", includeAudio: false)
        let extended = try fixtures.createValidMediaFile(in: fixtures.video, named: "Show Extended.mkv", includeAudio: false)
        let exactAudio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "Exact.mka")
        let showAudio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "Show.mka")
        try fixtures.settle(exactVideo)
        try fixtures.settle(extended)
        try fixtures.settle(exactAudio)
        try fixtures.settle(showAudio)
    }

    func testMatchOnMKANameOffClearsRemuxAndExactMatchesOnly() throws {
        let page = SplitPage(app: app)

        let remux = XCTContext.runActivity(named: "Switch to Remux") { _ in
            page.switchToRemux()
        }

        XCTContext.runActivity(named: "Remux folders are on screen") { _ in
            remux.waitForRemuxFolders()
            remux.videoFolder.assertShowsPathFragment("video")
            remux.audioFolder.assertShowsPathFragment("audio")
            remux.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan with Match on MKA Name on") { _ in
            try remux.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Exact pair and prefix pair are Ready") { _ in
            remux.queueRow(stem: "Exact").requireExactLabel("Exact, Ready")
            remux.queueRow(stem: "Show Extended").requireExactLabel("Show Extended, Ready")
        }

        XCTContext.runActivity(named: "Turn Match on MKA Name off") { _ in
            let settings = SettingsPage.open(in: app)
            settings.waitForSettingsChrome()
            settings.clickMatchOnMKAName()
            settings.waitUntilSwitch(named: "Match on MKA Name", isOn: false)
        }

        XCTContext.runActivity(named: "Return to the MKVForge window") { _ in
            remux.activateMainWindow()
        }

        XCTContext.runActivity(named: "Remux queue is cleared") { _ in
            remux.assertScanStatus(equalTo: "Not scanned yet")
            remux.assertPrimary(titled: "Remux", enabled: false)
        }

        try XCTContext.runActivity(named: "Scan again with exact names") { _ in
            try remux.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Only the exact pair is Ready") { _ in
            remux.queueRow(stem: "Exact").requireExactLabel("Exact, Ready")
            remux.queueRow(stem: "Show Extended").requireExactLabel(
                "Show Extended, Issue, No matching .mka in Audio folder"
            )
            remux.queueRow(stem: "Show").requireExactLabel(
                "Show, Issue, No matching .mkv in Video folder"
            )
        }
    }
}
