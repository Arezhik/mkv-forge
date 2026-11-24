import XCTest

// UIT-P1-03. A full MKV in Video is Ready with "Uses video only".
// One audio track and one subtitle track. Does not run.

@MainActor
final class RemuxVideoOnlyNoteUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let video = try fixtures.createValidMediaFile(
            in: fixtures.video,
            named: "Movie.mkv",
            includeAudio: true,
            includeSubtitles: true
        )
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "Movie.mka")
        try fixtures.settle(video)
        try fixtures.settle(audio)
    }

    func testFullMKVIsReadyWithUsesVideoOnly() throws {
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

        try XCTContext.runActivity(named: "Scan the Remux folders") { _ in
            try remux.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Movie is Ready and uses video only") { _ -> Void in
            remux.queueRow(stem: "Movie").requireExactLabel(
                "Movie, Ready, Uses video only, ignores 1 audio, 1 subtitle"
            )
        }

        XCTContext.runActivity(named: "Remux is enabled") { _ in
            remux.assertPrimary(titled: "Remux", enabled: true)
        }
    }
}
