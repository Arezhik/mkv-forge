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

        // SwiftUI Text on macOS puts the visible string in `value` and leaves `label`
        // empty. `matching` tests the element; `containing` only tests descendants,
        // so it never matches a StaticText.
        _ = app.outlines.firstMatch.waitForExistence(timeout: 5)
        let row = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "sample", "sample")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "The scanned sample.mkv row never showed up. Observed: \(observedQueueTexts(app))")
    }

    /// Labels and values from the queue outline, for a failed row assertion.
    private func observedQueueTexts(_ app: XCUIApplication) -> String {
        let outline = app.outlines.firstMatch
        guard outline.exists else {
            return "no outline; " + summarizedStaticTexts(app.staticTexts)
        }
        let rows = outline.descendants(matching: .outlineRow).allElementsBoundByIndex
        guard !rows.isEmpty else {
            return "outline with 0 rows; " + summarizedStaticTexts(outline.descendants(matching: .staticText))
        }
        let described = rows.prefix(6).map { row -> String in
            let texts = row.descendants(matching: .staticText).allElementsBoundByIndex.map { self.describe($0) }
            return "row(\(self.describe(row)) texts=[\(texts.joined(separator: "; "))])"
        }
        return described.joined(separator: " | ")
    }

    private func summarizedStaticTexts(_ query: XCUIElementQuery) -> String {
        let texts = query.allElementsBoundByIndex.prefix(12).map { self.describe($0) }
        return "staticTexts=[\(texts.joined(separator: "; "))]"
    }

    private func describe(_ element: XCUIElement) -> String {
        let value = element.value.map { "\($0)" } ?? ""
        return "label='\(element.label)' value='\(value)'"
    }
}
