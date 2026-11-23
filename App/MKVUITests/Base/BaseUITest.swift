import XCTest

// Base fixture. Playwright's test fixture / `beforeEach`.
// Subclasses get a launched app and temp folders. They do not launch the app again.
//
// Launch arguments are `--uitesting` only. Do not add `-ApplePersistenceIgnoreState YES`:
// together with `--uitesting` it suppresses the SwiftUI main Window (docs/LESSONS.md L34).
// The class is `@MainActor` because it owns `XCUIApplication`.

/// Launches MKVForge against a fresh `UITestFixtureBuilder` root.
@MainActor
class BaseUITest: XCTestCase {
    private(set) var app: XCUIApplication!
    private(set) var fixtures: UITestFixtureBuilder!

    /// Async so this `@MainActor` type can override setUp. XCTest's synchronous
    /// `setUp` / `setUpWithError` are nonisolated.
    override func setUp() async throws {
        continueAfterFailure = false
        fixtures = try UITestFixtures.make()
        try prepareFixtures()
        let application = XCUIApplication()
        // Replace, do not append. The only argument is `--uitesting`.
        application.launchArguments = ["--uitesting"]
        application.launchEnvironment = UITestFixtures.launchEnvironment(for: fixtures)
        application.launch()
        app = application
    }

    override func tearDown() async throws {
        // XCTest stops the app after the test. Remove the temp root here,
        // the same way `HelloWorldUITests` does.
        UITestFixtures.cleanup(fixtures)
        fixtures = nil
        app = nil
    }

    /// Seed dummy or real media before launch. The base does not create files.
    /// A window-and-folders smoke needs none. `HelloWorldUITests` creates
    /// `sample.mkv` / `sample.mka`. A Remux scan creates settled media here
    /// when that test moves onto this fixture.
    func prepareFixtures() throws {}
}
