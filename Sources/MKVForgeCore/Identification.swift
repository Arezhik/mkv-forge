import Foundation

// Reading `mkvmerge -J` (docs/scaffold.md, Validation / Scan Rules). Rules:
// - `-J` is the alias for `--identification-format json --identify`. There is no
//   `--identify-json` option.
// - `-J` exits 0 even for files it can't read (empty, random bytes). Only a file it
//   can't open exits 2. So readability comes from the JSON: `errors`, then
//   `container.recognized` / `supported`. Matroska type and track checks are the scanner's.
// - Schema 19 (MKVToolNix 82) and 20 (103) carry the same fields used here. Track `uid`
//   can be larger than Int64, so it isn't decoded. Unknown keys are ignored.

/// The kind of one track, from the JSON `type` field.
public enum TrackKind: String, Equatable, Sendable {
    case video
    case audio
    case subtitles
    case other
}

/// One track, as `mkvmerge -J` reports it. `id` is the track ID that options such as
/// `--language TID:und` take.
public struct TrackInfo: Equatable, Sendable {
    public var id: Int
    public var kind: TrackKind
    public var codec: String

    public init(id: Int, kind: TrackKind, codec: String = "") {
        self.id = id
        self.kind = kind
        self.codec = codec
    }
}

/// What a readable file holds.
public struct MediaInfo: Equatable, Sendable {
    /// `container.type`, such as "Matroska" or "SRT subtitles".
    public var containerType: String
    public var tracks: [TrackInfo]
    /// Number of chapter editions (`chapters` entries). Chapters are optional in v1.
    public var chapterEditions: Int

    public init(containerType: String, tracks: [TrackInfo], chapterEditions: Int = 0) {
        self.containerType = containerType
        self.tracks = tracks
        self.chapterEditions = chapterEditions
    }

    public var isMatroska: Bool { containerType == "Matroska" }

    public func count(of kind: TrackKind) -> Int {
        tracks.filter { $0.kind == kind }.count
    }

    public func ids(of kinds: Set<TrackKind>) -> [Int] {
        tracks.filter { kinds.contains($0.kind) }.map(\.id).sorted()
    }
}

/// The result of identifying one file.
public enum MediaProbe: Equatable, Sendable {
    case readable(MediaInfo)
    /// mkvmerge couldn't open or recognize the file. `detail` is mkvmerge's first error
    /// line when it gave one.
    case unreadable(detail: String?)
}

public enum IdentificationParser {
    /// Turns one `mkvmerge -J` run into a probe result. Pure, so it's tested with JSON
    /// captured from MKVToolNix 82.0 and 103.0.
    public static func parse(status: Int32, output: Data) -> MediaProbe {
        guard let json = try? JSONDecoder().decode(IdentifyJSON.self, from: output) else {
            return .unreadable(detail: status == 0 ? "mkvmerge printed no identification" : "mkvmerge exit \(status)")
        }
        if let first = json.errors?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .unreadable(detail: firstLine(first))
        }
        if status != 0 {
            return .unreadable(detail: "mkvmerge exit \(status)")
        }
        guard let container = json.container, container.recognized == true, container.supported == true else {
            return .unreadable(detail: nil)
        }
        let tracks = (json.tracks ?? []).map { track in
            TrackInfo(id: track.id, kind: TrackKind(rawValue: track.type) ?? .other, codec: track.codec ?? "")
        }
        return .readable(MediaInfo(
            containerType: container.type ?? "",
            tracks: tracks,
            chapterEditions: json.chapters?.count ?? 0
        ))
    }

    static func firstLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Only the fields MKVForge reads. Everything is optional because unreadable files
/// leave most keys out.
private struct IdentifyJSON: Decodable {
    struct Container: Decodable {
        var recognized: Bool?
        var supported: Bool?
        var type: String?
    }

    struct Track: Decodable {
        var id: Int
        var type: String
        var codec: String?
    }

    struct Chapters: Decodable {
        var num_entries: Int?
    }

    var container: Container?
    var tracks: [Track]?
    var chapters: [Chapters]?
    var errors: [String]?
}
