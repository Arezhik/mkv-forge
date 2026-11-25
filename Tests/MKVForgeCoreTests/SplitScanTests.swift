import XCTest
@testable import MKVForgeCore

final class SplitScanTests: XCTestCase {
    private typealias F = ScanFixture
    private let src = "/media/Rips"
    private let out = "/media/Audio"

    private func scan(_ files: [FileEntry], probes: [String: MediaProbe] = [:], existing: Set<String> = []) async throws -> (ScanResult, FakeIdentifier) {
        let identifier = FakeIdentifier(probes)
        let lister = FakeLister(folders: [src: files, out: []], existing: existing)
        let result = try await F.scanner(lister, identifier).scanSplit(source: src, output: out)
        return (result, identifier)
    }

    /// A Ready row starts checked and is a job when that name is checked.
    private func readyRow(_ result: ScanResult, _ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> ScanItem {
        let item = try XCTUnwrap(result.item(name), file: file, line: line)
        XCTAssertTrue(item.isReady, file: file, line: line)
        XCTAssertTrue(item.issues.isEmpty, "\(name) is an Issue", file: file, line: line)
        var state = ModeState(mode: .split)
        state.applyScan(result)
        XCTAssertEqual(state.row(name)?.isChecked, true, file: file, line: line)
        XCTAssertEqual(RunJob.jobs(from: result, checked: [name]).map(\.baseName), [name], file: file, line: line)
        return item
    }

    func testReadyFileHasPathsAndTracks() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, .subtitles, chapterEditions: 1)])
        let item = try XCTUnwrap(result.item("A"))
        XCTAssertTrue(item.isReady)
        XCTAssertNil(item.reasonText)
        XCTAssertNil(item.helpText)
        XCTAssertEqual(item.sourcePath, "/media/Rips/A.mkv")
        XCTAssertEqual(item.outputPath, "/media/Audio/A.mka")
        XCTAssertEqual(item.sourceInfo?.tracks.count, 3)
        XCTAssertEqual(item.notes, [])
        XCTAssertEqual(result.mode, .split)
        XCTAssertEqual(result.scannedAt, F.scanTime)
        XCTAssertEqual(result.readyCount, 1)
    }

    func testChaptersAreOptionalAndSeveralTracksAreFine() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, .audio, .subtitles, .subtitles, chapterEditions: 1)])
        let item = try readyRow(result, "A")
        XCTAssertEqual(item.notes, [])
        XCTAssertNil(item.reasonText)
    }

    func testExistingOutputIsFlaggedAndStillIdentified() async throws {
        let (result, identifier) = try await scan(
            [F.file("A.mkv")],
            probes: ["/media/Rips/A.mkv": F.media(.video, .subtitles)],
            existing: ["/media/Audio/A.mka"]
        )
        let item = try XCTUnwrap(result.item("A"))
        XCTAssertEqual(item.issues, [.noAudio(fileName: "A.mkv"), .outputExists(fileName: "A.mka")])
        XCTAssertEqual(item.reasonText, "No audio tracks found (+1 more)")
        XCTAssertEqual(item.notes, [])
        XCTAssertEqual(item.helpText, "No audio tracks found in A.mkv. Split needs at least one audio track.\nA.mka is already in the Output folder. MKVForge never overwrites files. Move or rename it, then scan again.")
        let calls = await identifier.calls
        XCTAssertEqual(calls, ["/media/Rips/A.mkv"])
    }

    func testOutputExistsReason() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, .subtitles)], existing: ["/media/Audio/A.mka"])
        XCTAssertEqual(result.item("A")?.reasonText, "A.mka already exists in Output folder")
    }

    func testEmptyFileIsNotIdentified() async throws {
        let (result, identifier) = try await scan([F.file("A.mkv", size: 0)])
        XCTAssertEqual(result.item("A")?.issues, [.emptyFile(.source, fileName: "A.mkv")])
        XCTAssertEqual(result.item("A")?.reasonText, "Empty file (0 bytes)")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testNoPermissionIsUnreadable() async throws {
        let (result, identifier) = try await scan([F.file("A.mkv", readable: false)])
        XCTAssertEqual(result.item("A")?.issues, [.unreadable(.source, fileName: "A.mkv", detail: "no permission to read it")])
        XCTAssertEqual(result.item("A")?.reasonText, "mkvmerge can't read this file")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testStillChangingBoundary() async throws {
        let (result, identifier) = try await scan([
            F.file("Fresh.mkv", modified: F.scanTime.addingTimeInterval(-59)),
            F.file("Settled.mkv", modified: F.scanTime.addingTimeInterval(-61)),
            F.file("Future.mkv", modified: F.scanTime.addingTimeInterval(30)),
        ], probes: ["/media/Rips/Settled.mkv": F.media(.audio, .subtitles)])
        XCTAssertEqual(result.item("Fresh")?.issues, [.stillChanging(.source, fileName: "Fresh.mkv")])
        XCTAssertEqual(result.item("Fresh")?.reasonText, "Still changing (modified in the last minute)")
        XCTAssertEqual(result.item("Future")?.issues, [.stillChanging(.source, fileName: "Future.mkv")])
        XCTAssertEqual(result.item("Settled")?.isReady, true)
        let calls = await identifier.calls
        XCTAssertEqual(calls, ["/media/Rips/Settled.mkv"])
    }

    func testUnreadableNotMatroskaAndNoTracks() async throws {
        let (result, _) = try await scan(
            [F.file("Bad.mkv"), F.file("Srt.mkv"), F.file("Cut.mkv")],
            probes: [
                "/media/Rips/Bad.mkv": .unreadable(detail: nil),
                "/media/Rips/Srt.mkv": F.media(.subtitles, type: "SRT subtitles"),
                "/media/Rips/Cut.mkv": F.media(),
            ]
        )
        XCTAssertEqual(result.item("Bad")?.reasonText, "mkvmerge can't read this file")
        XCTAssertEqual(result.item("Bad")?.helpText, "mkvmerge can't read Bad.mkv. It may be damaged or not a Matroska file.")
        XCTAssertEqual(result.item("Srt")?.issues, [.notMatroska(.source, fileName: "Srt.mkv", containerType: "SRT subtitles")])
        XCTAssertEqual(result.item("Srt")?.reasonText, "Not a Matroska file (SRT subtitles)")
        XCTAssertEqual(result.item("Cut")?.issues, [.noTracks(.source, fileName: "Cut.mkv")])
        XCTAssertEqual(result.item("Cut")?.reasonText, "No tracks found (damaged file?)")
    }

    func testMissingAudioOrSubtitles() async throws {
        let (result, _) = try await scan(
            [F.file("NoAudio.mkv"), F.file("VideoOnly.mkv")],
            probes: [
                "/media/Rips/NoAudio.mkv": F.media(.video, .subtitles),
                "/media/Rips/VideoOnly.mkv": F.media(.video),
            ]
        )
        let noAudio = try XCTUnwrap(result.item("NoAudio"))
        XCTAssertEqual(noAudio.issues, [.noAudio(fileName: "NoAudio.mkv")])
        XCTAssertEqual(noAudio.notes, [])
        XCTAssertEqual(noAudio.reasonText, "No audio tracks found")
        XCTAssertEqual(noAudio.helpText, "No audio tracks found in NoAudio.mkv. Split needs at least one audio track.")
        XCTAssertFalse(noAudio.helpText?.contains("subtitle track") ?? true)
        XCTAssertFalse(noAudio.isReady)

        let videoOnly = try XCTUnwrap(result.item("VideoOnly"))
        XCTAssertEqual(videoOnly.issues, [.noAudioOrSubtitles(fileName: "VideoOnly.mkv")])
        XCTAssertEqual(videoOnly.notes, [])
        XCTAssertEqual(videoOnly.reasonText, "No audio or subtitle tracks found")
        XCTAssertEqual(videoOnly.helpText, "No audio or subtitle tracks found in VideoOnly.mkv, so there's nothing to split.")
        XCTAssertFalse(videoOnly.isReady)

        var state = ModeState(mode: .split)
        state.applyScan(result)
        XCTAssertEqual(state.row("NoAudio")?.isChecked, false)
        XCTAssertEqual(state.row("VideoOnly")?.isChecked, false)
        XCTAssertEqual(RunJob.jobs(from: result, checked: ["NoAudio", "VideoOnly"]), [])
        XCTAssertEqual(result.flaggedCount, 2)
    }

    func testAudioSubtitlesAndChaptersAreReadyWithNoNotes() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, .subtitles, chapterEditions: 1)])
        let item = try readyRow(result, "A")
        XCTAssertEqual(item.notes, [])
        XCTAssertNil(item.reasonText)
        XCTAssertNil(item.helpText)
    }

    func testMissingChaptersIsReadyWithAWarning() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, .subtitles)])
        let item = try readyRow(result, "A")
        XCTAssertEqual(item.notes, [.noChapters(fileName: "A.mkv")])
        XCTAssertEqual(item.reasonText, "No chapters found")
        XCTAssertEqual(item.helpText, "No chapters found in A.mkv. The .mka will include its audio and subtitle tracks (if any).")
    }

    func testMissingSubtitlesIsReadyWithAWarning() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio, chapterEditions: 1)])
        let item = try readyRow(result, "A")
        XCTAssertEqual(item.notes, [.noSubtitles(fileName: "A.mkv")])
        XCTAssertEqual(item.reasonText, "No subtitle tracks found")
        XCTAssertEqual(item.helpText, "No subtitle tracks found in A.mkv. The .mka will include its audio tracks and chapters (if any).")
    }

    func testAudioOnlyIsReadyWithBothWarnings() async throws {
        let (result, _) = try await scan([F.file("A.mkv")], probes: ["/media/Rips/A.mkv": F.media(.video, .audio)])
        let item = try readyRow(result, "A")
        XCTAssertEqual(item.notes, [.noSubtitles(fileName: "A.mkv"), .noChapters(fileName: "A.mkv")])
        XCTAssertEqual(item.reasonText, "No subtitle tracks found (+1 more)")
        XCTAssertEqual(item.helpText, "No subtitle tracks found in A.mkv. The .mka will include its audio tracks and chapters (if any).\nNo chapters found in A.mkv. The .mka will include its audio and subtitle tracks (if any).")
    }

    func testDuplicateNameOnCaseSensitiveVolume() async throws {
        let (result, identifier) = try await scan([F.file("A.mkv"), F.file("A.MKV")])
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.item("A")?.issues, [.duplicateName(.source, fileNames: ["A.MKV", "A.mkv"])])
        XCTAssertEqual(result.item("A")?.reasonText, "Duplicate name in Source folder")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testIgnoredFilesAndSortOrder() async throws {
        let probes = ["/media/Rips/Show 2.mkv": F.media(.audio, .subtitles), "/media/Rips/Show 10.mkv": F.media(.audio, .subtitles), "/media/Rips/alpha.mkv": F.media(.audio, .subtitles)]
        let (result, _) = try await scan([
            F.file("Show 10.mkv"), F.file("._Show 10.mkv"), F.file(".DS_Store"), F.file("Show 2.mkv"),
            F.file("alpha.mkv"), F.file("Sub", regular: false), F.file("Show 2.en.srt"),
        ], probes: probes)
        XCTAssertEqual(result.items.map(\.baseName), ["alpha", "Show 2", "Show 10"])
        XCTAssertEqual(result.nameCount, 3)
        XCTAssertEqual(result.pairCount, 3)
    }

    func testReasonPriorityPutsEmptyBeforeStillChanging() async throws {
        let (result, _) = try await scan([F.file("A.mkv", size: 0, modified: F.scanTime)], existing: ["/media/Audio/A.mka"])
        XCTAssertEqual(result.item("A")?.issues.map(\.priority), [3, 4, 9])
        XCTAssertEqual(result.item("A")?.reasonText, "Empty file (0 bytes) (+2 more)")
    }

    func testUnreadableFolderThrows() async {
        let scanner = F.scanner(FakeLister(folders: [:]), FakeIdentifier())
        do {
            _ = try await scanner.scanSplit(source: src, output: out)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? ScanError, .folderNotReadable(.source, path: src))
            XCTAssertEqual((error as? ScanError)?.errorDescription, "The Source folder can't be read: /media/Rips")
        }
    }

    func testEmptyFolderGivesNoRows() async throws {
        let (result, _) = try await scan([])
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.flaggedCount, 0)
    }
}
