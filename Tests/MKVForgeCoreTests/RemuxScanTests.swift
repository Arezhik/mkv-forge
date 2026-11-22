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

    func testFullVideoFileIsReadyAndUsesVideoOnly() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A", video: F.media(.video, .audio, .audio, .subtitles)))
        let item = try XCTUnwrap(result.item("A"))
        XCTAssertTrue(item.isReady)
        XCTAssertEqual(item.issues, [])
        XCTAssertEqual(item.notes, [.videoOnly(fileName: "A.mkv", audio: 2, subtitles: 1)])
        XCTAssertEqual(item.reasonText, "Uses video only, ignores 2 audio, 1 subtitle")
        XCTAssertEqual(item.helpText, "A.mkv also has 2 audio, 1 subtitle. Remux takes only its video track; the audio, subtitles and chapters come from the .mka.")
        XCTAssertEqual(result.readyCount, 1)
        XCTAssertEqual(RunJob.jobs(from: result, checked: ["A"]).map(\.baseName), ["A"])
    }

    func testVideoOnlyNoteWording() {
        XCTAssertEqual(ScanNote.videoOnly(fileName: "A.mkv", audio: 0, subtitles: 2).reason, "Uses video only, ignores 2 subtitles")
        XCTAssertEqual(ScanNote.videoOnly(fileName: "A.mkv", audio: 1, subtitles: 0).reason, "Uses video only, ignores 1 audio")
    }

    func testAVideoOnlyFileHasNoNote() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A"))
        XCTAssertEqual(result.item("A")?.notes, [])
        XCTAssertNil(result.item("A")?.reasonText)
    }

    func testAnIssueHidesTheNote() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka")], probes: pairProbes("A", video: F.media(.video, .audio)), existing: ["/v/Finished/A.mkv"])
        let item = try XCTUnwrap(result.item("A"))
        XCTAssertFalse(item.isReady)
        XCTAssertEqual(item.reasonText, "A.mkv already exists in Output folder")
        XCTAssertEqual(item.notes, [.videoOnly(fileName: "A.mkv", audio: 1, subtitles: 0)])
    }

    func testNoVideoTrackAndEmptyMKA() async throws {
        let (result, _) = try await scan(
            video: [F.file("A.mkv"), F.file("B.mkv")],
            audio: [F.file("A.mka"), F.file("B.mka")],
            probes: pairProbes("A", video: F.media(.subtitles)).merging(pairProbes("B", mka: F.media(.video))) { a, _ in a }
        )
        XCTAssertEqual(result.item("A")?.issues, [.noVideoTrack(fileName: "A.mkv")])
        XCTAssertEqual(result.item("A")?.reasonText, "No video track in the .mkv")
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

    // MARK: Match on MKA Name (issue #33)

    private func scanMatching(video videoFiles: [FileEntry], audio audioFiles: [FileEntry], probes: [String: MediaProbe] = [:], existing: Set<String> = []) async throws -> (ScanResult, FakeIdentifier) {
        let identifier = FakeIdentifier(probes)
        let lister = FakeLister(folders: [video: videoFiles, audio: audioFiles, out: []], existing: existing)
        let result = try await F.scanner(lister, identifier).scanRemux(video: video, audio: audio, output: out, matchOnMKAName: true)
        return (result, identifier)
    }

    func testXMkaWithTwoVideosIsAllAmbiguous() async throws {
        let (result, _) = try await scanMatching(
            video: [F.file("X.mkv"), F.file("X Extended.mkv")],
            audio: [F.file("X.mka")],
            probes: [
                "/v/Video/X.mkv": F.media(.video),
                "/v/Video/X Extended.mkv": F.media(.video),
                "/v/Audio/X.mka": F.media(.audio, .subtitles),
            ]
        )
        XCTAssertEqual(result.items.map(\.baseName), ["X Extended.mkv", "X.mka", "X.mkv"])
        XCTAssertEqual(result.readyCount, 0)
        XCTAssertTrue(result.items.allSatisfy { $0.matchMenu != nil && !$0.isReady && !$0.matchedByYou })
        XCTAssertEqual(result.items.map(\.reasonText), ["Ambiguous match", "Ambiguous match", "Ambiguous match"])
        XCTAssertEqual(result.item("X.mka")?.matchMenu?.candidates.map(\.fileName), ["X Extended.mkv", "X.mkv"])
        XCTAssertEqual(result.item("X.mkv")?.matchMenu?.candidates.map(\.fileName), ["X.mka"])
        XCTAssertEqual(result.item("X Extended.mkv")?.matchMenu?.side, .video)
        XCTAssertEqual(result.item("X.mka")?.matchMenu?.side, .audio)
    }

    func testAlienPrefixMatchesCaseInsensitive() async throws {
        let (result, _) = try await scanMatching(
            video: [F.file("Aliens (1979).mkv")],
            audio: [F.file("Alien.mka")],
            probes: ["/v/Video/Aliens (1979).mkv": F.media(.video), "/v/Audio/Alien.mka": F.media(.audio, .subtitles)]
        )
        let item = try XCTUnwrap(result.item("Aliens (1979)"))
        XCTAssertTrue(item.isReady)
        XCTAssertFalse(item.matchedByYou)
        XCTAssertNil(item.matchMenu)
        XCTAssertEqual(item.outputPath, "/v/Finished/Aliens (1979).mkv")
        XCTAssertEqual(item.counterpartName, "Alien.mka")
        XCTAssertEqual(result.readyCount, 1)
        XCTAssertEqual(result.items.count, 1)

        let (cased, _) = try await scanMatching(
            video: [F.file("ALIENS (1979).mkv")],
            audio: [F.file("alien.mka")],
            probes: ["/v/Video/ALIENS (1979).mkv": F.media(.video), "/v/Audio/alien.mka": F.media(.audio, .subtitles)]
        )
        let folded = try XCTUnwrap(cased.item("ALIENS (1979)"))
        XCTAssertTrue(folded.isReady)
        XCTAssertEqual(folded.outputPath, "/v/Finished/ALIENS (1979).mkv")
        XCTAssertEqual(folded.counterpartName, "alien.mka")
    }

    func testCloseNamesDoNotMatch() async throws {
        let cases = [
            ("My Blue Heven (1990).mka", "My Blue Heaven (1990) CRF21.mkv"),
            ("My.Blue.Heaven.1990.mka", "My Blue Heaven (1990) CRF21.mkv"),
            ("My Blue  Heaven (1990).mka", "My Blue Heaven (1990) CRF21.mkv"),
        ]
        for (audioName, videoName) in cases {
            let (result, identifier) = try await scanMatching(video: [F.file(videoName)], audio: [F.file(audioName)])
            let videoStem = (videoName as NSString).deletingPathExtension
            let audioStem = (audioName as NSString).deletingPathExtension
            XCTAssertEqual(result.items.count, 2, audioName)
            XCTAssertFalse(result.items.contains(where: \.isReady), audioName)
            XCTAssertFalse(result.items.contains(where: \.matchedByYou), audioName)
            XCTAssertEqual(result.item(videoStem)?.issues, [.noMatchingMKA], audioName)
            XCTAssertEqual(result.item(audioStem)?.issues, [.noMatchingMKV], audioName)
            XCTAssertEqual(result.item(videoStem)?.reasonText, "No matching .mka in Audio folder", audioName)
            XCTAssertEqual(result.item(audioStem)?.reasonText, "No matching .mkv in Video folder", audioName)
            let calls = await identifier.calls
            XCTAssertTrue(calls.isEmpty, audioName)
        }
    }

    func testPicksResetOnRescanFolderChangeAndSettingChange() async throws {
        let probes = [
            "/v/Video/X.mkv": F.media(.video),
            "/v/Video/X Extended.mkv": F.media(.video),
            "/v/Audio/X.mka": F.media(.audio, .subtitles),
        ]
        let files = (
            video: [F.file("X.mkv"), F.file("X Extended.mkv")],
            audio: [F.file("X.mka")]
        )
        let (result, _) = try await scanMatching(video: files.video, audio: files.audio, probes: probes)
        let pick = RemuxPick(audioPath: "/v/Audio/X.mka", videoPath: "/v/Video/X Extended.mkv")

        var state = ModeState(mode: .remux)
        state.setFolder(video, for: .video)
        state.setFolder(audio, for: .audio)
        state.setFolder(out, for: .output)
        state.applyScan(result)
        XCTAssertEqual(state.applyMatchPicks([pick]), "X Extended")
        XCTAssertEqual(state.picks, [pick])
        XCTAssertTrue(state.row("X Extended")?.item.matchedByYou == true)
        XCTAssertTrue(state.row("X Extended")?.isChecked == true)

        let (again, _) = try await scanMatching(video: files.video, audio: files.audio, probes: probes)
        state.applyScan(again)
        XCTAssertTrue(state.picks.isEmpty)
        XCTAssertFalse(state.rows.contains { $0.item.matchedByYou })
        XCTAssertEqual(state.rows.filter { $0.item.matchMenu != nil }.count, 3)

        state.applyMatchPicks([pick])
        state.setFolder("/v/Other", for: .audio)
        XCTAssertNil(state.scan)
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertTrue(state.picks.isEmpty)

        state.setFolder(audio, for: .audio)
        state.applyScan(again)
        state.applyMatchPicks([pick])
        state.matchSettingChanged()
        XCTAssertNil(state.scan)
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertEqual(state.folder(.video), video, "a setting change keeps the folders")

        var split = UIFixture.state([UIFixture.ready("A")])
        split.matchSettingChanged()
        XCTAssertNotNil(split.scan)
        XCTAssertEqual(split.rows.map(\.id), ["A"])
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
