import Foundation

// Scan results (docs/scaffold.md, Validation / Scan Rules; layout contract v2 §4–§5):
// - One row per base name. Remux rows are the union of the Video and Audio folders.
// - A row with any issue is an Issue row: unchecked, and it can't run in v1.
// - Reason shows the first issue by priority plus "(+N more)"; the help text lists all.

public enum ScanMode: String, Equatable, Sendable {
    case split
    case remux
}

/// Which folder a file came from. The names match the folder rows in the window.
public enum FolderRole: String, Equatable, Sendable {
    case source
    case video
    case audio
    case output

    public var displayName: String {
        switch self {
        case .source: return "Source"
        case .video: return "Video"
        case .audio: return "Audio"
        case .output: return "Output"
        }
    }

    /// How a reason names the file: Split has one input, Remux has two.
    var fileNoun: String {
        switch self {
        case .source, .output: return "file"
        case .video: return ".mkv"
        case .audio: return ".mka"
        }
    }
}

/// Why a row can't run. `reason` goes in the Reason column, `detail` in its help tag.
public enum ScanIssue: Equatable, Sendable {
    case duplicateName(FolderRole, fileNames: [String])
    case noMatchingMKA
    case noMatchingMKV
    case emptyFile(FolderRole, fileName: String)
    case stillChanging(FolderRole, fileName: String)
    /// No read permission, or mkvmerge couldn't open or recognize the file.
    case unreadable(FolderRole, fileName: String, detail: String?)
    case notMatroska(FolderRole, fileName: String, containerType: String)
    case noTracks(FolderRole, fileName: String)
    case noAudioOrSubtitles(fileName: String)
    case noAudio(fileName: String)
    case noSubtitles(fileName: String)
    case noVideoTrack(fileName: String)
    case extraTracks(fileName: String, audio: Int, subtitles: Int)
    case mkaHasNoAudioOrSubtitles(fileName: String)
    case outputIsVideoFolder
    case outputExists(fileName: String)

    /// Lower comes first in the Reason column.
    public var priority: Int {
        switch self {
        case .duplicateName: return 0
        case .noMatchingMKA, .noMatchingMKV: return 1
        case .outputIsVideoFolder: return 2
        case .emptyFile: return 3
        case .stillChanging: return 4
        case .unreadable: return 5
        case .notMatroska: return 6
        case .noTracks: return 7
        case .noAudioOrSubtitles, .noAudio, .noSubtitles, .noVideoTrack, .extraTracks, .mkaHasNoAudioOrSubtitles: return 8
        case .outputExists: return 9
        }
    }

    public var reason: String {
        switch self {
        case let .duplicateName(role, _):
            return "Duplicate name in \(role.displayName) folder"
        case .noMatchingMKA:
            return "No matching .mka in Audio folder"
        case .noMatchingMKV:
            return "No matching .mkv in Video folder"
        case let .emptyFile(role, _):
            return "Empty \(role.fileNoun) (0 bytes)"
        case let .stillChanging(role, _):
            return role == .source ? "Still changing (modified in the last minute)" : "\(role.fileNoun) still changing (modified in the last minute)"
        case let .unreadable(role, _, _):
            return role == .source ? "mkvmerge can't read this file" : "mkvmerge can't read the \(role.fileNoun)"
        case let .notMatroska(_, _, type):
            return "Not a Matroska file (\(type.isEmpty ? "unknown type" : type))"
        case let .noTracks(role, _):
            return role == .source ? "No tracks found (damaged file?)" : "No tracks in the \(role.fileNoun) (damaged file?)"
        case .noAudioOrSubtitles:
            return "No audio or subtitle tracks found"
        case .noAudio:
            return "No audio tracks found"
        case .noSubtitles:
            return "No subtitle tracks found"
        case .noVideoTrack:
            return "No video track in the .mkv"
        case let .extraTracks(_, audio, subtitles):
            return "Video file has extra tracks (\(Self.trackCounts(audio: audio, subtitles: subtitles)))"
        case .mkaHasNoAudioOrSubtitles:
            return "No audio or subtitle tracks in the .mka"
        case .outputIsVideoFolder:
            return "Output folder is the Video folder"
        case let .outputExists(fileName):
            return "\(fileName) already exists in Output folder"
        }
    }

