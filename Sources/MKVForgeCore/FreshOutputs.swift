import Foundation

// Outputs MKVForge itself just finished (docs/LESSONS.md L32). Rules:
// - A scan flags a file modified in the last minute as still changing: it may still be
//   copying. A Split output is complete as soon as MKVForge renames its temp file, so a
//   Remux scan right after a Split must not flag it.
// - After a Split batch the app records each output's path, size and modification date.
//   A Remux scan skips the still-changing rule for an .mka only when its path, size and
//   date all match a record exactly. Anything else, such as a file copied in by hand,
//   keeps the one-minute rule.
// - Memory only, never saved. A record expires after `FolderScanner.stillChangingInterval`,
//   when the rule no longer flags the file anyway.

/// A file's size and modification date, read the same way `LocalFolderLister` reads them.
public struct FileStamp: Equatable, Sendable {
    public var size: Int64
    public var modified: Date

    public init(size: Int64, modified: Date) {
        self.size = size
        self.modified = modified
    }

    public init(_ entry: FileEntry) {
        self.init(size: entry.size, modified: entry.modified)
    }

    /// Nil when the file isn't there or can't be read.
    public static func read(atPath path: String) -> FileStamp? {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolved),
              let modified = attributes[.modificationDate] as? Date else { return nil }
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return FileStamp(size: size, modified: modified)
    }
}

/// The outputs of recent Split batches in this session.
public struct FreshOutputs: Equatable, Sendable {
    private struct Record: Equatable, Sendable {
        var stamp: FileStamp
        var recordedAt: Date
    }

    private var records: [String: Record] = [:]

    public init() {}

    public var count: Int { records.count }

    /// Remembers one finished output. A newer record for the same path replaces the old one.
    public mutating func record(_ path: String, _ stamp: FileStamp, at date: Date) {
        records[Self.key(path)] = Record(stamp: stamp, recordedAt: date)
    }

    /// Reads and records every path that is still there.
    public mutating func record(paths: [String], at date: Date) {
        for path in paths {
            if let stamp = FileStamp.read(atPath: path) { record(path, stamp, at: date) }
        }
    }

    /// Drops the records the still-changing rule no longer needs.
    public mutating func prune(now: Date) {
        records = records.filter { Self.isCurrent($0.value, at: now) }
    }

    /// True when `entry`, found at `path`, is exactly the file MKVForge wrote there.
    public func isOwnOutput(_ path: String, _ entry: FileEntry, at date: Date) -> Bool {
        guard let record = records[Self.key(path)], Self.isCurrent(record, at: date) else { return false }
        return record.stamp == FileStamp(entry)
    }

    private static func isCurrent(_ record: Record, at date: Date) -> Bool {
        let age = date.timeIntervalSince(record.recordedAt)
        return age >= 0 && age < FolderScanner.stillChangingInterval
    }

    /// The same path written two ways (a doubled slash, `..`, a symlinked folder) is one key.
    static func key(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
