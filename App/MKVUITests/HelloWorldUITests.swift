import XCTest

final class HelloWorldUITests: XCTestCase {
    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for name in ["Source", "Output", "Video", "Audio"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
        fixtureRoot = root
    }

    override func tearDownWithError() throws {
        if let fixtureRoot {
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
    }

    func testAppOpensMainWindow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = [
            "UITEST_SOURCE_DIR": fixtureRoot.appendingPathComponent("Source", isDirectory: true).path,
            "UITEST_OUTPUT_DIR": fixtureRoot.appendingPathComponent("Output", isDirectory: true).path,
            "UITEST_VIDEO_DIR": fixtureRoot.appendingPathComponent("Video", isDirectory: true).path,
            "UITEST_AUDIO_DIR": fixtureRoot.appendingPathComponent("Audio", isDirectory: true).path,
        ]
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "The main application window never showed up")

        let source = app.descendants(matching: .any)["sourceFolder"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), "The Source folder field never showed up")
        XCTAssertTrue(source.label.contains("Source"),
                      "The Source folder was not seeded from UITEST_SOURCE_DIR: \(source.label)")

        let output = app.descendants(matching: .any)["outputFolder"]
        XCTAssertTrue(output.waitForExistence(timeout: 2), "The Output folder field never showed up")
        XCTAssertTrue(output.label.contains("Output"),
                      "The Output folder was not seeded from UITEST_OUTPUT_DIR: \(output.label)")
    }
}
