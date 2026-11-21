import XCTest
@testable import MKVForgeCore

final class ScanCaptionTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let us = Locale(identifier: "en_US_POSIX")
    // 2027-01-15 21:12 UTC.
    private let time = Date(timeIntervalSince1970: 1_800_047_520)

    private func item(_ name: String, ready: Bool = true, mka: Bool = false) -> ScanItem {
        ScanItem(baseName: name, sourcePath: "/s/\(name).mkv", mkaPath: mka ? "/a/\(name).mka" : nil, outputPath: "/o/\(name).mka",
                 issues: ready ? [] : [.noAudio(fileName: name + ".mkv")])
    }

    func testScannedSplitCaption() {
        let result = ScanResult(mode: .split, scannedAt: time, items: (1...7).map { item("E\($0)") })
        XCTAssertEqual(ScanCaption.scanned(result, timeZone: utc, locale: us), "Scanned 9:12 PM · 7 MKV files")
        let one = ScanResult(mode: .split, scannedAt: time, items: [item("A")])
        XCTAssertEqual(ScanCaption.scanned(one, timeZone: utc, locale: us), "Scanned 9:12 PM · 1 MKV file")
    }

    func testScannedRemuxCaptionCountsNamesAndPairs() {
        let items = [item("A", mka: true), item("B", mka: true), item("C", mka: true), item("D", mka: true),
                     item("E"), ScanItem(baseName: "F", sourcePath: nil, mkaPath: "/a/F.mka", outputPath: "/o/F.mkv", issues: [.noMatchingMKV])]
        let result = ScanResult(mode: .remux, scannedAt: time.addingTimeInterval(8 * 60), items: items)
        XCTAssertEqual(ScanCaption.scanned(result, timeZone: utc, locale: us), "Scanned 9:20 PM · 6 names · 4 pairs")
    }

    func testScanningCaptions() {
        XCTAssertEqual(ScanCaption.scanning(.listing), "Scanning…")
        XCTAssertEqual(ScanCaption.scanning(.reading(current: 3, total: 9)), "Scanning… 3 of 9")
        XCTAssertEqual(ScanCaption.escHelp, "Press Esc to stop scanning")
    }

    func testIdleCaptions() {
        var split = ModeState(mode: .split)
        XCTAssertEqual(ScanCaption.idle(split, toolUsable: true), "Choose a Source and an Output folder to scan")
        XCTAssertEqual(ScanCaption.idle(ModeState(mode: .remux), toolUsable: true), "Choose a Video, an Audio and an Output folder to scan")
        split.setFolder("/s", for: .source)
        split.setFolder("/o", for: .output)
        XCTAssertEqual(ScanCaption.idle(split, toolUsable: false), "Scan needs mkvmerge")
        XCTAssertEqual(ScanCaption.idle(split, toolUsable: true), "Not scanned yet")
        split.applyScan(ScanResult(mode: .split, scannedAt: time, items: [item("A"), item("B")]))
        XCTAssertEqual(ScanCaption.idle(split, toolUsable: true, timeZone: utc, locale: us), "Scanned 9:12 PM · 2 MKV files")
    }

    func testShortTimeUsesAPlainSpace() {
        let text = ScanCaption.shortTime(time, timeZone: utc, locale: Locale(identifier: "en_US"))
        XCTAssertFalse(text.contains("\u{202F}"))
        XCTAssertTrue(text.hasPrefix("9:12"), text)
    }

    func testAnnouncements() {
        XCTAssertEqual(ScanCaption.startedAnnouncement, "Scanning")
        XCTAssertEqual(ScanCaption.stoppedAnnouncement, "Scan stopped")
        let items = (1...5).map { item("E\($0)") } + [item("F1", ready: false), item("F2", ready: false)]
        XCTAssertEqual(ScanCaption.finishedAnnouncement(ScanResult(mode: .split, scannedAt: time, items: items)), "Scan finished, 7 files, 2 flagged")
        XCTAssertEqual(ScanCaption.finishedAnnouncement(ScanResult(mode: .remux, scannedAt: time, items: [item("A", mka: true)])), "Scan finished, 1 name")
    }

    func testFailedCaptionUsesTheErrorMessage() {
        let error = ScanError.folderNotReadable(.source, path: "/gone")
        XCTAssertEqual(ScanCaption.failed(error), error.errorDescription)
        XCTAssertFalse(ScanCaption.failed(error).isEmpty)
    }
}
