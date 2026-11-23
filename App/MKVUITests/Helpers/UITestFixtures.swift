import XCTest

// Helpers: a thin forwarder to `UITestFixtureBuilder`.
// The builder stays at `App/MKVUITests/UITestFixtureBuilder.swift`. This file
// only creates it, cleans it up, and maps its folders onto the launch environment.
// File-generation helpers stay on the builder. Do not duplicate them here.

/// Creates and cleans the temp fixture root, and builds the `UITEST_*` environment.
enum UITestFixtures {
    static func make() throws -> UITestFixtureBuilder {
        try UITestFixtureBuilder()
    }

    static func cleanup(_ fixtures: UITestFixtureBuilder?) {
        fixtures?.cleanup()
    }

    /// Keys read by `UITestingLaunch.folderSeed`.
    /// `input` is Split's Source folder. `video` and `audio` are Remux.
    /// `output` is the Output folder in both modes.
    static func launchEnvironment(for fixtures: UITestFixtureBuilder) -> [String: String] {
        [
            "UITEST_SOURCE_DIR": fixtures.input.path,
            "UITEST_OUTPUT_DIR": fixtures.output.path,
            "UITEST_VIDEO_DIR": fixtures.video.path,
            "UITEST_AUDIO_DIR": fixtures.audio.path,
        ]
    }
}
