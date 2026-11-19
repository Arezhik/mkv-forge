import XCTest
@testable import MKVForgeCore

/// Runs the real mkvmerge on a small file generated at test time: a 108-byte VP8 stub
/// (one black 16×16 frame), one second of silent PCM audio, two subtitle lines, two
/// chapters, a global tag, a title, and an attachment. No media is committed.
/// Skips when mkvmerge isn't installed (the macOS CI jobs). Linux CI and the cloud agent
/// environment install mkvtoolnix, so it runs there.
final class MKVMergeIntegrationTests: XCTestCase {
    private static let vp8IVFBase64 = "REtJRgAAIABWUDgwEAAQAAEAAAABAAAAAgAAAAAAAAAfAAAAAAAAAAAAAAAQAgCdASoQABAAAEcIhYWImYSIAgIADA1gAP7/q1CAFQAAAAEAAAAAAAAAsQEAARAQABgAMD/0DAAAAP7/q1CA"

    private var root = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-it-\(UUID().uuidString)").path
        for folder in ["inputs", "Rips", "Audio", "Video", "Finished"] {
            try FileManager.default.createDirectory(atPath: "\(root)/\(folder)", withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: root)
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

    private func run(_ tool: String, _ arguments: [String], file: StaticString = #filePath, line: UInt = #line) async throws -> ToolCommandResult {
        let result = try await ToolCommand.run(executable: tool, arguments: arguments)
        XCTAssertEqual(result.status, 0, "mkvmerge \(arguments): \(String(decoding: result.standardOutput, as: UTF8.self))", file: file, line: line)
        return result
    }

    private func identifyJSON(_ tool: String, _ path: String) async throws -> [String: Any] {
        let result = try await run(tool, ["-J", path])
        return try XCTUnwrap(JSONSerialization.jsonObject(with: result.standardOutput) as? [String: Any])
    }

    /// Checks that nothing but tracks and chapters survived.
    private func assertStripped(_ json: [String: Any], kinds: [String], file: StaticString = #filePath, line: UInt = #line) {
        let container = json["container"] as? [String: Any] ?? [:]
        let properties = container["properties"] as? [String: Any] ?? [:]
        XCTAssertNil(properties["title"], "title", file: file, line: line)
        XCTAssertNil(properties["date_utc"], "date (--no-date)", file: file, line: line)
        XCTAssertEqual((json["attachments"] as? [Any])?.count, 0, "attachments", file: file, line: line)
        XCTAssertEqual((json["global_tags"] as? [Any])?.count, 0, "global tags", file: file, line: line)
        XCTAssertEqual((json["track_tags"] as? [Any])?.count, 0, "track tags", file: file, line: line)
        let chapters = json["chapters"] as? [[String: Any]] ?? []
        XCTAssertEqual(chapters.first?["num_entries"] as? Int, 2, "chapters kept", file: file, line: line)
        let tracks = json["tracks"] as? [[String: Any]] ?? []
        XCTAssertEqual(tracks.map { $0["type"] as? String ?? "" }, kinds, "track order", file: file, line: line)
        for track in tracks {
            let p = track["properties"] as? [String: Any] ?? [:]
            let label = "track \(track["id"] ?? "?")"
            XCTAssertEqual(p["language"] as? String, "und", label, file: file, line: line)
            XCTAssertNil(p["track_name"], label, file: file, line: line)
            XCTAssertEqual(p["default_track"] as? Bool, false, label, file: file, line: line)
            XCTAssertEqual(p["forced_track"] as? Bool, false, label, file: file, line: line)
            XCTAssertNotEqual(p["flag_commentary"] as? Bool, true, label, file: file, line: line)
            XCTAssertTrue(p.keys.filter { $0.hasPrefix("tag_") }.isEmpty, "\(label) statistics tags", file: file, line: line)
        }
    }

    func testScanSplitAndRemuxWithRealMKVMerge() async throws {
        let tool = try mkvmerge()
        let inputs = "\(root)/inputs"
        try write(try XCTUnwrap(Data(base64Encoded: Self.vp8IVFBase64)), "\(inputs)/video.ivf")
        try write(silentWAV(), "\(inputs)/audio.wav")
        try write(Data("1\n00:00:00,100 --> 00:00:00,500\nHello\n\n2\n00:00:00,600 --> 00:00:00,900\nWorld\n".utf8), "\(inputs)/subs.srt")
        try write(Data("CHAPTER01=00:00:00.000\nCHAPTER01NAME=Intro\nCHAPTER02=00:00:00.500\nCHAPTER02NAME=Part 2\n".utf8), "\(inputs)/chapters.txt")
        try write(Data("<?xml version=\"1.0\"?><Tags><Tag><Targets/><Simple><Name>COMMENT</Name><String>global</String></Simple></Tag></Tags>\n".utf8), "\(inputs)/tags.xml")
        try write(Data("font".utf8), "\(inputs)/font.ttf")

        // A full source, the kind Split starts from, with every kind of metadata to strip.
        let name = "Show - S01E01 [é]"
        let source = "\(root)/Rips/\(name).mkv"
        _ = try await run(tool, [
            "-o", source, "--title", "Full Title", "--global-tags", "\(inputs)/tags.xml",
            "--attachment-mime-type", "font/ttf", "--attach-file", "\(inputs)/font.ttf", "--chapters", "\(inputs)/chapters.txt",
            "--language", "0:fre", "--track-name", "0:Video", "\(inputs)/video.ivf",
            "--language", "0:jpn", "--track-name", "0:Main", "--default-track-flag", "0:1", "--commentary-flag", "0:1", "\(inputs)/audio.wav",
            "--language", "0:eng", "--track-name", "0:Signs", "--forced-display-flag", "0:1", "\(inputs)/subs.srt",
        ])
        try write(Data(), "\(root)/Rips/Empty.mkv")
        try write(Data((0..<4096).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }), "\(root)/Rips/Garbage.mkv")
        try write(Data("x".utf8), "\(root)/Rips/._\(name).mkv")

        // Files written just now would be "still changing"; scan as if two minutes later.
        let scanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool), now: { Date().addingTimeInterval(120) })

        // Split scan and run.
        let split = try await scanner.scanSplit(source: "\(root)/Rips", output: "\(root)/Audio")
        XCTAssertEqual(split.items.map(\.baseName), ["Empty", "Garbage", name])
        XCTAssertEqual(split.item("Empty")?.issues, [.emptyFile(.source, fileName: "Empty.mkv")])
        XCTAssertEqual(split.item("Garbage")?.issues, [.unreadable(.source, fileName: "Garbage.mkv", detail: nil)])
        let ready = try XCTUnwrap(split.item(name))
        XCTAssertTrue(ready.isReady, ready.helpText ?? "")
        XCTAssertEqual(ready.sourceInfo?.tracks.map(\.kind), [.video, .audio, .subtitles])
        let splitArguments = try MKVMergeCommand.split(source: source, output: ready.outputPath, tracks: ready.sourceInfo?.tracks ?? [])
        _ = try await run(tool, splitArguments)
        assertStripped(try await identifyJSON(tool, ready.outputPath), kinds: ["audio", "subtitles"])

        // A rescan now flags the existing output.
        let rescan = try await scanner.scanSplit(source: "\(root)/Rips", output: "\(root)/Audio")
        XCTAssertEqual(rescan.item(name)?.issues, [.outputExists(fileName: name + ".mka")])

        // The encoded video-only file Remux starts from, with its own name and language.
        let video = "\(root)/Video/\(name).mkv"
        _ = try await run(tool, ["-o", video, "--title", "Encode", "--language", "0:fre", "--track-name", "0:Encoded", "--default-track-flag", "0:1", "\(inputs)/video.ivf"])
        let remux = try await scanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Finished")
        let pair = try XCTUnwrap(remux.item(name))
        XCTAssertTrue(pair.isReady, pair.helpText ?? "")
        let remuxArguments = try MKVMergeCommand.remux(video: video, mka: try XCTUnwrap(pair.mkaPath), output: pair.outputPath, videoTracks: pair.sourceInfo?.tracks ?? [])
        _ = try await run(tool, remuxArguments)
        assertStripped(try await identifyJSON(tool, pair.outputPath), kinds: ["video", "audio", "subtitles"])

        // The full source in the Video folder has extra tracks.
        try FileManager.default.removeItem(atPath: video)
        try FileManager.default.copyItem(atPath: source, toPath: video)
        let extra = try await scanner.scanRemux(video: "\(root)/Video", audio: "\(root)/Audio", output: "\(root)/Video")
        XCTAssertEqual(extra.item(name)?.issues.first, .outputIsVideoFolder)
        XCTAssertTrue(extra.item(name)?.issues.contains(.extraTracks(fileName: name + ".mkv", audio: 1, subtitles: 1)) ?? false)
    }
}
