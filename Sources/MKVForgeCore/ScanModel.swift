import Foundation

// Scan results (docs/scaffold.md, Validation / Scan Rules; layout contract v2 §4–§5;
// v2.2 when Match on MKA Name is on):
// - Exact matching: one row per base name. Remux rows are the union of the two folders.
// - Match on MKA Name: a row is a pair or one unpaired file. Ambiguous rows use the file
//   name with its extension, because `X.mka` and `X.mkv` share a base name.
// - A row with any issue is an Issue row: unchecked, and it can't run in v1.
// - Reason shows the first issue by priority plus "(+N more)"; the help text lists all.
// - A note doesn't stop a row. A Ready row with a note shows it in Reason (a Remux video
//   file with audio or subtitle tracks: only its video is used; a pair you picked says
//   `Matched by you`; a Split source with audio but no subtitles or no chapters names
//   what is missing).

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
    case noVideoTrack(fileName: String)
    case mkaHasNoAudioOrSubtitles(fileName: String)
    case outputIsVideoFolder
    case outputExists(fileName: String)
    /// Match on MKA Name: this file has more than one counterpart, or it is a counterpart
    /// of a file that does. `otherCount` is how many this row's menu lists.
    case ambiguousMatch(fileName: String, otherCount: Int, otherIsVideo: Bool)
    /// A pair that would be Ready, but `<fileName>` is already in the Output folder.
    /// Exact matching keeps `.outputExists` and its older wording (issue #33, not #30).
    case outputAlreadyExists(fileName: String)

    /// Lower comes first in the Reason column.
    public var priority: Int {
        switch self {
        case .duplicateName: return 0
        case .noMatchingMKA, .noMatchingMKV, .ambiguousMatch: return 1
        case .outputIsVideoFolder: return 2
        case .emptyFile: return 3
        case .stillChanging: return 4
        case .unreadable: return 5
        case .notMatroska: return 6
        case .noTracks: return 7
        case .noAudioOrSubtitles, .noAudio, .noVideoTrack, .mkaHasNoAudioOrSubtitles: return 8
        case .outputExists, .outputAlreadyExists: return 9
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
        case .noVideoTrack:
            return "No video track in the .mkv"
        case .mkaHasNoAudioOrSubtitles:
            return "No audio or subtitle tracks in the .mka"
        case .outputIsVideoFolder:
            return "Output folder is the Video folder"
        case let .outputExists(fileName):
            return "\(fileName) already exists in Output folder"
        case .ambiguousMatch:
            return "Ambiguous match"
        case .outputAlreadyExists:
            return "Output already exists"
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
            return "No audio tracks found in \(name). Split needs at least one audio track."
        case let .noVideoTrack(name):
            return "\(name) has no video track, so there's nothing to remux."
        case let .mkaHasNoAudioOrSubtitles(name):
            return "\(name) has no audio or subtitle tracks, so there's nothing to add to the video."
        case .outputIsVideoFolder:
            return "The finished .mkv would replace the video file. Choose a different Output folder."
        case let .outputExists(name):
            return "\(name) is already in the Output folder. MKVForge never overwrites files. Move or rename it, then scan again."
        case let .ambiguousMatch(fileName, count, otherIsVideo):
            let noun = otherIsVideo ? "video file" : "audio file"
            let plural = count == 1 ? noun : noun + "s"
            return "\(fileName) matches \(count) \(plural). Choose the right one."
        case let .outputAlreadyExists(name):
            return "\u{201C}\(name)\u{201D} is already in the Output folder. MKVForge never overwrites it."
        }
    }
}

/// Something a row should say that doesn't stop it from running. `reason` goes in the
/// Reason column of a Ready row, `detail` in its help tag.
public enum ScanNote: Equatable, Sendable {
    /// Remux: the video .mkv also has audio or subtitle tracks. Only its video track is
    /// used (`MKVMergeCommand.remux` passes `--no-audio --no-subtitles --no-chapters`).
    case videoOnly(fileName: String, audio: Int, subtitles: Int)
    /// The user picked this pair from an Ambiguous match row (v2.2 §B.3).
    case matchedByYou(videoFileName: String, audioFileName: String)
    /// Split: the source has audio and no subtitle tracks. The row stays Ready.
    case noSubtitles(fileName: String)
    /// Split: the source has audio and no chapter editions. The row stays Ready.
    case noChapters(fileName: String)

