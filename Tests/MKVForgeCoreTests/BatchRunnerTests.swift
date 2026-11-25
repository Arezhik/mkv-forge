import XCTest
@testable import MKVForgeCore

/// The runner with a scripted mkvmerge and a real temporary folder tree.
final class BatchRunnerTests: XCTestCase {
    private var folders: RunFolders!

    override func setUpWithError() throws {
        folders = try RunFolders()
    }

    override func tearDown() {
        folders.remove()
    }

    private func run(
        _ jobs: [RunJob],
        _ tool: FakeMKVMerge,
        identifier: FakeIdentifier? = nil,
        flagged: Int = 0,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) async -> (BatchSummary, EventLog) {
        let runner = BatchRunner(tool: tool, identifier: identifier ?? RunFixture.identifier(for: jobs), clock: clock)
        tool.runner = runner
        let log = EventLog()
        let summary = await runner.run(jobs, flaggedCount: flagged) { log.append($0) }
        return (summary, log)
    }

    func testExit0RenamesTheTempFileToTheOutput() async throws {
        let job = try RunFixture.split("Show [é]", in: folders)
        let tool = FakeMKVMerge(["Show [é]": FakeRun(status: 0)])
        let (summary, log) = await run([job], tool)
        XCTAssertEqual(log.statuses["Show [é]"], .done(outputPath: job.outputPath))
        XCTAssertEqual(folders.names(in: "Output"), ["Show [é].mka"])
        XCTAssertEqual(folders.contents("Output/Show [é].mka"), "new output")
        XCTAssertEqual(log.events.first, .started(id: "Show [é]", index: 1, total: 1))
        XCTAssertEqual(summary.text, "Finished · 1 done")
        XCTAssertEqual(summary.outputPaths, [job.outputPath])
    }

    func testExit1KeepsTheOutputWithAWarning() async throws {
        let job = try RunFixture.split("A", in: folders)
        let warning = "Warning: '/x/A.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored."
        let tool = FakeMKVMerge(["A": FakeRun(status: 1, output: "mkvmerge v82.0\n\(warning)\n")])
        let (summary, log) = await run([job], tool)
        XCTAssertEqual(log.statuses["A"], .doneWithWarning(outputPath: job.outputPath, warnings: [warning]))
        XCTAssertEqual(log.statuses["A"]?.reasonText, warning)
        XCTAssertEqual(folders.names(in: "Output"), ["A.mka"])
        XCTAssertEqual(summary.text, "Finished · 1 done (1 with warning)")
    }

    func testExit2FailsDeletesTheTempAndTheBatchKeepsGoing() async throws {
        let a = try RunFixture.split("A", in: folders)
        let b = try RunFixture.split("B", in: folders)
        let tool = FakeMKVMerge([
            "A": FakeRun(status: 2, output: "mkvmerge v82.0\nError: The type of file '/x/A.mkv' could not be recognized.\n"),
            "B": FakeRun(status: 0),
        ])
        let (summary, log) = await run([a, b], tool, flagged: 2)
        XCTAssertEqual(log.statuses["A"], .failed(
            reason: "mkvmerge exit 2: The type of file '/x/A.mkv' could not be recognized.",
            detail: "mkvmerge v82.0\nError: The type of file '/x/A.mkv' could not be recognized."))
        XCTAssertEqual(log.statuses["B"], .done(outputPath: b.outputPath))
        XCTAssertEqual(folders.names(in: "Output"), ["B.mka"])
        XCTAssertEqual(summary.text, "Finished · 1 done · 2 flagged · 1 failed")
        XCTAssertEqual(summary.completed, 2)
    }

    func testLaunchFailureFailsAndTheBatchKeepsGoing() async throws {
        let a = try RunFixture.split("A", in: folders)
        let b = try RunFixture.split("B", in: folders)
        let tool = FakeMKVMerge(["A": FakeRun(throwing: .couldNotStart("mkvmerge")), "B": FakeRun()])
        let (_, log) = await run([a, b], tool)
        XCTAssertEqual(log.statuses["A"], .failed(reason: "mkvmerge could not be started", detail: "mkvmerge could not be started."))
        XCTAssertEqual(log.statuses["B"], .done(outputPath: b.outputPath))
    }

    func testAnUnexpectedExitCodeFails() async throws {
        let job = try RunFixture.split("A", in: folders)
        let (_, log) = await run([job], FakeMKVMerge(["A": FakeRun(status: 9)]))
        XCTAssertEqual(log.statuses["A"]?.reasonText, "mkvmerge stopped unexpectedly (code 9)")
        XCTAssertEqual(folders.names(in: "Output"), [], "the temp file is deleted")
    }

    func testExit0WithoutATempFileFails() async throws {
        let job = try RunFixture.split("A", in: folders)
        let (_, log) = await run([job], FakeMKVMerge(["A": FakeRun(status: 0, writesTemp: false)]))
        XCTAssertEqual(log.statuses["A"]?.reasonText, "mkvmerge finished but wrote no file")
        XCTAssertEqual(folders.names(in: "Output"), [])
    }

