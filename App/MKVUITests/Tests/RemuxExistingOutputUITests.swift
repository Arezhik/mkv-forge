import XCTest

// UIT-P1-06. Match on MKA Name on: an existing .mkv is an Issue and is not overwritten.
// Output file name is the video name. Settings stays closed.

@MainActor
final class RemuxExistingOutputUITests: BaseUITest {
    override func prepareFixtures() async throws {
        let keepVideo = try fixtures.createValidMediaFile(in: fixtures.video, named: "keep.mkv", includeAudio: false)
        let freshVideo = try fixtures.createValidMediaFile(in: fixtures.video, named: "fresh.mkv", includeAudio: false)
        let keepAudio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "keep.mka")
        let freshAudio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "fresh.mka")
        try fixtures.settle(keepVideo)
        try fixtures.settle(freshVideo)
        try fixtures.settle(keepAudio)
        try fixtures.settle(freshAudio)
        _ = try fixtures.createDummyFile(in: fixtures.output, named: "keep.mkv")
    }

    func testExistingMKVIsIssueAndIsNotOverwritten() throws {
        let keepOutput = fixtures.output.appendingPathComponent("keep.mkv")
        let keepBefore = try Data(contentsOf: keepOutput)
        XCTAssertEqual(keepBefore.count, 0, "The pre-existing keep.mkv should be 0 bytes")
        let keepVideo = fixtures.video.appendingPathComponent("keep.mkv")
        let freshVideo = fixtures.video.appendingPathComponent("fresh.mkv")
        let keepAudio = fixtures.audio.appendingPathComponent("keep.mka")
        let freshAudio = fixtures.audio.appendingPathComponent("fresh.mka")
        let sources = try [keepVideo, freshVideo, keepAudio, freshAudio].map { url in
            (url, try Data(contentsOf: url))
        }

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

        XCTContext.runActivity(named: "keep is an existing-output Issue and fresh is Ready") { _ in
            remux.queueRow(stem: "keep").requireExactLabel("keep, Issue, Output already exists")
            remux.queueRow(stem: "fresh").requireExactLabel("fresh, Ready")
        }

        XCTContext.runActivity(named: "Run Remux") { _ in
            remux.clickPrimaryAction(titled: "Remux")
        }

        XCTContext.runActivity(named: "fresh finishes and keep stays flagged") { _ in
            remux.queueRow(stem: "fresh").requireExactLabel("fresh, Done", timeout: UITestTimeout.batch)
            remux.queueRow(stem: "keep").requireExactLabel(
                "keep, Issue, Output already exists",
                timeout: UITestTimeout.batch
            )
        }

        XCTContext.runActivity(named: "Bottom bar counts one done and one flagged") { _ in
            remux.bottomBar.assertSummary(
                "Finished \u{00B7} 1 done \u{00B7} 1 flagged",
                timeout: UITestTimeout.batch
            )
        }

        try XCTContext.runActivity(named: "keep.mkv is unchanged, fresh.mkv is written, sources stay") { _ -> Void in
            XCTAssertEqual(try Data(contentsOf: keepOutput), keepBefore)
            let freshOutput = fixtures.output.appendingPathComponent("fresh.mkv")
            XCTAssertGreaterThan(fixtures.byteCount(at: freshOutput) ?? 0, 0, "fresh.mkv is missing or empty")
            for (url, before) in sources {
                XCTAssertEqual(try Data(contentsOf: url), before, "\(url.lastPathComponent) changed")
            }
        }
    }
}