    public var detail: String {
        switch self {
        case let .duplicateName(role, names):
            return "The \(role.displayName) folder has more than one file with this name: \(names.joined(separator: ", ")). Keep one, then scan again."
        case .noMatchingMKA:
            return "There's no .mka with exactly this name in the Audio folder."
        case .noMatchingMKV:
            return "There's no .mkv with exactly this name in the Video folder."
        case let .emptyFile(_, name):
            return "\(name) is empty (0 bytes)."
        case let .stillChanging(_, name):
            return "\(name) was modified less than a minute ago and may still be copying. Scan again when it's done."
        case let .unreadable(_, name, detail):
            if let detail, !detail.isEmpty { return "mkvmerge can't read \(name): \(detail)" }
            return "mkvmerge can't read \(name). It may be damaged or not a Matroska file."
        case let .notMatroska(_, name, type):
            return "\(name) is \(type.isEmpty ? "not a Matroska file" : "a \(type) file, not Matroska"), even though its name ends in .\((name as NSString).pathExtension)."
        case let .noTracks(_, name):
            return "mkvmerge found no tracks in \(name). It may be damaged or incomplete."
        case let .noAudioOrSubtitles(name):
            return "No audio or subtitle tracks found in \(name), so there's nothing to split."
        case let .noAudio(name):
            return "No audio tracks found in \(name). Split needs at least one audio track and one subtitle track."
        case let .noSubtitles(name):
            return "No subtitle tracks found in \(name). Split needs at least one audio track and one subtitle track."
        case let .noVideoTrack(name):
            return "\(name) has no video track, so there's nothing to remux."
        case let .extraTracks(name, audio, subtitles):
            return "\(name) has \(Self.trackCounts(audio: audio, subtitles: subtitles)) besides its video. Remux expects a video-only .mkv."
        case let .mkaHasNoAudioOrSubtitles(name):
            return "\(name) has no audio or subtitle tracks, so there's nothing to add to the video."
        case .outputIsVideoFolder:
            return "The finished .mkv would replace the video file. Choose a different Output folder."
        case let .outputExists(name):
            return "\(name) is already in the Output folder. MKVForge never overwrites files. Move or rename it, then scan again."
        }
    }

    static func trackCounts(audio: Int, subtitles: Int) -> String {
        var parts: [String] = []
        if audio > 0 { parts.append("\(audio) audio") }
        if subtitles > 0 { parts.append("\(subtitles) subtitle\(subtitles == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}

/// One queue row after a scan.
public struct ScanItem: Identifiable, Equatable, Sendable {
    /// The base name. Rescans keep a still-Ready row's checkbox by this name.
    public var id: String { baseName }
    public let baseName: String
    /// Split: the source .mkv. Remux: the video .mkv.
    public var sourcePath: String?
    /// Remux only: the input .mka.
    public var mkaPath: String?
    /// Where the output will go: `<Output>/<base>.mka` (Split) or `.mkv` (Remux).
    public var outputPath: String
    /// Tracks of `sourcePath`, when it was identified.
    public var sourceInfo: MediaInfo?
    /// Tracks of `mkaPath`, when it was identified.
    public var mkaInfo: MediaInfo?
    /// Sorted by priority.
    public private(set) var issues: [ScanIssue]

    public init(baseName: String, sourcePath: String?, mkaPath: String? = nil, outputPath: String, sourceInfo: MediaInfo? = nil, mkaInfo: MediaInfo? = nil, issues: [ScanIssue] = []) {
        self.baseName = baseName
        self.sourcePath = sourcePath
        self.mkaPath = mkaPath
        self.outputPath = outputPath
        self.sourceInfo = sourceInfo
        self.mkaInfo = mkaInfo
        self.issues = Self.ordered(issues)
    }

    /// Ready rows start checked. Flagged rows can't be checked in v1.
    public var isReady: Bool { issues.isEmpty }

    /// The Reason column: the first issue, plus "(+N more)". Nil when Ready (the UI shows —).
    public var reasonText: String? {
        guard let first = issues.first else { return nil }
        return issues.count > 1 ? "\(first.reason) (+\(issues.count - 1) more)" : first.reason
    }

    /// The Reason help tag: every issue's detail, one per line.
    public var helpText: String? {
        issues.isEmpty ? nil : issues.map(\.detail).joined(separator: "\n")
    }

    static func ordered(_ issues: [ScanIssue]) -> [ScanIssue] {
        issues.enumerated()
            .sorted { ($0.element.priority, $0.offset) < ($1.element.priority, $1.offset) }
            .map(\.element)
    }
}

/// Everything one Scan click produced.
public struct ScanResult: Equatable, Sendable {
    public let mode: ScanMode
    public let scannedAt: Date
    /// Sorted by name (case-insensitive, numbers in numeric order).
    public let items: [ScanItem]

    public init(mode: ScanMode, scannedAt: Date, items: [ScanItem]) {
        self.mode = mode
        self.scannedAt = scannedAt
        self.items = items.sorted { Self.nameOrder($0.baseName, $1.baseName) }
    }

    /// Rows (base names).
    public var nameCount: Int { items.count }
    /// Remux: names with both a .mkv and a .mka. Split: rows with a source.
    public var pairCount: Int {
        items.filter { $0.sourcePath != nil && (mode == .split || $0.mkaPath != nil) }.count
    }
    public var readyCount: Int { items.filter(\.isReady).count }
    public var flaggedCount: Int { items.count - readyCount }

    static func nameOrder(_ a: String, _ b: String) -> Bool {
        switch a.compare(b, options: [.caseInsensitive, .numeric]) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return a < b
        }
    }
}
