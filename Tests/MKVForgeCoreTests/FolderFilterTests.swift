import XCTest
@testable import MKVForgeCore

final class FolderFilterTests: XCTestCase {
    func testOnlyTopLevelVisibleFilesWithTheExtension() {
        let entries = [
            FileEntry(name: "Show - S01E01.mkv"),
            FileEntry(name: "Movie.MKV"),
            FileEntry(name: ".hidden.mkv"),
            FileEntry(name: "._Show - S01E01.mkv"),
            FileEntry(name: "Folder.mkv", isRegularFile: false),
            FileEntry(name: "Show - S01E01.mka"),
            FileEntry(name: "Show - S01E01.en.srt"),
            FileEntry(name: "Partial.mkv.part"),
            FileEntry(name: "noextension"),
        ]
        XCTAssertEqual(ScanFilter.candidates(entries, fileExtension: "mkv").map(\.name), ["Show - S01E01.mkv", "Movie.MKV"])
        XCTAssertEqual(ScanFilter.candidates(entries, fileExtension: "mka").map(\.name), ["Show - S01E01.mka"])
    }

    func testBaseNameDropsOnlyTheLastExtension() {
        XCTAssertEqual(FileEntry(name: "The.Expanse.S01E01.mkv").baseName, "The.Expanse.S01E01")
        XCTAssertEqual(FileEntry(name: "Name - S01E01 - title.MKA").baseName, "Name - S01E01 - title")
    }

    func testGroupingIsExactButUnicodeEquivalent() {
        let nfc = "Caf\u{E9}.mkv"
        let nfd = "Cafe\u{301}.mkv"
        let groups = ScanFilter.byBaseName([FileEntry(name: nfc), FileEntry(name: nfd), FileEntry(name: "cafe.mkv"), FileEntry(name: "A.mkv"), FileEntry(name: "A.MKV")])
        XCTAssertEqual(groups["Caf\u{E9}"]?.count, 2)
        XCTAssertEqual(groups["cafe"]?.count, 1)
        XCTAssertEqual(groups["A"]?.map(\.name), ["A.MKV", "A.mkv"])
        XCTAssertEqual(groups.count, 3)
    }

    func testLocalListerReadsTheDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-lister-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: folder + "/sub.mkv", withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        try Data("abc".utf8).write(to: URL(fileURLWithPath: folder + "/a.mkv"))
        try Data().write(to: URL(fileURLWithPath: folder + "/empty.mkv"))
        try FileManager.default.createSymbolicLink(atPath: folder + "/link.mkv", withDestinationPath: folder + "/a.mkv")
        try FileManager.default.createSymbolicLink(atPath: folder + "/broken.mkv", withDestinationPath: folder + "/nothing")

        let lister = LocalFolderLister()
        let byName = Dictionary(uniqueKeysWithValues: try lister.entries(in: folder).map { ($0.name, $0) })
        XCTAssertEqual(byName["a.mkv"]?.size, 3)
        XCTAssertEqual(byName["a.mkv"]?.isRegularFile, true)
        XCTAssertEqual(byName["empty.mkv"]?.size, 0)
        XCTAssertEqual(byName["link.mkv"]?.isRegularFile, true)
        XCTAssertEqual(byName["link.mkv"]?.size, 3)
        XCTAssertEqual(byName["broken.mkv"]?.isRegularFile, false)
        XCTAssertEqual(byName["sub.mkv"]?.isRegularFile, false)
        XCTAssertLessThan(abs(byName["a.mkv"]?.modified.timeIntervalSinceNow ?? 999), 120)
        XCTAssertTrue(lister.fileExists(atPath: folder + "/a.mkv"))
        XCTAssertFalse(lister.fileExists(atPath: folder + "/b.mkv"))
        XCTAssertThrowsError(try lister.entries(in: folder + "/missing"))
    }
}
