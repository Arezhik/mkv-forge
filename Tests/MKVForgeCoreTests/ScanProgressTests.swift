import XCTest
@testable import MKVForgeCore

/// Scan progress for the `Scanning… 3 of 9` caption (layout contract v2.1 §2.2, Phase 5 Q4).
final class ScanProgressTests: XCTestCase {
    private typealias F = ScanFixture

    /// Collects progress updates from the scan's task.
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [ScanProgress] = []
        func append(_ p: ScanProgress) { lock.lock(); items.append(p); lock.unlock() }
        var all: [ScanProgress] { lock.lock(); defer { lock.unlock() }; return items }
        var readings: [(Int, Int)] {
            all.compactMap { if case let .reading(c, t) = $0 { return (c, t) } else { return nil } }
        }
    }

    private func splitScanner(_ names: [String], flagged: Set<String> = [], delay: UInt64 = 0, interval: TimeInterval = 0) -> FolderScanner {
        var probes: [String: MediaProbe] = [:]
        for name in names { probes["/s/\(name).mkv"] = F.media(.audio, .subtitles) }
        let files = names.map { flagged.contains($0) ? F.file($0 + ".mkv", size: 0) : F.file($0 + ".mkv") }
        var scanner = F.scanner(FakeLister(folders: ["/s": files, "/o": []]), FakeIdentifier(probes, delayNanoseconds: delay))
        scanner.progressInterval = interval
        return scanner
    }

    func testSplitReportsListingThenOneBasedCountsUpToTheTotal() async throws {
        let recorder = Recorder()
        let names = (1...9).map { "E\($0)" }
        _ = try await splitScanner(names).scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) })
        XCTAssertEqual(recorder.all.first, .listing)
        let readings = recorder.readings
        XCTAssertEqual(readings.first?.0, 1)
        XCTAssertEqual(readings.last?.0, 9)
        XCTAssertTrue(readings.allSatisfy { $0.1 == 9 && $0.0 >= 1 && $0.0 <= 9 })
        XCTAssertEqual(readings.map(\.0), readings.map(\.0).sorted(), "never goes backwards")
        // 1 at the start, then one per finished file, capped at 9: 1,2,...,9,9.
        XCTAssertEqual(readings.map(\.0), [1, 2, 3, 4, 5, 6, 7, 8, 9, 9])
    }

    func testNamesFlaggedBeforeReadingCountAsFinished() async throws {
        let recorder = Recorder()
        let names = ["A", "B", "C", "D"]
        _ = try await splitScanner(names, flagged: ["A", "B"]).scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) })
        XCTAssertEqual(recorder.readings.map(\.0), [3, 4, 4])
        XCTAssertTrue(recorder.readings.allSatisfy { $0.1 == 4 })
    }

    func testEveryNameFlaggedShowsTheTotalOnce() async throws {
        let recorder = Recorder()
        _ = try await splitScanner(["A", "B"], flagged: ["A", "B"]).scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) })
        XCTAssertEqual(recorder.readings.map(\.0), [2])
    }

    func testAnEmptyFolderReportsOnlyListing() async throws {
        let recorder = Recorder()
        _ = try await splitScanner([]).scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) })
        XCTAssertEqual(recorder.all, [.listing])
    }

    func testDefaultThrottleStillSendsTheFirstAndLastCount() async throws {
        let recorder = Recorder()
        let names = (1...30).map { "E\($0)" }
        let scanner = splitScanner(names, interval: ProgressThrottle.defaultInterval)
        _ = try await scanner.scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) })
        let counts = recorder.readings.map(\.0)
        XCTAssertEqual(counts.first, 1)
        XCTAssertEqual(counts.last, 30)
        XCTAssertLessThan(counts.count, 31, "fast probes are throttled")
    }

    func testRemuxCountsANameWhenBothFilesAreRead() async throws {
        let recorder = Recorder()
        let lister = FakeLister(folders: [
            "/v": [F.file("A.mkv"), F.file("B.mkv"), F.file("C.mkv")],
            "/a": [F.file("A.mka"), F.file("B.mka")],
            "/o": [],
        ])
        let identifier = FakeIdentifier([
            "/v/A.mkv": F.media(.video), "/v/B.mkv": F.media(.video),
            "/a/A.mka": F.media(.audio), "/a/B.mka": F.media(.audio),
        ])
        var scanner = F.scanner(lister, identifier)
        scanner.progressInterval = 0
        let result = try await scanner.scanRemux(video: "/v", audio: "/a", output: "/o", progress: { recorder.append($0) })
        XCTAssertEqual(result.nameCount, 3)
        XCTAssertEqual(recorder.all.first, .listing)
        // C has no .mka (finished without reading): starts at 2 of 3, then A and B.
        XCTAssertEqual(recorder.readings.map(\.0), [2, 3, 3])
        XCTAssertTrue(recorder.readings.allSatisfy { $0.1 == 3 })
    }

    func testCancellingStopsProgressAndThrows() async throws {
        let recorder = Recorder()
        let names = (1...40).map { "E\($0)" }
        let scanner = splitScanner(names, delay: 200_000_000)
        let task = Task { try await scanner.scanSplit(source: "/s", output: "/o", progress: { recorder.append($0) }) }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("a cancelled scan should throw")
        } catch is CancellationError {}
        let last = recorder.readings.last?.0 ?? 0
        XCTAssertLessThan(last, 40)
    }

    func testCurrentIsFinishedPlusOneCapped() {
        XCTAssertEqual(ScanProgressReporter.current(finished: 0, total: 9), 1)
        XCTAssertEqual(ScanProgressReporter.current(finished: 8, total: 9), 9)
        XCTAssertEqual(ScanProgressReporter.current(finished: 9, total: 9), 9)
    }

    func testScanWithoutAProgressHandlerStillWorks() async throws {
        let result = try await splitScanner(["A"]).scanSplit(source: "/s", output: "/o")
        XCTAssertEqual(result.readyCount, 1)
    }
}
