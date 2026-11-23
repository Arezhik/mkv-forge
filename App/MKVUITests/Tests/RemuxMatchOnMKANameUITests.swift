import XCTest

/// Remux happy path for Match on MKA Name (#33). The setting defaults on, and
/// `--uitesting` starts from a cleared defaults suite, so this test does not open Settings.
/// Edge cases stay in `RemuxScanTests`.
@MainActor
final class RemuxMatchOnMKANameUITests: BaseUITest {
    private static let videoFileName = "My Blue Heaven (1990) CRF21 DN 00_title_02.mkv"
    private static let audioFileName = "My Blue Heaven (1990).mka"
    private static let unmatchedFileName = "Unrelated Title (2001).mkv"

    override func prepareFixtures() async throws {
        // Video-only: a prefix pair is Ready with no "Uses video only" note.
        // A file modified in the last minute is "still changing", which blocks Ready
        // and adds a second issue next to an unmatched file's no-match reason.
        // `createValidMediaFile` throws `XCTSkip` when ffmpeg is missing.
        let video = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.videoFileName, includeAudio: false)
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: Self.audioFileName)
        let unmatched = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.unmatchedFileName, includeAudio: false)
        try fixtures.settle(video)
        try fixtures.settle(audio)
        try fixtures.settle(unmatched)
    }

    func testRemuxMatchOnMKANameCriticalPath() throws {
        let videoStem = (Self.videoFileName as NSString).deletingPathExtension
        let unmatchedStem = (Self.unmatchedFileName as NSString).deletingPathExtension

        let page = SplitPage(app: app)

        // The segment inside modePicker, not the toolbar button that is also titled Remux.
        let remux = XCTContext.runActivity(named: "Switch to Remux") { _ in
            page.switchToRemux()
        }

        XCTContext.runActivity(named: "Remux folders are on screen") { _ in
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

        XCTContext.runActivity(named: "Matched video is Ready") { _ in
            remux.queueRow(stem: videoStem).requireExactLabel("\(videoStem), Ready")
        }

        XCTContext.runActivity(named: "Unmatched video is an Issue") { _ in
            remux.queueRow(stem: unmatchedStem).requireExactLabel(
                "\(unmatchedStem), Issue, No matching .mka in Audio folder"
            )
        }
    }
}
