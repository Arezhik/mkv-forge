import Foundation

// mkvmerge's messages (Phase 3 research, mkvmerge 82.0 and 103.0; docs/LESSONS.md L28). Rules:
// - mkvmerge prints warnings and errors on standard output, as lines starting with
//   `Warning:` and `Error:`. Standard error stays empty, so both streams are read here.
// - Without `--gui-mode`, progress is `Progress: 4%` pieces separated by carriage returns.
//   With `--gui-mode` (mux only), the same stream uses `#GUI#progress`, `#GUI#warning`
//   and `#GUI#error`. Progress is dropped. GUI warnings and errors are mapped back to
//   `Warning:` and `Error:` so the Reason text stays the same.
// - The Reason column gets the first warning or error line; the help tag gets the rest
//   (docs/design/v1-layout-contract_v2.md §4).

public struct MKVMergeOutput: Equatable, Sendable {
    /// Raw text longer than this is cut, with "…" at the end.
    public static let rawLimit = 4000
    /// The Reason text when mkvmerge exits 1 without a `Warning:` line.
    public static let noWarningDetails = "mkvmerge reported a warning (no details)"

    /// Every message line, in order, without progress pieces or blank lines.
    public let lines: [String]

    public init(standardOutput: Data, standardError: Data = Data()) {
        let text = Self.decode(standardOutput) + "\n" + Self.decode(standardError)
        lines = Self.messageLines(text)
    }

    public init(result: ToolCommandResult) {
        self.init(standardOutput: result.standardOutput, standardError: result.standardError)
    }

    public var warnings: [String] { lines.filter { $0.hasPrefix("Warning:") } }
    public var errors: [String] { lines.filter { $0.hasPrefix("Error:") } }

    /// All message lines, cut at `rawLimit` characters. This is the failed row's help text.
    public var rawText: String {
        let text = lines.joined(separator: "\n")
        if text.count <= Self.rawLimit { return text }
        return String(text.prefix(Self.rawLimit)) + "…"
    }

    /// Reason for a failed run: `mkvmerge exit 2: <first error, without "Error: ">`.
    public func failureReason(status: Int32) -> String {
        guard let first = errors.first else { return "mkvmerge exit \(status) (no details)" }
        let message = String(first.dropFirst("Error:".count)).trimmingCharacters(in: .whitespaces)
        return "mkvmerge exit \(status): \(message)"
    }

    /// Reason for exit 1: the first warning line (prefix kept), plus "(+N more)".
    public static func warningReason(_ warnings: [String]) -> String {
        guard let first = warnings.first else { return noWarningDetails }
        return warnings.count > 1 ? "\(first) (+\(warnings.count - 1) more)" : first
    }

    /// Help tag for exit 1: every warning line.
    public static func warningHelp(_ warnings: [String]) -> String {
        warnings.isEmpty ? noWarningDetails : warnings.joined(separator: "\n")
    }

    static func messageLines(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" })
            .compactMap { MKVMergeGUIParser.reasonLine(String($0)) }
    }

    static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

/// `#GUI#` lines from `mkvmerge --gui-mode` (mux only). Playlist-scan progress, between
/// `#GUI#begin_scanning_playlists` and `#GUI#end_scanning_playlists`, is not the file's percent.
public struct MKVMergeGUIParser: Sendable {
    private var scanningPlaylists = false

    public init() {}

    /// A mux percent in 0...100, or nil when this line is not one.
    public mutating func progressPercent(in line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#GUI#begin_scanning_playlists") {
            scanningPlaylists = true
            return nil
        }
        if trimmed.hasPrefix("#GUI#end_scanning_playlists") {
            scanningPlaylists = false
            return nil
        }
        guard trimmed.hasPrefix("#GUI#progress") else { return nil }
        guard !scanningPlaylists else { return nil }
        return Self.percent(in: trimmed)
    }

    /// A Reason-text line, or nil for progress, playlist markers, and blank lines.
    /// `#GUI#warning` / `#GUI#error` become `Warning:` / `Error:`.
    public static func reasonLine(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("Progress:") || trimmed.hasPrefix("#GUI#progress") { return nil }
        if trimmed.hasPrefix("#GUI#begin_scanning_playlists") || trimmed.hasPrefix("#GUI#end_scanning_playlists") {
            return nil
        }
        if let warning = prefixed(trimmed, marker: "#GUI#warning", prefix: "Warning:") { return warning }
        if let error = prefixed(trimmed, marker: "#GUI#error", prefix: "Error:") { return error }
        return trimmed
    }

    private static func percent(in trimmed: String) -> Int? {
        let rest = trimmed.dropFirst("#GUI#progress".count).trimmingCharacters(in: .whitespaces)
        guard let mark = rest.firstIndex(of: "%") else { return nil }
        let number = rest[..<mark].trimmingCharacters(in: .whitespaces)
        guard let value = Int(number) else { return nil }
        return min(100, max(0, value))
    }

    private static func prefixed(_ line: String, marker: String, prefix: String) -> String? {
        guard line.hasPrefix(marker) else { return nil }
        let rest = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        if rest.isEmpty { return prefix }
        if rest.hasPrefix(prefix) { return String(rest) }
        return "\(prefix) \(rest)"
    }
}
