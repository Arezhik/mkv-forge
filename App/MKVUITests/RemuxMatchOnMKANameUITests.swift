import XCTest

/// Remux happy path for Match on MKA Name (#33). The setting defaults on, and
/// `--uitesting` starts from a cleared defaults suite, so this test does not open Settings.
/// Edge cases stay in `RemuxScanTests`.
@MainActor
final class RemuxMatchOnMKANameUITests: XCTestCase {
    private static let videoFileName = "My Blue Heaven (1990) CRF21 DN 00_title_02.mkv"
    private static let audioFileName = "My Blue Heaven (1990).mka"
    private static let unmatchedFileName = "Unrelated Title (2001).mkv"

    private var fixtures: UITestFixtureBuilder!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtures = try UITestFixtureBuilder()
        // Video-only: a prefix pair is Ready with no "Uses video only" note.
        // A file modified in the last minute is "still changing", which blocks Ready
        // and adds a second issue next to an unmatched file's no-match reason.
        let video = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.videoFileName, includeAudio: false)
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: Self.audioFileName)
        let unmatched = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.unmatchedFileName, includeAudio: false)
        try settle(video)
        try settle(audio)
        try settle(unmatched)
    }

    override func tearDownWithError() throws {
        fixtures?.cleanup()
        fixtures = nil
    }

    func testRemuxMatchOnMKANameCriticalPath() throws {
        let videoStem = (Self.videoFileName as NSString).deletingPathExtension
        let unmatchedStem = (Self.unmatchedFileName as NSString).deletingPathExtension

        let app = XCUIApplication()
        // Do not add -ApplePersistenceIgnoreState YES: it combines with --uitesting to suppress the main Window.
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "UITEST_VIDEO_DIR": fixtures.video.path,
            "UITEST_AUDIO_DIR": fixtures.audio.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
        ]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "The main application window never showed up")

        selectRemux(in: app)
        assertSeededFolders(in: app)

        let scan = app.buttons["Scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5), "The Scan button never showed up")
        guard scan.isEnabled else {
            throw XCTSkip("Scan is disabled (needs MKVToolNix); folder seeding was verified")
        }
        scan.click()

        assertQueueRow(
            in: app,
            label: "\(videoStem), Ready",
            timeout: 10,
            message: "The matched video never showed up as Ready under its video stem"
        )
        assertQueueRow(
            in: app,
            label: "\(unmatchedStem), Issue, No matching .mka in Audio folder",
            timeout: 10,
            message: "The unmatched video never showed up as Issue with the no-match reason"
        )
    }

    /// The Mode picker is a segmented control. Its segments are buttons or radio buttons,
    /// scoped here so this does not hit the toolbar action that is also titled Remux.
    private func selectRemux(in app: XCUIApplication) {
        let mode = app.descendants(matching: .any)["modePicker"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5), "The Mode picker never showed up")
        let remux = mode.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR title == %@", "Remux", "Remux")
        ).firstMatch
        XCTAssertTrue(remux.waitForExistence(timeout: 2), "The Remux segment never showed up")
        remux.click()
    }

    private func assertSeededFolders(in app: XCUIApplication) {
        let video = app.descendants(matching: .any)["videoFolder"]
        XCTAssertTrue(video.waitForExistence(timeout: 5), "The Video folder field never showed up")
        XCTAssertTrue(video.label.contains("Video") && video.label.contains("video"),
                      "The Video folder was not seeded from UITEST_VIDEO_DIR: \(video.label)")

        let audio = app.descendants(matching: .any)["audioFolder"]
        XCTAssertTrue(audio.waitForExistence(timeout: 2), "The Audio folder field never showed up")
        XCTAssertTrue(audio.label.contains("Audio") && audio.label.contains("audio"),
                      "The Audio folder was not seeded from UITEST_AUDIO_DIR: \(audio.label)")

        let output = app.descendants(matching: .any)["outputFolder"]
        XCTAssertTrue(output.waitForExistence(timeout: 2), "The Output folder field never showed up")
        XCTAssertTrue(output.label.contains("Output") && output.label.contains("output"),
                      "The Output folder was not seeded from UITEST_OUTPUT_DIR: \(output.label)")
    }

    private func assertQueueRow(in app: XCUIApplication, label: String, timeout: TimeInterval, message: String) {
        let row = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "queueRow", label)
        ).firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            let shown = app.descendants(matching: .any)
                .matching(identifier: "queueRow")
                .allElementsBoundByIndex
                .map(\.label)
            XCTFail("\(message). Expected \(label). queueRow labels: \(shown)")
            return
        }
        XCTAssertEqual(row.label, label)
    }

    private func settle(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-120)],
            ofItemAtPath: url.path
        )
    }
}
