import Foundation
@testable import MKVForgeCore

/// Folders in memory. A folder that isn't in `folders` can't be read.
struct FakeLister: FolderListing {
    var folders: [String: [FileEntry]]
    var existing: Set<String> = []

    func entries(in folder: String) throws -> [FileEntry] {
        guard let entries = folders[folder] else { throw CocoaError(.fileReadNoPermission) }
        return entries
    }

    func fileExists(atPath path: String) -> Bool { existing.contains(path) }
}

/// Answers from a table and records how many probes ran at once.
actor FakeIdentifier: TrackIdentifying {
    private let probes: [String: MediaProbe]
    private let delayNanoseconds: UInt64
    private(set) var calls: [String] = []
    private var inFlight = 0
    private(set) var maxInFlight = 0

    init(_ probes: [String: MediaProbe] = [:], delayNanoseconds: UInt64 = 0) {
        self.probes = probes
        self.delayNanoseconds = delayNanoseconds
    }

    func identify(_ path: String) async throws -> MediaProbe {
        calls.append(path)
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        defer { inFlight -= 1 }
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return probes[path] ?? .unreadable(detail: "fake has no answer for \(path)")
    }
}

enum ScanFixture {
    static let scanTime = Date(timeIntervalSince1970: 1_800_000_000)
    static let old = scanTime.addingTimeInterval(-3600)

    static func file(_ name: String, size: Int64 = 1000, modified: Date = old, readable: Bool = true, regular: Bool = true) -> FileEntry {
        FileEntry(name: name, isRegularFile: regular, size: size, modified: modified, isReadable: readable)
    }

    /// A readable Matroska file with these tracks, IDs from 0.
    /// `chapterEditions` defaults to 0 (no chapters). Split treats that as a Ready note
    /// when the file has audio, so a fixture that should have no Reason passes a count.
    static func media(_ kinds: TrackKind..., type: String = "Matroska", chapterEditions: Int = 0) -> MediaProbe {
        .readable(MediaInfo(containerType: type, tracks: kinds.enumerated().map { TrackInfo(id: $0.offset, kind: $0.element) }, chapterEditions: chapterEditions))
    }

    static func scanner(_ lister: FakeLister, _ identifier: FakeIdentifier, maxConcurrentProbes: Int = 4) -> FolderScanner {
        FolderScanner(lister: lister, identifier: identifier, now: { scanTime }, maxConcurrentProbes: maxConcurrentProbes)
    }
}

extension ScanResult {
    func item(_ name: String) -> ScanItem? { items.first { $0.baseName == name } }
}