    func testAnOutputThatAppearsMidRunIsNeverOverwritten() async throws {
        let job = try RunFixture.split("A", in: folders)
        let (_, log) = await run([job], FakeMKVMerge(["A": FakeRun(status: 0, createsOutput: true)]))
        XCTAssertEqual(log.statuses["A"]?.reasonText, "A.mka already exists in Output folder")
        XCTAssertEqual(folders.contents("Output/A.mka"), "someone else's file")
        XCTAssertEqual(folders.names(in: "Output"), ["A.mka"], "the finished temp file is deleted")
    }

    func testAMissingInputFailsWithoutRunningMKVMerge() async throws {
        let job = try RunFixture.remux("A", in: folders)
        try FileManager.default.removeItem(atPath: try XCTUnwrap(job.mkaPath))
        let tool = FakeMKVMerge()
        let (_, log) = await run([job], tool)
        XCTAssertEqual(log.statuses["A"]?.reasonText, "A.mka is missing")
        XCTAssertTrue(tool.calls.isEmpty)
    }

    func testAFileThatChangedSinceTheScanFailsWithoutRunningMKVMerge() async throws {
        let job = try RunFixture.split("A", in: folders)
        let changed = MediaProbe.readable(MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .video)]))
        let tool = FakeMKVMerge()
        let (_, log) = await run([job], tool, identifier: RunFixture.identifier(for: [job], overrides: [job.sourcePath: changed]))
        XCTAssertEqual(log.statuses["A"]?.reasonText, "Changed since the scan. Scan again.")
        XCTAssertTrue(tool.calls.isEmpty)
    }

    func testAMissingOutputFolderFailsWithoutRunningMKVMerge() async throws {
        let job = try RunFixture.split("A", in: folders)
        try FileManager.default.removeItem(atPath: folders.path("Output"))
        let tool = FakeMKVMerge()
        let (_, log) = await run([job], tool)
        XCTAssertEqual(log.statuses["A"]?.reasonText, "Output folder is missing")
        XCTAssertTrue(tool.calls.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folders.path("Output")), "never recreated")
    }

    func testAStaleTempFileIsReplaced() async throws {
        let job = try RunFixture.split("A", in: folders)
        try folders.touch("Output/.A.partial.mka", "left over from a crash")
        let (_, log) = await run([job], FakeMKVMerge(["A": FakeRun(status: 0)]))
        XCTAssertEqual(log.statuses["A"], .done(outputPath: job.outputPath))
        XCTAssertEqual(folders.names(in: "Output"), ["A.mka"])
        XCTAssertEqual(folders.contents("Output/A.mka"), "new output")
    }

    func testTheCommandWritesToTheTempPathWithTheScannedTracks() async throws {
        let job = try RunFixture.remux("A", in: folders)
        let tool = FakeMKVMerge()
        _ = await run([job], tool)
        let expected = try MKVMergeCommand.remux(video: job.sourcePath, mka: try XCTUnwrap(job.mkaPath), output: folders.path("Output/.A.partial.mkv"), videoTracks: RunFixture.videoInfo.tracks)
        XCTAssertEqual(tool.calls, [expected])
    }

    func testCancelFinishesTheCurrentFileThenStops() async throws {
        let jobs = try ["A", "B", "C", "D"].map { try RunFixture.split($0, in: folders) }
        let tool = FakeMKVMerge(["B": FakeRun(status: 0, requestsStop: true)])
        let (summary, log) = await run(jobs, tool)
        XCTAssertEqual(log.statuses["A"], .done(outputPath: jobs[0].outputPath))
        XCTAssertEqual(log.statuses["B"], .done(outputPath: jobs[1].outputPath), "the current file finishes")
        XCTAssertEqual(log.statuses["C"], .notRun)
        XCTAssertEqual(log.statuses["D"], .notRun)
        XCTAssertEqual(tool.calls.count, 2)
        XCTAssertTrue(summary.stopped)
        XCTAssertEqual(summary.text, "Stopped · 2 of 4 complete")
        XCTAssertEqual(log.statuses["C"]?.statusText(mode: .split), "Ready")
    }

    func testAHardStopDeletesTheTempAndMarksTheRowCancelled() async throws {
        let jobs = try ["A", "B"].map { try RunFixture.split($0, in: folders) }
        let tool = FakeMKVMerge(["A": FakeRun(status: 0, cancelsTask: true)])
        let (summary, log) = await run(jobs, tool)
        XCTAssertEqual(log.statuses["A"], .canceled)
        XCTAssertEqual(log.statuses["B"], .notRun)
        XCTAssertEqual(folders.names(in: "Output"), [], "no temp file and no output")
        XCTAssertEqual(summary.text, "Stopped · 0 of 2 complete")
    }

    func testJobsKeepOnlyCheckedReadyRowsInOrder() {
        let info = RunFixture.splitInfo
        let scan = ScanResult(mode: .split, scannedAt: Date(), items: [
            ScanItem(baseName: "c", sourcePath: "/s/c.mkv", outputPath: "/o/c.mka", sourceInfo: info),
            ScanItem(baseName: "a", sourcePath: "/s/a.mkv", outputPath: "/o/a.mka", sourceInfo: info),
            ScanItem(baseName: "b", sourcePath: "/s/b.mkv", outputPath: "/o/b.mka", sourceInfo: info, issues: [.noAudio(fileName: "b.mkv")]),
            ScanItem(baseName: "d", sourcePath: "/s/d.mkv", outputPath: "/o/d.mka", sourceInfo: info),
        ])
        let jobs = RunJob.jobs(from: scan, checked: ["a", "b", "c"])
        XCTAssertEqual(jobs.map(\.baseName), ["a", "c"])
        XCTAssertEqual(jobs.first?.tempPath, "/o/.a.partial.mka")
        XCTAssertEqual(jobs.first?.sourceInfo, info)
    }

    func testGUIWarningAndErrorKeepTheSameReason() async throws {
        let warning = "Warning: '/x/A.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored."
        let guiWarning = "#GUI#warning '/x/A.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored."
        let warned = try RunFixture.split("A", in: folders)
        let (_, warningLog) = await run([warned], FakeMKVMerge(["A": FakeRun(status: 1, output: "mkvmerge v82.0\r\(guiWarning)\n")]))
        XCTAssertEqual(warningLog.statuses["A"]?.reasonText, warning)

        let failed = try RunFixture.split("B", in: folders)
        let (_, errorLog) = await run([failed], FakeMKVMerge(["B": FakeRun(status: 2, output: "#GUI#error The type of file '/x/B.mkv' could not be recognized.\r")]))
        XCTAssertEqual(errorLog.statuses["B"]?.reasonText, "mkvmerge exit 2: The type of file '/x/B.mkv' could not be recognized.")
    }

    func testProgressBlendsTheCurrentFileWithFinishedDurations() async throws {
        let jobs = try ["A", "B", "C"].map { try RunFixture.split($0, in: folders) }
        let origin = Date(timeIntervalSince1970: 1_700_000_000)
        // A: start, 50% at +10s, end at +16s (duration 16). Two files still queued.
        // B: start, 25% at +10s from its start, end +20s later. One file still queued.
        // C: start and end, no percent.
        let times = [
            origin,
            origin.addingTimeInterval(10),
            origin.addingTimeInterval(16),
            origin.addingTimeInterval(16),
            origin.addingTimeInterval(26),
            origin.addingTimeInterval(36),
            origin.addingTimeInterval(36),
            origin.addingTimeInterval(36),
        ]
        let clock = ScriptedClock(times)
        let tool = FakeMKVMerge([
            "A": FakeRun(status: 0, progress: [50]),
            "B": FakeRun(status: 0, progress: [25]),
            "C": FakeRun(status: 0),
        ])
        let (_, log) = await run(jobs, tool, clock: { clock.call() })
        let captions = log.events.compactMap { event -> String? in
            if case let .progress(caption) = event { return caption }
            return nil
        }
        XCTAssertEqual(captions, ["About 50 seconds left", "About 46 seconds left"])
        XCTAssertEqual(clock.calls, times.count)
        XCTAssertEqual(log.statuses["A"], .done(outputPath: jobs[0].outputPath))
        XCTAssertFalse(tool.calls.contains { $0.contains("--gui-mode") }, "the fake sees the command, not the process flag")
    }

    func testProgressHidesAtZeroPercentAndAtOneHundred() async throws {
        let job = try RunFixture.split("A", in: folders)
        let origin = Date(timeIntervalSince1970: 1_800_000_000)
        let times = [
            origin,
            origin.addingTimeInterval(10),
            origin.addingTimeInterval(10),
            origin.addingTimeInterval(10.05),
            origin.addingTimeInterval(20),
        ]
        let clock = ScriptedClock(times)
        let tool = FakeMKVMerge(["A": FakeRun(status: 0, progress: [0, 50, 100])])
        let (_, log) = await run([job], tool, clock: { clock.call() })
        let captions = log.events.compactMap { event -> String? in
            if case let .progress(caption) = event { return caption }
            return nil
        }
        XCTAssertEqual(captions, ["About 10 seconds left", ""])
        XCTAssertEqual(clock.calls, times.count)
    }
}

private final class ScriptedClock: @unchecked Sendable {
    private let lock = NSLock()
    private let dates: [Date]
    private var index = 0

    init(_ dates: [Date]) {
        self.dates = dates
    }

    func call() -> Date {
        lock.lock()
        defer { lock.unlock() }
        precondition(index < dates.count, "scripted clock ran out of dates")
        let date = dates[index]
        index += 1
        return date
    }

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return index
    }
}