    public var reason: String {
        switch self {
        case let .videoOnly(_, audio, subtitles):
            return "Uses video only, ignores \(Self.trackCounts(audio: audio, subtitles: subtitles))"
        case .matchedByYou:
            return "Matched by you"
        case .noSubtitles:
            return "No subtitle tracks found"
        case .noChapters:
            return "No chapters found"
        }
    }

    public var detail: String {
        switch self {
        case let .videoOnly(name, audio, subtitles):
            return "\(name) also has \(Self.trackCounts(audio: audio, subtitles: subtitles)). Remux takes only its video track; the audio, subtitles and chapters come from the .mka."
        case let .matchedByYou(video, audio):
            return "You paired \(audio) with \(video)."
        case let .noSubtitles(name):
            return "No subtitle tracks found in \(name). The .mka will include its audio tracks and chapters (if any)."
        case let .noChapters(name):
            return "No chapters found in \(name). The .mka will include its audio and subtitle tracks (if any)."
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
    /// Shown in Reason only while the row has no issues.
    public private(set) var notes: [ScanNote]
    /// Queue identity. Equals `baseName` except for an ambiguous file, which uses its path
    /// so `X.mka` and `X.mkv` are two rows.
    public let rowID: String
    /// Set on an Ambiguous match row. Nil for every other row.
    public var matchMenu: RemuxMatchMenu?

    public init(baseName: String, sourcePath: String?, mkaPath: String? = nil, outputPath: String, sourceInfo: MediaInfo? = nil, mkaInfo: MediaInfo? = nil, issues: [ScanIssue] = [], notes: [ScanNote] = [], rowID: String? = nil, matchMenu: RemuxMatchMenu? = nil) {
        self.baseName = baseName
        self.sourcePath = sourcePath
        self.mkaPath = mkaPath
        self.outputPath = outputPath
        self.sourceInfo = sourceInfo
        self.mkaInfo = mkaInfo
        self.issues = Self.ordered(issues)
        self.notes = notes
        self.rowID = rowID ?? baseName
        self.matchMenu = matchMenu
    }

    /// A Ready row the user paired from Choose Match.
    public var matchedByYou: Bool {
        notes.contains { if case .matchedByYou = $0 { return true } else { return false } }
    }

    /// The `.mka` file name shown after the video name when the two stems differ.
    /// Nil for an exact pair (`V == K`), and for any row that isn't a pair.
    public var counterpartName: String? {
        guard sourcePath != nil, let mkaPath else { return nil }
        let audioFile = (mkaPath as NSString).lastPathComponent
        let audioStem = (audioFile as NSString).deletingPathExtension
        guard audioStem != baseName else { return nil }
        return audioFile
    }

    /// Name-cell help for a prefix pair: `Arrival CRF21.mkv ↔ Arrival.mka`.
    public var pairNameHelp: String? {
        guard counterpartName != nil, let sourcePath, let mkaPath else { return nil }
        let videoFile = (sourcePath as NSString).lastPathComponent
        let audioFile = (mkaPath as NSString).lastPathComponent
        return "\(videoFile) ↔ \(audioFile)"
    }

    /// Ready rows start checked. Flagged rows can't be checked in v1.
    public var isReady: Bool { issues.isEmpty }

    /// The Reason column: the first issue, plus "(+N more)". A Ready row shows its first
    /// note the same way. Nil when Ready with no notes (the UI shows —).
    public var reasonText: String? {
        let reasons = issues.isEmpty ? notes.map(\.reason) : issues.map(\.reason)
        guard let first = reasons.first else { return nil }
        return reasons.count > 1 ? "\(first) (+\(reasons.count - 1) more)" : first
    }

    /// The Reason help tag: every issue's detail (or, when Ready, every note's), one per line.
    public var helpText: String? {
        let details = issues.isEmpty ? notes.map(\.detail) : issues.map(\.detail)
        return details.isEmpty ? nil : details.joined(separator: "\n")
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
    /// Sorted by the shown name (case-insensitive, numbers in numeric order).
    public let items: [ScanItem]
    /// Set when this Remux scan used Match on MKA Name, so a pick can be re-scored
    /// without reading the folders again. Nil for Split and for exact Remux matching.
    public let inventory: RemuxInventory?
    /// Picks applied to `inventory`, in the order the user made them.
    public let picks: [RemuxPick]

    public init(mode: ScanMode, scannedAt: Date, items: [ScanItem], inventory: RemuxInventory? = nil, picks: [RemuxPick] = []) {
        self.mode = mode
        self.scannedAt = scannedAt
        self.items = items.sorted { Self.nameOrder($0.baseName, $1.baseName) }
        self.inventory = inventory
        self.picks = picks
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
