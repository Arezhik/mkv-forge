import XCTest
@testable import MKVForgeCore

final class RemuxScanTests: XCTestCase {
    private typealias F = ScanFixture
    private let video = "/v/Video"
    private let audio = "/v/Audio"
    private let out = "/v/Finished"

    private func scan(video videoFiles: [FileEntry], audio audioFiles: [FileEntry], probes: [String: MediaProbe] = [:], existing: Set<String> = [], output: String? = nil) async throws -> (ScanResult, FakeIdentifier) {
        let identifier = FakeIdentifier(probes)
        let lister = FakeLister(folders: [video: videoFiles, audio: audioFiles, out: []], existing: existing)
        let result = try await F.scanner(lister, identifier).scanRemux(video: video, audio: audio, output: output ?? out)
        return (result, identifier)
    }

    private func pairProbes(_ name: String, video videoProbe: MediaProbe = F.media(.video), mka: MediaProbe = F.media(.audio, .subtitles)) -> [String: MediaProbe] {
        ["/v/Video/\(name).mkv": videoProbe, "/v/Audio/\(name).mka": mka]
    }

    func testPairIsReady() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A"))
        let item = try XCTUnwrap(result.item("A"))
        XCTAssertTrue(item.isReady)
        XCTAssertEqual(item.sourcePath, "/v/Video/A.mkv")
        XCTAssertEqual(item.mkaPath, "/v/Audio/A.mka")
        XCTAssertEqual(item.outputPath, "/v/Finished/A.mkv")
        XCTAssertEqual(item.sourceInfo?.count(of: .video), 1)
        XCTAssertEqual(item.mkaInfo?.count(of: .audio), 1)
        XCTAssertEqual(result.mode, .remux)
    }

    func testOrphansBothWaysUseTheContractWording() async throws {
        let (result, identifier) = try await scan(
            video: [F.file("A.mkv"), F.file("OnlyVideo.mkv")],
            audio: [F.file("A.mka"), F.file("OnlyAudio.mka")],
            probes: pairProbes("A")
        )
        XCTAssertEqual(result.items.map(\.baseName), ["A", "OnlyAudio", "OnlyVideo"])
        XCTAssertEqual(result.item("OnlyVideo")?.reasonText, "No matching .mka in Audio folder")
        XCTAssertEqual(result.item("OnlyAudio")?.reasonText, "No matching .mkv in Video folder")
        XCTAssertEqual(result.item("OnlyAudio")?.sourcePath, nil)
        XCTAssertEqual(result.item("OnlyAudio")?.mkaPath, "/v/Audio/OnlyAudio.mka")
        XCTAssertEqual(result.nameCount, 3)
        XCTAssertEqual(result.pairCount, 1)
        XCTAssertEqual(result.flaggedCount, 2)
        let calls = Set(await identifier.calls)
        XCTAssertEqual(calls, ["/v/Video/A.mkv", "/v/Audio/A.mka"])
    }

    func testMatchingIsCaseSensitiveButUnicodeEquivalent() async throws {
        let nfc = "Caf\u{E9}"
        let nfd = "Cafe\u{301}"
        let (result, _) = try await scan(
            video: [F.file("Show.mkv"), F.file(nfc + ".mkv")],
            audio: [F.file("show.mka"), F.file(nfd + ".mka")],
            probes: ["/v/Video/\(nfc).mkv": F.media(.video), "/v/Audio/\(nfd).mka": F.media(.audio)]
        )
        XCTAssertEqual(result.item("Show")?.issues, [.noMatchingMKA])
        XCTAssertEqual(result.item("show")?.issues, [.noMatchingMKV])
        XCTAssertEqual(result.item(nfc)?.isReady, true)
        XCTAssertEqual(result.nameCount, 3)
    }

    func testDuplicatesInEitherFolder() async throws {
        let (result, identifier) = try await scan(
            video: [F.file("A.mkv"), F.file("A.MKV"), F.file("B.mkv")],
            audio: [F.file("A.mka"), F.file("B.mka"), F.file("B.MKA")]
        )
        XCTAssertEqual(result.item("A")?.issues, [.duplicateName(.video, fileNames: ["A.MKV", "A.mkv"])])
        XCTAssertEqual(result.item("A")?.reasonText, "Duplicate name in Video folder")
        XCTAssertEqual(result.item("B")?.reasonText, "Duplicate name in Audio folder")
        XCTAssertEqual(result.item("B")?.helpText, "The Audio folder has more than one file with this name: B.MKA, B.mka. Keep one, then scan again.")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testExtraTracksInTheVideoFile() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A", video: F.media(.video, .audio, .audio, .subtitles)))
        XCTAssertEqual(result.item("A")?.issues, [.extraTracks(fileName: "A.mkv", audio: 2, subtitles: 1)])
        XCTAssertEqual(result.item("A")?.reasonText, "Video file has extra tracks (2 audio, 1 subtitle)")
        XCTAssertEqual(result.item("A")?.helpText, "A.mkv has 2 audio, 1 subtitle besides its video. Remux expects a video-only .mkv.")
    }

    func testExtraTrackCountWording() {
        XCTAssertEqual(ScanIssue.extraTracks(fileName: "A.mkv", audio: 0, subtitles: 2).reason, "Video file has extra tracks (2 subtitles)")
        XCTAssertEqual(ScanIssue.extraTracks(fileName: "A.mkv", audio: 1, subtitles: 0).reason, "Video file has extra tracks (1 audio)")
    }

    func testNoVideoTrackAndEmptyMKA() async throws {
        let (result, _) = try await scan(
            video: [F.file("A.mkv"), F.file("B.mkv")],
            audio: [F.file("A.mka"), F.file("B.mka")],
            probes: pairProbes("A", video: F.media(.subtitles)).merging(pairProbes("B", mka: F.media(.video))) { a, _ in a }
        )
        XCTAssertEqual(result.item("A")?.issues, [.noVideoTrack(fileName: "A.mkv"), .extraTracks(fileName: "A.mkv", audio: 0, subtitles: 1)])
        XCTAssertEqual(result.item("A")?.reasonText, "No video track in the .mkv (+1 more)")
        XCTAssertEqual(result.item("B")?.issues, [.mkaHasNoAudioOrSubtitles(fileName: "B.mka")])
        XCTAssertEqual(result.item("B")?.reasonText, "No audio or subtitle tracks in the .mka")
    }

    func testUnreadableAndNotMatroskaOnEachSide() async throws {
        let (result, _) = try await scan(
            video: [F.file("A.mkv"), F.file("B.mkv")],
            audio: [F.file("A.mka"), F.file("B.mka")],
            probes: pairProbes("A", video: .unreadable(detail: "open file error")).merging(pairProbes("B", mka: F.media(.audio, type: "AAC"))) { a, _ in a }
        )
        XCTAssertEqual(result.item("A")?.reasonText, "mkvmerge can't read the .mkv")
        XCTAssertEqual(result.item("A")?.helpText, "mkvmerge can't read A.mkv: open file error")
        XCTAssertEqual(result.item("B")?.issues, [.notMatroska(.audio, fileName: "B.mka", containerType: "AAC")])
    }

    func testCheapChecksOnBothSides() async throws {
        let (result, identifier) = try await scan(
            video: [F.file("A.mkv", size: 0), F.file("B.mkv")],
            audio: [F.file("A.mka"), F.file("B.mka", modified: F.scanTime)]
        )
        XCTAssertEqual(result.item("A")?.reasonText, "Empty .mkv (0 bytes)")
        XCTAssertEqual(result.item("B")?.reasonText, ".mka still changing (modified in the last minute)")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testExistingOutput() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A"), existing: ["/v/Finished/A.mkv"])
        XCTAssertEqual(result.item("A")?.issues, [.outputExists(fileName: "A.mkv")])
        XCTAssertEqual(result.item("A")?.reasonText, "A.mkv already exists in Output folder")
    }

    func testOutputFolderIsTheVideoFolder() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A"), existing: ["/v/Video/A.mkv"], output: "/v/Video/")
        XCTAssertEqual(result.item("A")?.issues, [.outputIsVideoFolder])
        XCTAssertEqual(result.item("A")?.reasonText, "Output folder is the Video folder")
    }

    func testSameFolderComparison() {
        XCTAssertTrue(FolderScanner.sameFolder("/a/b", "/a/b/"))
        XCTAssertTrue(FolderScanner.sameFolder("/a/b", "/a/c/../b"))
        XCTAssertFalse(FolderScanner.sameFolder("/a/b", "/a/B"))
    }

    func testUnreadableAudioFolderThrows() async {
        let scanner = F.scanner(FakeLister(folders: [video: []]), FakeIdentifier())
        do {
            _ = try await scanner.scanRemux(video: video, audio: audio, output: out)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? ScanError, .folderNotReadable(.audio, path: audio))
        }
    }
}
