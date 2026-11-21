import Foundation

// The Scan row caption (layout contract v2 §3; v2.1 §2.2). Rules:
// - Idle: `Scanned 9:12 PM · 7 MKV files` (Remux: `Scanned 9:20 PM · 6 names · 4 pairs`),
//   `Not scanned yet`, `Choose a Source and an Output folder to scan`, `Scan needs mkvmerge`.
// - Scanning: `Scanning…` while listing, then `Scanning… 3 of 9`.
// - A scan stopped with Esc shows the previous caption again: the queue on screen is
//   still that scan, so the caption is still true (`Not scanned yet` after a first scan).

public enum ScanCaption {
    public static let notScanned = "Not scanned yet"
    public static let needsMKVMerge = "Scan needs mkvmerge"
    public static let escHelp = "Press Esc to stop scanning"

    public static func needsFolders(_ mode: ScanMode) -> String {
        switch mode {
        case .split: return "Choose a Source and an Output folder to scan"
        case .remux: return "Choose a Video, an Audio and an Output folder to scan"
        }
    }

    public static func scanning(_ progress: ScanProgress) -> String {
        switch progress {
        case .listing: return "Scanning…"
        case let .reading(current, total): return "Scanning… \(current) of \(total)"
        }
    }

    /// `Scanned 9:12 PM · 7 MKV files` / `Scanned 9:20 PM · 6 names · 4 pairs`.
    public static func scanned(_ result: ScanResult, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let time = shortTime(result.scannedAt, timeZone: timeZone, locale: locale)
        switch result.mode {
        case .split:
            return "Scanned \(time) · \(count(result.nameCount, "MKV file"))"
        case .remux:
            return "Scanned \(time) · \(count(result.nameCount, "name")) · \(count(result.pairCount, "pair"))"
        }
    }

    /// The caption for a mode that isn't scanning.
    public static func idle(_ state: ModeState, toolUsable: Bool, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        if let scan = state.scan { return scanned(scan, timeZone: timeZone, locale: locale) }
        if !state.hasAllFolders { return needsFolders(state.mode) }
        if !toolUsable { return needsMKVMerge }
        return notScanned
    }

    // MARK: VoiceOver (v2.1 §2.5), at most one announcement per event

    public static let startedAnnouncement = "Scanning"
    public static let stoppedAnnouncement = "Scan stopped"

    /// `Scan finished, 7 files, 2 flagged` (Remux counts names). No flagged part when none are.
    public static func finishedAnnouncement(_ result: ScanResult) -> String {
        var text = "Scan finished, \(count(result.nameCount, result.mode == .split ? "file" : "name"))"
        if result.flaggedCount > 0 { text += ", \(result.flaggedCount) flagged" }
        return text
    }

    /// The caption when a scan fails (a folder can't be read): the error's own message.
    public static func failed(_ error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The scan didn't finish." : trimmed
    }

    /// `7 MKV files`, `1 MKV file`.
    public static func count(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    /// `9:12 PM` in the person's locale. Newer ICU puts a narrow no-break space before
    /// AM/PM; a plain space keeps the caption the same everywhere.
    public static func shortTime(_ date: Date, timeZone: TimeZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
