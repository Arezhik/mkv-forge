import XCTest

// UIT-P1-04 (priority P2). Choose Match pairs an ambiguous group. Unmatch restores it.
// Do not click Run. queueRow(stem: "X") matches every row, so labels are exact.

@MainActor
final class RemuxChooseMatchUITests: BaseUITest {
    private static let extendedIssue = "X Extended.mkv, Issue, Ambiguous match, 1 possible match"
    private static let audioIssue = "X.mka, Issue, Ambiguous match, 2 possible matches"
    private static let videoIssue = "X.mkv, Issue, Ambiguous match, 1 possible match"

    override func prepareFixtures() async throws {
        let extended = try fixtures.createValidMediaFile(in: fixtures.video, named: "X Extended.mkv", includeAudio: false)
        let video = try fixtures.createValidMediaFile(in: fixtures.video, named: "X.mkv", includeAudio: false)
        let audio = try fixtures.createValidMediaFile(in: fixtures.audio, named: "X.mka")
        try fixtures.settle(extended)
        try fixtures.settle(video)
        try fixtures.settle(audio)
    }

    func testChooseMatchPairsAmbiguousGroupAndUnmatchRestoresIt() throws {
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

        XCTContext.runActivity(named: "Three ambiguous rows and Remux disabled") { _ in
            remux.queueRow(stem: "X Extended.mkv").requireExactLabel(Self.extendedIssue)
            remux.queueRow(stem: "X.mka").requireExactLabel(Self.audioIssue)
            remux.queueRow(stem: "X.mkv").requireExactLabel(Self.videoIssue)
            remux.assertPrimary(titled: "Remux", enabled: false)
        }

        XCTContext.runActivity(named: "Choose Match pairs X.mka with X Extended.mkv") { _ in
            remux.queueRow(stem: "X.mka").chooseMatch("X Extended.mkv")
        }

        XCTContext.runActivity(named: "The pick is Ready and the other video is unmatched") { _ in
            remux.queueRow(stem: "X Extended").requireExactLabel(
                "X Extended paired with X.mka, Ready, matched by you"
            )
            remux.queueRow(stem: "X").requireExactLabel("X, Issue, No matching .mka in Audio folder")
            remux.queueRow(stem: "X.mka").assertExactLabelAbsent(Self.audioIssue)
            remux.assertPrimary(titled: "Remux", enabled: true)
        }

        XCTContext.runActivity(named: "Unmatch restores the ambiguous group") { _ in
            remux.queueRow(stem: "X Extended").clickUnmatch(audioFileName: "X.mka")
            remux.queueRow(stem: "X Extended.mkv").requireExactLabel(Self.extendedIssue)
            remux.queueRow(stem: "X.mka").requireExactLabel(Self.audioIssue)
            remux.queueRow(stem: "X.mkv").requireExactLabel(Self.videoIssue)
            remux.assertPrimary(titled: "Remux", enabled: false)
        }

        XCTContext.runActivity(named: "No output file is written") { _ in
            XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("X.mkv")))
            XCTAssertNil(fixtures.byteCount(at: fixtures.output.appendingPathComponent("X Extended.mkv")))
        }
    }
}
