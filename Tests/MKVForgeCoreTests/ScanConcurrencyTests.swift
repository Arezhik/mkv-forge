import XCTest
@testable import MKVForgeCore

final class ScanConcurrencyTests: XCTestCase {
    private typealias F = ScanFixture

    func testAtMostFourProbesAtOnce() async throws {
        let names = (1...12).map { "Episode \($0)" }
        var probes: [String: MediaProbe] = [:]
        for name in names { probes["/s/\(name).mkv"] = F.media(.audio, .subtitles) }
        let identifier = FakeIdentifier(probes, delayNanoseconds: 20_000_000)
        let lister = FakeLister(folders: ["/s": names.map { F.file($0 + ".mkv") }, "/o": []])
        let result = try await F.scanner(lister, identifier).scanSplit(source: "/s", output: "/o")
        XCTAssertEqual(result.readyCount, 12)
        let maxInFlight = await identifier.maxInFlight
        let calls = await identifier.calls
        XCTAssertEqual(calls.count, 12)
        XCTAssertGreaterThan(maxInFlight, 1)
        XCTAssertLessThanOrEqual(maxInFlight, 4)
    }

    func testOneAtATimeWhenAskedTo() async throws {
        let identifier = FakeIdentifier(["/s/A.mkv": F.media(.audio, .subtitles), "/s/B.mkv": F.media(.audio, .subtitles)], delayNanoseconds: 5_000_000)
        let lister = FakeLister(folders: ["/s": [F.file("A.mkv"), F.file("B.mkv")], "/o": []])
        _ = try await F.scanner(lister, identifier, maxConcurrentProbes: 1).scanSplit(source: "/s", output: "/o")
        let maxInFlight = await identifier.maxInFlight
        XCTAssertEqual(maxInFlight, 1)
    }

    func testCancellingTheScanStopsIt() async throws {
        let names = (1...40).map { "E\($0)" }
        let identifier = FakeIdentifier([:], delayNanoseconds: 200_000_000)
        let lister = FakeLister(folders: ["/s": names.map { F.file($0 + ".mkv") }, "/o": []])
        let scanner = F.scanner(lister, identifier)
        let task = Task { try await scanner.scanSplit(source: "/s", output: "/o") }
        try await Task.sleep(nanoseconds: 50_000_000)
        let started = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("a cancelled scan should throw")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        }
        let calls = await identifier.calls
        XCTAssertLessThan(calls.count, 40)
    }
}
