import Foundation

// mkvmerge's messages (Phase 3 research, mkvmerge 82.0 and 103.0; docs/LESSONS.md L28). Rules:
// - mkvmerge prints warnings and errors on standard output, as lines starting with
//   `Warning:` and `Error:`. Standard error stays empty, so both streams are read here.
// - Progress comes as `Progress: 4%` pieces separated by carriage returns, not newlines.
//   They're dropped.
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
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Progress:") }
    }

    static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}
