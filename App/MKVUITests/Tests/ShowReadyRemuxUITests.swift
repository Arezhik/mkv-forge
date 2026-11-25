import XCTest

// Show Ready in Remux. One unmatched video is Issue. One prefix-matched pair is Ready.
// Match on MKA Name defaults on. `--uitesting` clears defaults, so this test does not
// open Settings. Launch arguments stay `--uitesting`.

@MainActor
final class ShowReadyRemuxUITests: BaseUITest {
    private static let videoFileName = "My Blue Heaven (1990) CRF21 DN 00_title_02.mkv"
    private static let audioFileName = "My Blue Heaven (1990).mka"
    private static let unmatchedFileName = "Unrelated Title (2001).mkv"

    override func prepareFixtures() async throws {
        let video = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.videoFileName, includeAudio: false)
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: Self.audioFileName)
        let unmatched = try fixtures.createValidMediaFile(in: fixtures.video, named: Self.unmatchedFileName, includeAudio: false)
        try fixtures.settle(video)
        try fixtures.settle(audio)
        try fixtures.settle(unmatched)
    }

    func testShowReadyHidesTheUnmatchedRowAndKeepsTheMatchedRow() throws {
        let videoStem = (Self.videoFileName as NSString).deletingPathExtension
        let unmatchedStem = (Self.unmatchedFileName as NSString).deletingPathExtension
        let page = SplitPage(app: app)

        let remux = XCTContext.runActivity(named: "Switch to Remux") { _ in
            page.switchToRemux()
        }

        XCTContext.runActivity(named: "Remux folders are on screen") { _ -> Void in
            remux.waitForRemuxFolders()
        }

        try XCTContext.runActivity(named: "Scan the Remux folders") { _ in
            try remux.clickScanOrSkip()
        }

        XCTContext.runActivity(named: "Issue and Ready are both visible") { _ -> Void in
            remux.queueRow(stem: unmatchedStem).requireExactLabel(
                "\(unmatchedStem), Issue, No matching .mka in Audio folder"
            )
            remux.queueRow(stem: videoStem).requireExactLabel("\(videoStem), Ready")
        }

        XCTContext.runActivity(named: "Turn Show Ready on") { _ in
            remux.setShowReady(true)
        }

        XCTContext.runActivity(named: "Issue is hidden and Ready stays") { _ -> Void in
            remux.queueRow(stem: unmatchedStem).assertExactLabelAbsent(
                "\(unmatchedStem), Issue, No matching .mka in Audio folder"
            )
            remux.queueRow(stem: videoStem).requireExactLabel("\(videoStem), Ready")
        }

        XCTContext.runActivity(named: "Turn Show Ready off") { _ in
            remux.setShowReady(false)
        }

        XCTContext.runActivity(named: "Issue returns") { _ -> Void in
            remux.queueRow(stem: unmatchedStem).requireExactLabel(
                "\(unmatchedStem), Issue, No matching .mka in Audio folder"
            )
            remux.queueRow(stem: videoStem).requireExactLabel("\(videoStem), Ready")
        }
    }
}
