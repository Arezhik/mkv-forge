import XCTest

// UIT-P0-04. Remux run of one settled video-only prefix pair.
// Match on MKA Name stays at the default. Settings stays closed.
// The output file uses the video name.

@MainActor
final class RemuxRunUITests: BaseUITest {
    private static let videoFileName = "My Blue Heaven (1990) CRF21 DN 00_title_02.mkv"
    private static let audioFileName = "My Blue Heaven (1990).mka"

    override func prepareFixtures() async throws {
        let video = try fixtures.createValidMediaFile(
            in: fixtures.video,
            named: Self.videoFileName,
            includeAudio: false
        )
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: Self.audioFileName)
        try fixtures.settle(video)
        try fixtures.settle(audio)
    }

    func testRemuxRunFinishesDoneAndWritesMKV() throws {
        let videoStem = (Self.videoFileName as NSString).deletingPathExtension
        let videoURL = fixtures.video.appendingPathComponent(Self.videoFileName)
        let audioURL = fixtures.audio.appendingPathComponent(Self.audioFileName)
        let videoBefore = try Data(contentsOf: videoURL)
        let audioBefore = try Data(contentsOf: audioURL)
        let remux = try scanUntilReady(videoStem: videoStem)

        XCTContext.runActivity(named: "Run Remux") { _ in
            remux.clickPrimaryAction(titled: "Remux")
        }

        XCTContext.runActivity(named: "Row finishes Done") { _ -> Void in
            remux.queueRow(stem: videoStem).requireExactLabel(
                "\(videoStem), Done",
                timeout: UITestTimeout.batch
            )
        }

        XCTContext.runActivity(named: "Bottom bar shows one done") { _ in
            remux.bottomBar.assertSummary("Finished \u{00B7} 1 done", timeout: UITestTimeout.batch)
            remux.bottomBar.assertProgress(
                value: "1 of 1 complete",
                caption: "1 .mkv saved",
                timeout: UITestTimeout.batch
            )
            remux.bottomBar.assertShowInFinderVisible(timeout: UITestTimeout.batch)
        }

        try XCTContext.runActivity(named: "Output mkv is written and both sources stay") { _ -> Void in
            let output = fixtures.output.appendingPathComponent(Self.videoFileName)
            XCTAssertGreaterThan(fixtures.byteCount(at: output) ?? 0, 0, "The remuxed mkv is missing or empty")
            XCTAssertEqual(try Data(contentsOf: videoURL), videoBefore)
            XCTAssertEqual(try Data(contentsOf: audioURL), audioBefore)
        }
    }

    private func scanUntilReady(videoStem: String) throws -> RemuxPage {
        let page = SplitPage(app: app)

        let remux = XCTContext.runActivity(named: "Switch to Remux") { _ in
            page.switchToRemux()
        }

        XCTContext.runActivity(named: "Remux folders are on screen") { _ -> Void in
            remux.waitForRemuxFolders()
        }

        XCTContext.runActivity(named: "Video folder shows the video fixture") { _ in
            remux.videoFolder.assertShowsPathFragment("video")
        }

        XCTContext.runActivity(named: "Audio folder shows the audio fixture") { _ in
            remux.audioFolder.assertShowsPathFragment("audio")
        }

        XCTContext.runActivity(named: "Output folder shows the output fixture") { _ in
            remux.outputFolder.assertShowsPathFragment("output")
        }

        try XCTContext.runActivity(named: "Scan the Remux folders") { _ in
            try remux.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Prefix pair is Ready") { _ -> Void in
            remux.queueRow(stem: videoStem).requireExactLabel("\(videoStem), Ready")
        }

        return remux
    }
}
