import XCTest
@testable import MKVForgeCore

final class IdentificationParserTests: XCTestCase {
    private func parse(_ json: String, status: Int32 = 0) -> MediaProbe {
        IdentificationParser.parse(status: status, output: Data(json.utf8))
    }

    func testFullFileOnBothSchemaVersions() {
        for json in [IdentifyFixtures.full103, IdentifyFixtures.full82] {
            guard case let .readable(info) = parse(json) else { return XCTFail("full file should be readable") }
            XCTAssertTrue(info.isMatroska)
            XCTAssertEqual(info.tracks.map(\.kind), [.video, .audio, .audio, .subtitles])
            XCTAssertEqual(info.tracks.map(\.id), [0, 1, 2, 3])
            XCTAssertEqual(info.tracks.map(\.codec), ["AVC/H.264/MPEG-4p10", "AAC", "Opus", "SubRip/SRT"])
            XCTAssertEqual(info.chapterEditions, 1)
            XCTAssertEqual(info.ids(of: [.audio, .subtitles]), [1, 2, 3])
        }
    }

    func testTrackUIDAboveInt64DoesNotBreakDecoding() {
        // The subtitle track's uid is 17389891100597187705, above Int64.max.
        XCTAssertTrue(IdentifyFixtures.full103.contains("17389891100597187705"))
        guard case .readable = parse(IdentifyFixtures.full103) else { return XCTFail("uid must be ignored") }
    }

    func testTrackKinds() {
        for (json, kinds) in [
            (IdentifyFixtures.noAudio103, [TrackKind.video, .subtitles]), (IdentifyFixtures.noAudio82, [.video, .subtitles]),
            (IdentifyFixtures.noSubtitles103, [.video, .audio]), (IdentifyFixtures.noSubtitles82, [.video, .audio]),
            (IdentifyFixtures.videoOnly103, [.video]), (IdentifyFixtures.videoOnly82, [.video]),
        ] {
            guard case let .readable(info) = parse(json) else { return XCTFail("should be readable") }
            XCTAssertEqual(info.tracks.map(\.kind), kinds)
            XCTAssertEqual(info.chapterEditions, 0)
        }
    }

    func testEmptyAndGarbageExitZeroButAreUnreadable() {
        for json in [IdentifyFixtures.empty103, IdentifyFixtures.empty82, IdentifyFixtures.garbage103, IdentifyFixtures.garbage82] {
            XCTAssertEqual(parse(json, status: 0), .unreadable(detail: nil))
        }
    }

    func testTruncatedFileIsMatroskaWithNoTracks() {
        for json in [IdentifyFixtures.truncated103, IdentifyFixtures.truncated82] {
            XCTAssertEqual(parse(json), .readable(MediaInfo(containerType: "Matroska", tracks: [], chapterEditions: 0)))
        }
    }

    func testOtherContainerIsReadableButNotMatroska() {
        guard case let .readable(info) = parse(IdentifyFixtures.srtNamedMKV103) else { return XCTFail("SRT is readable") }
        XCTAssertEqual(info.containerType, "SRT subtitles")
        XCTAssertFalse(info.isMatroska)
    }

    func testCannotOpenUsesFirstErrorLine() {
        XCTAssertEqual(
            parse(IdentifyFixtures.cannotOpen103, status: 2),
            .unreadable(detail: "The file 'missing.mkv' could not be opened for reading: open file error.")
        )
    }

    func testNonJSONOutput() {
        XCTAssertEqual(IdentificationParser.parse(status: 2, output: Data("Error: no destination".utf8)), .unreadable(detail: "mkvmerge exit 2"))
        XCTAssertEqual(IdentificationParser.parse(status: 0, output: Data()), .unreadable(detail: "mkvmerge printed no identification"))
    }

    func testNonZeroExitWithoutErrorsIsUnreadable() {
        XCTAssertEqual(parse(IdentifyFixtures.videoOnly103, status: 2), .unreadable(detail: "mkvmerge exit 2"))
    }

    func testUnknownTrackTypeIsOther() {
        let json = #"{"container":{"recognized":true,"supported":true,"type":"Matroska"},"tracks":[{"id":0,"type":"buttons","codec":"x"}],"errors":[]}"#
        XCTAssertEqual(parse(json), .readable(MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .other, codec: "x")])))
    }
}
