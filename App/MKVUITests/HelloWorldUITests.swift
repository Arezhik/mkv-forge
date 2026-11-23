import XCTest

final class HelloWorldUITests: XCTestCase {
    private var fixtures: UITestFixtureBuilder!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtures = try UITestFixtureBuilder()
        // Dummy files stay in the queue after Scan (empty-file issue) and never need mkvmerge.
        try fixtures.createDummyFile(in: fixtures.input, named: "sample.mkv")
        try fixtures.createDummyFile(in: fixtures.video, named: "sample.mkv")
        try fixtures.createDummyFile(in: fixtures.audio, named: "sample.mka")
    }

    override func tearDownWithError() throws {
        fixtures?.cleanup()
        fixtures = nil
    }

    func testAppOpensMainWindow() throws {
        let app = XCUIApplication()
        // Do not add -ApplePersistenceIgnoreState YES: it combines with --uitesting to suppress the main Window.
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "UITEST_SOURCE_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
            "UITEST_VIDEO_DIR": fixtures.video.path,
            "UITEST_AUDIO_DIR": fixtures.audio.path,
        ]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "The main application window never showed up")

        let source = app.descendants(matching: .any)["sourceFolder"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), "The Source folder field never showed up")
        XCTAssertTrue(source.label.contains("Source") && source.label.contains("input"),
                      "The Source folder was not seeded from UITEST_SOURCE_DIR: \(source.label)")

        let output = app.descendants(matching: .any)["outputFolder"]
        XCTAssertTrue(output.waitForExistence(timeout: 2), "The Output folder field never showed up")
        XCTAssertTrue(output.label.contains("Output") && output.label.contains("output"),
                      "The Output folder was not seeded from UITEST_OUTPUT_DIR: \(output.label)")

        // Default mode is Split, so Scan reads Source. Video/Audio are also seeded for Remux.
        let scan = app.buttons["Scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5), "The Scan button never showed up")
        guard scan.isEnabled else {
            throw XCTSkip("Scan is disabled (needs MKVToolNix); folder seeding was verified")
        }
        scan.click()

        // The Name column shows the base name. The row's VoiceOver label is "sample, …".
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "sample")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The scanned sample.mkv row never showed up")
    }
}
