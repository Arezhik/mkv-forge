import XCTest
@testable import MKVForgeCore

/// Runs real Split and Remux batches with the installed mkvmerge on small files generated
/// at test time (the same VP8 stub, silent PCM, subtitles and chapters as
/// MKVMergeIntegrationTests). Runs under LC_ALL=C with an `é` name, so it also proves
/// the UTF-8 locale (L27). Skips when mkvmerge isn't installed (the macOS CI jobs).
final class MKVMergeRunIntegrationTests: XCTestCase {
    private static let vp8IVFBase64 = "REtJRgAAIABWUDgwEAAQAAEAAAABAAAAAgAAAAAAAAAfAAAAAAAAAAAAAAAQAgCdASoQABAAAEcIhYWImYSIAgIADA1gAP7/q1CAFQAAAAEAAAAAAAAAsQEAARAQABgAMD/0DAAAAP7/q1CA"
    private static let name = "Show - S01E02 [é]"

    private var root = ""
    private var savedLocale: String?

    override func setUpWithError() throws {
        savedLocale = ProcessInfo.processInfo.environment["LC_ALL"]
        setenv("LC_ALL", "C", 1)
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-run-it-\(UUID().uuidString)").path
        for folder in ["inputs", "Rips", "Audio", "Video", "Finished"] {
            try FileManager.default.createDirectory(atPath: "\(root)/\(folder)", withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
        if let savedLocale { setenv("LC_ALL", savedLocale, 1) } else { unsetenv("LC_ALL") }
    }

    private func mkvmerge() throws -> String {
        guard let path = ExternalTool.locate(.primary)?["mkvmerge"] else {
            throw XCTSkip("mkvmerge isn't installed here; this test runs on Linux CI and in the agent environment")
        }
        return path
    }

    private func write(_ data: Data, _ path: String) throws {
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// One second of 8 kHz mono 16-bit silence.
    private func silentWAV() -> Data {
        func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8(v >> 24)] }
        func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xff), UInt8(v >> 8)] }
        let samples = 8000
        let dataSize = UInt32(samples * 2)
        var bytes: [UInt8] = Array("RIFF".utf8) + le32(36 + dataSize) + Array("WAVEfmt ".utf8)
        bytes += le32(16) + le16(1) + le16(1) + le32(8000) + le32(16000) + le16(2) + le16(16)
        bytes += Array("data".utf8) + le32(dataSize) + [UInt8](repeating: 0, count: samples * 2)
        return Data(bytes)
    }

    /// Writes `Rips/<name>.mkv` (video, audio, subtitles, chapters, a title) and the
    /// video-only `Video/<name>.mkv`.
    private func makeSources(_ tool: String) async throws -> (full: String, video: String) {
        let inputs = "\(root)/inputs"
        try write(try XCTUnwrap(Data(base64Encoded: Self.vp8IVFBase64)), "\(inputs)/video.ivf")
        try write(silentWAV(), "\(inputs)/audio.wav")
        try write(Data("1\n00:00:00,100 --> 00:00:00,500\nHello\n".utf8), "\(inputs)/subs.srt")
        try write(Data("CHAPTER01=00:00:00.000\nCHAPTER01NAME=Intro\n".utf8), "\(inputs)/chapters.txt")
        let full = "\(root)/Rips/\(Self.name).mkv"
        let video = "\(root)/Video/\(Self.name).mkv"
        for arguments in [
            ["-o", full, "--title", "Full", "--chapters", "\(inputs)/chapters.txt", "\(inputs)/video.ivf", "--language", "0:jpn", "\(inputs)/audio.wav", "\(inputs)/subs.srt"],
            ["-o", video, "--title", "Encode", "\(inputs)/video.ivf"],
        ] {
            let result = try await ToolCommand.run(executable: tool, arguments: arguments)
            XCTAssertEqual(result.status, 0, String(decoding: result.standardOutput, as: UTF8.self))
        }
        return (full, video)
    }

    private func trackTypes(_ tool: String, _ path: String) async throws -> [String] {
        let result = try await ToolCommand.run(executable: tool, arguments: ["-J", path])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: result.standardOutput) as? [String: Any])
        return (json["tracks"] as? [[String: Any]] ?? []).map { $0["type"] as? String ?? "" }
    }

    private func allNames(_ folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: "\(root)/\(folder)")) ?? []).sorted()
    }

    func testSplitThenRemuxBatchesWithRealMKVMerge() async throws {
        let tool = try mkvmerge()
        _ = try await makeSources(tool)
        let scanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool), now: { Date().addingTimeInterval(120) })
        let runner = BatchRunner(executable: tool)

        let split = try await scanner.scanSplit(source: "\(root)/Rips", output: "\(root)/Audio")
        let splitJobs = RunJob.jobs(from: split, checked: Set(split.items.map(\.baseName)))
        XCTAssertEqual(splitJobs.map(\.baseName), [Self.name])
        let splitSummary = await runner.run(splitJobs, flaggedCount: split.flaggedCount)
        XCTAssertEqual(splitSummary.text, "Finished · 1 done")
        XCTAssertEqual(allNames("Audio"), ["\(Self.name).mka"], "full name, no hidden temp left")
        let splitTracks = try await trackTypes(tool, "\(root)/Audio/\(Self.name).mka")
        XCTAssertEqual(splitTracks, ["audio", "subtitles"])

        // The .mka from Split pairs with the video-only file. Scan as if two minutes later.
        let remuxScanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool), now: { Date().addingTimeInterval(120) })
        let remux = try await remuxScanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Finished")
        let remuxJobs = RunJob.jobs(from: remux, checked: [Self.name])
        XCTAssertEqual(remuxJobs.count, 1, remux.items.first?.helpText ?? "")
        let log = EventLog()
        let remuxSummary = await runner.run(remuxJobs, flaggedCount: 0) { log.append($0) }
        XCTAssertEqual(log.statuses[Self.name], .done(outputPath: "\(root)/Finished/\(Self.name).mkv"))
        XCTAssertEqual(remuxSummary.savedText, "1 .mkv saved")
        XCTAssertEqual(allNames("Finished"), ["\(Self.name).mkv"])
        let remuxTracks = try await trackTypes(tool, "\(root)/Finished/\(Self.name).mkv")
        XCTAssertEqual(remuxTracks, ["video", "audio", "subtitles"])
    }

    /// Arezhik's case (L32): Split, then Remux the full sources against the new .mka files
    /// within a minute. The .mka are MKVForge's own outputs, so they aren't still changing,
    /// and the full .mkv gives only its video.
    func testRemuxRightAfterSplitWithTheFullSourcesAsVideo() async throws {
        let tool = try mkvmerge()
        let (full, _) = try await makeSources(tool)
        // The full source has been in place for an hour; only the .mka will be new.
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: full)
        let runner = BatchRunner(executable: tool)
        let scanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool))
        let split = try await scanner.scanSplit(source: "\(root)/Rips", output: "\(root)/Audio")
        let splitSummary = await runner.run(RunJob.jobs(from: split, checked: [Self.name]), flaggedCount: 0)
        XCTAssertEqual(splitSummary.text, "Finished · 1 done")
        var fresh = FreshOutputs()
        fresh.record(paths: splitSummary.outputPaths, at: Date())
        XCTAssertEqual(fresh.count, 1)

        // Real clock: the .mka is seconds old.
        let without = try await scanner.scanRemux(video: "\(root)/Rips", audio: "\(root)/Audio", output: "\(root)/Finished")
        XCTAssertEqual(without.item(Self.name)?.issues, [.stillChanging(.audio, fileName: "\(Self.name).mka")])
        let remux = try await scanner.scanRemux(video: "\(root)/Rips", audio: "\(root)/Audio", output: "\(root)/Finished", fresh: fresh)
        let pair = try XCTUnwrap(remux.item(Self.name))
        XCTAssertTrue(pair.isReady, pair.helpText ?? "")
        XCTAssertEqual(pair.reasonText, "Uses video only, ignores 1 audio, 1 subtitle")

        let log = EventLog()
        let summary = await runner.run(RunJob.jobs(from: remux, checked: [Self.name]), flaggedCount: 0) { log.append($0) }
        XCTAssertEqual(log.statuses[Self.name], .done(outputPath: "\(root)/Finished/\(Self.name).mkv"))
        XCTAssertEqual(summary.savedText, "1 .mkv saved")
        let tracks = try await trackTypes(tool, "\(root)/Finished/\(Self.name).mkv")
        XCTAssertEqual(tracks, ["video", "audio", "subtitles"])
    }

    func testExit1FromAStaleTrackIDIsDoneWithAWarning() async throws {
        let tool = try mkvmerge()
        let (full, _) = try await makeSources(tool)
        let info = MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .video), TrackInfo(id: 1, kind: .audio), TrackInfo(id: 2, kind: .subtitles)])
        let job = RunJob(mode: .split, baseName: Self.name, sourcePath: full, outputPath: "\(root)/Audio/\(Self.name).mka", sourceInfo: info)
        let status = try await BatchRunner(executable: tool).execute(job, sourceTracks: info.tracks + [TrackInfo(id: 9, kind: .audio)])
        guard case let .doneWithWarning(path, warnings) = status else { return XCTFail("expected a warning, got \(status)") }
        XCTAssertEqual(path, job.outputPath)
        XCTAssertTrue(warnings.first?.hasPrefix("Warning:") ?? false, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("ID 9") ?? false, "\(warnings)")
        XCTAssertEqual(allNames("Audio"), ["\(Self.name).mka"])
    }

    func testExit2FromAGarbageInputFailsAndLeavesNoFile() async throws {
        let tool = try mkvmerge()
        let garbage = "\(root)/Rips/Garbage.mkv"
        try write(Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }), garbage)
        let job = RunJob(mode: .split, baseName: "Garbage", sourcePath: garbage, outputPath: "\(root)/Audio/Garbage.mka", sourceInfo: MediaInfo(containerType: "Matroska", tracks: []))
        let status = try await BatchRunner(executable: tool).execute(job, sourceTracks: [])
        guard case let .failed(reason, detail) = status else { return XCTFail("expected a failure, got \(status)") }
        XCTAssertTrue(reason.hasPrefix("mkvmerge exit 2: The type of file"), reason)
        XCTAssertTrue(detail.contains("Error:"), detail)
        XCTAssertEqual(allNames("Audio"), [], "no output and no temp file")
    }
}
