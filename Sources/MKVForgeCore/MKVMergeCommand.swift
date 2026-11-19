import Foundation

// mkvmerge command lines (docs/scaffold.md, MKVToolNix Integration; verified against
// mkvmerge 82.0 and 103.0 during Phase 2 research). Rules:
// - Strip everything: title, mux date, track statistics tags, global and track tags,
//   attachments. Keep every audio and subtitle track and the chapters.
// - mkvmerge copies names, languages, and flags from the source unless told otherwise,
//   and Matroska reads a missing language as English and a missing default flag as on.
//   So each kept track gets an empty name, `und`, and every flag set to 0.
// - Per-track options only for track IDs `mkvmerge -J` reported. An unknown ID is a
//   warning (exit 1).
// - Paths must be absolute: mkvmerge has no `--`, and an argument starting with `@` is
//   read as an option file.
// - The output path is a parameter, so the Running phase can pass a temporary name.

public enum CommandError: Error, Equatable, LocalizedError {
    case relativePath(String)

    public var errorDescription: String? {
        switch self {
        case let .relativePath(path): return "Internal error: mkvmerge needs an absolute path, got \(path)"
        }
    }
}

public enum MKVMergeCommand {
    /// Options that come before the inputs in both workflows.
    static let globalOptions = ["--title", "", "--no-date", "--disable-track-statistics-tags"]

    /// Options that drop everything but tracks and chapters from one input file.
    static let stripFileOptions = ["--no-attachments", "--no-global-tags", "--no-track-tags"]

    /// Empty name, `und`, and every flag off, for each track ID (sorted).
    public static func clearTrackOptions(for trackIDs: [Int]) -> [String] {
        trackIDs.sorted().flatMap { id -> [String] in
            [
                "--track-name", "\(id):",
                "--language", "\(id):und",
                "--default-track-flag", "\(id):0",
                "--forced-display-flag", "\(id):0",
                "--commentary-flag", "\(id):0",
                "--original-flag", "\(id):0",
                "--hearing-impaired-flag", "\(id):0",
                "--visual-impaired-flag", "\(id):0",
                "--text-descriptions-flag", "\(id):0",
            ]
        }
    }

    /// Split: every audio and subtitle track plus chapters from `source` into `output` (.mka).
    /// `tracks` comes from identifying `source`.
    public static func split(source: String, output: String, tracks: [TrackInfo]) throws -> [String] {
        try requireAbsolute(source, output)
        let keep = tracks.filter { $0.kind == .audio || $0.kind == .subtitles }.map(\.id)
        var arguments: [String] = ["-o", output]
        arguments += globalOptions
        arguments += ["--no-video"]
        arguments += stripFileOptions
        arguments += clearTrackOptions(for: keep)
        arguments.append(source)
        return arguments
    }

    /// Remux: the video track from `video`, then every track and the chapters from `mka`.
    /// `videoTracks` comes from identifying `video`; its video tracks get cleared too.
    public static func remux(video: String, mka: String, output: String, videoTracks: [TrackInfo]) throws -> [String] {
        try requireAbsolute(video, mka, output)
        let videoIDs = videoTracks.filter { $0.kind == .video }.map(\.id)
        var arguments: [String] = ["-o", output]
        arguments += globalOptions
        arguments += ["--no-audio", "--no-subtitles", "--no-chapters"]
        arguments += stripFileOptions
        arguments += clearTrackOptions(for: videoIDs)
        arguments.append(video)
        arguments += ["--no-video"]
        arguments += stripFileOptions
        arguments.append(mka)
        return arguments
    }

    static func requireAbsolute(_ paths: String...) throws {
        for path in paths where !path.hasPrefix("/") {
            throw CommandError.relativePath(path)
        }
    }
}
