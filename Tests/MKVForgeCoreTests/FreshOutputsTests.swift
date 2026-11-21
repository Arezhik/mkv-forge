import XCTest
@testable import MKVForgeCore

/// L32: a Remux scan doesn't flag MKVForge's own fresh Split outputs as still changing,
/// and keeps the one-minute rule for everything else.
final class FreshOutputsTests: XCTestCase {
    private typealias F = ScanFixture
    private let video = "/v/Video"
    private let audio = "/v/Audio"
    private let out = "/v/Finished"
    private let justNow = F.scanTime.addingTimeInterval(-5)

    private func scan(video videoFiles: [FileEntry], audio audioFiles: [FileEntry], fresh: FreshOutputs = FreshOutputs()) async throws -> (ScanResult, FakeIdentifier) {
        let identifier = FakeIdentifier(["/v/Video/A.mkv": F.media(.video), "/v/Audio/A.mka": F.media(.audio, .subtitles)])
        let lister = FakeLister(folders: [video: videoFiles, audio: audioFiles, out: []])
        let result = try await F.scanner(lister, identifier).scanRemux(video: video, audio: audio, output: out, fresh: fresh)
        return (result, identifier)
    }

    private func fresh(_ path: String, size: Int64 = 1000, modified: Date? = nil, recordedAt: Date? = nil) -> FreshOutputs {
        var fresh = FreshOutputs()
        fresh.record(path, FileStamp(size: size, modified: modified ?? justNow), at: recordedAt ?? justNow)
        return fresh
    }

    func testANewMKAIsStillChangingWithoutARecord() async throws {
        let (result, identifier) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka", modified: justNow)])
        XCTAssertEqual(result.item("A")?.issues, [.stillChanging(.audio, fileName: "A.mka")])
        XCTAssertEqual(result.item("A")?.reasonText, ".mka still changing (modified in the last minute)")
        let calls = await identifier.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testOwnSplitOutputIsReadyAndProbed() async throws {
        let (result, identifier) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka", modified: justNow)], fresh: fresh("/v/Audio/A.mka"))
        XCTAssertEqual(result.item("A")?.isReady, true, result.item("A")?.helpText ?? "")
        let calls = Set(await identifier.calls)
        XCTAssertEqual(calls, ["/v/Video/A.mkv", "/v/Audio/A.mka"])
    }

    func testTheSamePathWrittenAnotherWayStillMatches() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka", modified: justNow)], fresh: fresh("/v/Audio//sub/../A.mka"))
        XCTAssertEqual(result.item("A")?.isReady, true)
    }

    func testAnythingElseKeepsTheOneMinuteRule() async throws {
        let stillChanging: [ScanIssue] = [.stillChanging(.audio, fileName: "A.mka")]
        let cases: [(String, FreshOutputs)] = [
            ("other size (replaced by hand)", fresh("/v/Audio/A.mka", size: 999)),
            ("other date (touched or copied over)", fresh("/v/Audio/A.mka", modified: justNow.addingTimeInterval(1))),
            ("other folder (copied in by hand)", fresh("/elsewhere/A.mka")),
            ("record older than a minute", fresh("/v/Audio/A.mka", recordedAt: F.scanTime.addingTimeInterval(-61))),
        ]
        for (label, fresh) in cases {
            let (result, _) = try await scan(video: [F.file("A.mkv")], audio: [F.file("A.mka", modified: justNow)], fresh: fresh)
            XCTAssertEqual(result.item("A")?.issues, stillChanging, label)
        }
    }

    func testOnlyTheMKAIsTrustedNotTheVideoFile() async throws {
        let (result, _) = try await scan(video: [F.file("A.mkv", modified: justNow)], audio: [F.file("A.mka")], fresh: fresh("/v/Video/A.mkv"))
        XCTAssertEqual(result.item("A")?.issues, [.stillChanging(.video, fileName: "A.mkv")])
    }

    func testPruneDropsRecordsOlderThanTheRule() {
        var fresh = FreshOutputs()
        fresh.record("/a/Old.mka", FileStamp(size: 1, modified: F.old), at: F.scanTime.addingTimeInterval(-60))
        fresh.record("/a/New.mka", FileStamp(size: 1, modified: F.old), at: F.scanTime.addingTimeInterval(-59))
        fresh.prune(now: F.scanTime)
        XCTAssertEqual(fresh.count, 1)
        XCTAssertTrue(fresh.isOwnOutput("/a/New.mka", F.file("New.mka", size: 1, modified: F.old), at: F.scanTime))
        XCTAssertFalse(fresh.isOwnOutput("/a/Old.mka", F.file("Old.mka", size: 1, modified: F.old), at: F.scanTime))
    }

    /// On a real disk, the stamp recorded after a batch equals what the folder scan reads.
    func testRecordedStampMatchesTheFolderListingOnDisk() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-fresh-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        for folder in ["Video", "Audio", "Finished"] {
            try FileManager.default.createDirectory(atPath: "\(root)/\(folder)", withIntermediateDirectories: true)
        }
        try Data("video".utf8).write(to: URL(fileURLWithPath: "\(root)/Video/A.mkv"))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: "\(root)/Video/A.mkv")
        try Data("audio".utf8).write(to: URL(fileURLWithPath: "\(root)/Audio/A.mka"))
        let identifier = FakeIdentifier(["\(root)/Video/A.mkv": F.media(.video), "\(root)/Audio/A.mka": F.media(.audio)])
        let scanner = FolderScanner(identifier: identifier)

        let before = try await scanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Finished")
        XCTAssertEqual(before.item("A")?.issues, [.stillChanging(.audio, fileName: "A.mka")])

        var fresh = FreshOutputs()
        fresh.record(paths: ["\(root)/Audio/A.mka", "\(root)/Audio/Missing.mka"], at: Date())
        XCTAssertEqual(fresh.count, 1, "a missing output isn't recorded")
        let after = try await scanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Finished", fresh: fresh)
        XCTAssertEqual(after.item("A")?.isReady, true, after.item("A")?.helpText ?? "")

        // Rewritten by hand afterwards: the size changes, so the rule is back.
        try Data("audio, copied again".utf8).write(to: URL(fileURLWithPath: "\(root)/Audio/A.mka"))
        let rewritten = try await scanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Finished", fresh: fresh)
        XCTAssertEqual(rewritten.item("A")?.issues, [.stillChanging(.audio, fileName: "A.mka")])
    }
}
