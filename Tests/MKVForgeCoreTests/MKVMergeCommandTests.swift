import XCTest
@testable import MKVForgeCore

final class MKVMergeCommandTests: XCTestCase {
    private func clear(_ id: Int) -> [String] {
        [
            "--track-name", "\(id):", "--language", "\(id):und",
            "--default-track-flag", "\(id):0", "--forced-display-flag", "\(id):0",
            "--commentary-flag", "\(id):0", "--original-flag", "\(id):0",
            "--hearing-impaired-flag", "\(id):0", "--visual-impaired-flag", "\(id):0",
            "--text-descriptions-flag", "\(id):0",
        ]
    }

    func testSplitKeepsAudioAndSubtitlesAndClearsEachOne() throws {
        let tracks = [TrackInfo(id: 0, kind: .video), TrackInfo(id: 3, kind: .subtitles), TrackInfo(id: 1, kind: .audio), TrackInfo(id: 2, kind: .audio), TrackInfo(id: 4, kind: .other)]
        let arguments = try MKVMergeCommand.split(source: "/in/@A -x.mkv", output: "/out/@A -x.mka", tracks: tracks)
        XCTAssertEqual(arguments,
            ["-o", "/out/@A -x.mka", "--title", "", "--no-date", "--disable-track-statistics-tags",
             "--no-video", "--no-attachments", "--no-global-tags", "--no-track-tags"]
            + clear(1) + clear(2) + clear(3) + ["/in/@A -x.mkv"])
    }

    func testSplitFromTheFullFixtureClearsOnlyReportedIDs() throws {
        guard case let .readable(info) = IdentificationParser.parse(status: 0, output: Data(IdentifyFixtures.full103.utf8)) else { return XCTFail() }
        let arguments = try MKVMergeCommand.split(source: "/in/full.mkv", output: "/out/full.mka", tracks: info.tracks)
        let ids = Set(arguments.filter { $0.hasSuffix(":und") })
        XCTAssertEqual(ids, ["1:und", "2:und", "3:und"])
        XCTAssertFalse(arguments.contains("0:und"))
    }

    func testRemuxTakesVideoFromTheMKVAndEverythingFromTheMKA() throws {
        let arguments = try MKVMergeCommand.remux(video: "/v/A.mkv", mka: "/a/A.mka", output: "/o/A.mkv", videoTracks: [TrackInfo(id: 0, kind: .video)])
        XCTAssertEqual(arguments,
            ["-o", "/o/A.mkv", "--title", "", "--no-date", "--disable-track-statistics-tags",
             "--no-audio", "--no-subtitles", "--no-chapters", "--no-attachments", "--no-global-tags", "--no-track-tags"]
            + clear(0) + ["/v/A.mkv",
             "--no-video", "--no-attachments", "--no-global-tags", "--no-track-tags", "/a/A.mka"])
    }

    func testNoTracksMeansNoTrackOptions() throws {
        let arguments = try MKVMergeCommand.split(source: "/a.mkv", output: "/a.mka", tracks: [])
        XCTAssertFalse(arguments.contains("--language"))
        XCTAssertEqual(MKVMergeCommand.clearTrackOptions(for: []), [])
    }

    func testRelativePathsAreRejected() {
        XCTAssertThrowsError(try MKVMergeCommand.split(source: "A.mkv", output: "/o/A.mka", tracks: [])) { error in
            XCTAssertEqual(error as? CommandError, .relativePath("A.mkv"))
        }
        XCTAssertThrowsError(try MKVMergeCommand.remux(video: "/v/A.mkv", mka: "@opts.json", output: "/o/A.mkv", videoTracks: []))
        XCTAssertThrowsError(try MKVMergeCommand.remux(video: "/v/A.mkv", mka: "/a/A.mka", output: "-o", videoTracks: []))
    }
}
