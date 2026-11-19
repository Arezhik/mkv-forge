import Foundation

// What a run works on (docs/scaffold.md, MKVToolNix Integration; issue #3). Rules:
// - Only checked rows that are Ready run, in queue order. Flagged rows never run in v1.
// - Each job keeps the tracks the scan found, so the runner can tell when a file
//   changed between the scan and the run.
// - mkvmerge writes to a hidden temp file next to the output (same folder, so the final
//   rename never copies across volumes). Only a finished run is renamed to the real name.

/// One file to Split, or one pair to Remux.
public struct RunJob: Identifiable, Equatable, Sendable {
    /// The base name, the same id as the queue row.
    public var id: String { baseName }
    public let mode: ScanMode
    public let baseName: String
    /// Split: the source .mkv. Remux: the video .mkv.
    public let sourcePath: String
    /// Remux only: the .mka.
    public let mkaPath: String?
    public let outputPath: String
    /// Tracks of `sourcePath` at scan time.
    public let sourceInfo: MediaInfo
    /// Tracks of `mkaPath` at scan time (Remux only).
    public let mkaInfo: MediaInfo?

    public init(mode: ScanMode, baseName: String, sourcePath: String, mkaPath: String? = nil, outputPath: String, sourceInfo: MediaInfo, mkaInfo: MediaInfo? = nil) {
        self.mode = mode
        self.baseName = baseName
        self.sourcePath = sourcePath
        self.mkaPath = mkaPath
        self.outputPath = outputPath
        self.sourceInfo = sourceInfo
        self.mkaInfo = mkaInfo
    }

    /// The checked rows that are Ready, in the scan's order (by name).
    public static func jobs(from scan: ScanResult, checked: Set<String>) -> [RunJob] {
        scan.items.compactMap { item -> RunJob? in
            guard item.isReady, checked.contains(item.baseName),
                  let source = item.sourcePath, let sourceInfo = item.sourceInfo else { return nil }
            if scan.mode == .remux && (item.mkaPath == nil || item.mkaInfo == nil) { return nil }
            return RunJob(
                mode: scan.mode, baseName: item.baseName, sourcePath: source,
                mkaPath: scan.mode == .remux ? item.mkaPath : nil, outputPath: item.outputPath,
                sourceInfo: sourceInfo, mkaInfo: scan.mode == .remux ? item.mkaInfo : nil
            )
        }
    }

    public var outputFolder: String { (outputPath as NSString).deletingLastPathComponent }
    public var outputName: String { (outputPath as NSString).lastPathComponent }
    public var tempPath: String { TempOutput.path(for: outputPath) }
}

/// The hidden name mkvmerge writes to: `.<base>.partial.<ext>` in the output's folder.
/// Hidden files are skipped by scans, so a leftover never shows up as a row.
public enum TempOutput {
    /// Longest file name most Mac and Linux file systems allow, in UTF-8 bytes.
    public static let maxNameBytes = 255

    public static func path(for outputPath: String) -> String {
        let folder = (outputPath as NSString).deletingLastPathComponent
        return (folder as NSString).appendingPathComponent(name(for: (outputPath as NSString).lastPathComponent))
    }

    public static func name(for outputName: String) -> String {
        let ext = (outputName as NSString).pathExtension
        let base = (outputName as NSString).deletingPathExtension
        let name = "." + base + ".partial." + ext
        if name.utf8.count <= maxNameBytes { return name }
        // Too long: a short name that is still the same for the same output.
        return ".mkvforge-" + fnv1a(outputName) + ".partial." + ext
    }

    /// 32-bit FNV-1a as 8 hex digits. Stable across launches, unlike `hashValue`.
    static func fnv1a(_ text: String) -> String {
        var hash: UInt32 = 0x811c_9dc5
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 8 - hex.count) + hex
    }
}
