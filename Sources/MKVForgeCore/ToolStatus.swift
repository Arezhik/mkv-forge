import Foundation

// Where mkvmerge is, for the window and Settings (layout contract v2 §8, §9; L15). Rules:
// - With no copy chosen in Settings, the automatic search finds it (ExternalTool.locate).
// - A chosen copy that is missing or doesn't run is an error: "Can't run this mkvmerge".
//   There's no silent fallback to the automatic search. Use Automatic goes back to it.
// - The not-found help lists the real search order (ExternalTool.searchDescription).

public enum ToolStatus: Equatable, Sendable {
    case checking
    /// Found by the automatic search.
    case found(path: String, version: String)
    /// The copy chosen in Settings, and it runs.
    case chosen(path: String, version: String)
    case notFound
    /// The copy chosen in Settings is missing or doesn't run.
    case chosenFails(path: String, reason: String)

    /// The mkvmerge to scan and run with. Nil when there's none that works.
    public var executable: String? {
        switch self {
        case let .found(path, _), let .chosen(path, _): return path
        case .checking, .notFound, .chosenFails: return nil
        }
    }

    public var isUsable: Bool { executable != nil }

    /// The `--version` line of the mkvmerge in use, for the debug log header.
    public var version: String? {
        switch self {
        case let .found(_, version), let .chosen(_, version): return version
        case .checking, .notFound, .chosenFails: return nil
        }
    }

    /// True when the main window shows the not-found banner (v2 §9).
    public var showsBanner: Bool {
        switch self {
        case .notFound, .chosenFails: return true
        case .checking, .found, .chosen: return false
        }
    }

    /// One line for the debug log and the placeholder window.
    public var detail: String {
        switch self {
        case .checking: return "Looking for mkvmerge…"
        case let .found(path, version), let .chosen(path, version): return "\(version) at \(path)"
        case .notFound: return "mkvmerge not found"
        case let .chosenFails(path, _): return "Can't run \(path)"
        }
    }

    // MARK: Settings (v2 §8)

    /// The path shown in the mkvmerge row (11 pt monospaced). Nil shows nothing.
    public var settingsPath: String? {
        switch self {
        case let .found(path, _), let .chosen(path, _), let .chosenFails(path, _): return path
        case .checking, .notFound: return nil
        }
    }

    /// The trailing status: `Found · v88.0`, `Chosen · v88.0`, `Not found`, `Can't run this mkvmerge`.
    public var settingsStatus: String {
        switch self {
        case .checking: return "Looking…"
        case let .found(_, version): return "Found · \(Self.shortVersion(version))"
        case let .chosen(_, version): return "Chosen · \(Self.shortVersion(version))"
        case .notFound: return "Not found"
        case .chosenFails: return "Can't run this mkvmerge"
        }
    }

    /// SF Symbol for the status. A warning is an orange triangle; found is a checkmark.
    public var settingsSymbol: String {
        switch self {
        case .checking: return "hourglass"
        case .found, .chosen: return "checkmark.circle.fill"
        case .notFound, .chosenFails: return "exclamationmark.triangle.fill"
        }
    }

    public var isWarning: Bool { showsBanner }

    /// The help line in the Location row.
    public var locationHelp: String {
        switch self {
        case .checking: return "Looking for mkvmerge…"
        case .found: return "Found automatically. Choose another copy to override."
        case .chosen: return "Chosen by you. Use Automatic goes back to the automatic search."
        case .notFound: return ExternalTool.searchDescription()
        case let .chosenFails(_, reason): return reason
        }
    }

    /// Use Automatic is enabled only when a copy was chosen (v2 §8).
    public var canUseAutomatic: Bool {
        switch self {
        case .chosen, .chosenFails: return true
        case .checking, .found, .notFound: return false
        }
    }

    /// `mkvmerge v92.0 ('Everglow') 64-bit` → `v92.0`. Anything else is returned as is.
    public static func shortVersion(_ line: String) -> String {
        for word in line.split(separator: " ") where word.hasPrefix("v") && word.dropFirst().first?.isNumber == true {
            return String(word)
        }
        return line
    }

    // MARK: Resolving

    public static let chosenMissingReason = "The chosen mkvmerge isn't there anymore. Choose it again, or use the automatic search."
    public static let chosenDoesNotRunReason = "The chosen mkvmerge didn't run. Choose another copy, or use the automatic search."

    /// Finds mkvmerge. `chosen` is the Settings choice (nil = automatic). The closures do the
    /// file system work, so this is testable without a real install.
    public static func resolve(
        chosen: String?,
        spec: ExternalToolSpec = .primary,
        automatic: () -> ExternalToolPaths?,
        locateChosen: (String) -> ExternalToolPaths?,
        version: (String) -> String?
    ) -> ToolStatus {
        let first = spec.executables.first ?? spec.name
        if let chosen, !chosen.isEmpty {
            guard let paths = locateChosen(chosen), let path = paths[first] else {
                return .chosenFails(path: chosen, reason: chosenMissingReason)
            }
            guard let line = version(path) else {
                return .chosenFails(path: path, reason: chosenDoesNotRunReason)
            }
            return .chosen(path: path, version: line)
        }
        guard let paths = automatic(), let path = paths[first] else { return .notFound }
        return .found(path: path, version: version(path) ?? "unknown version")
    }

    /// The real search, with the real file system. Slow (runs `mkvmerge --version`): call off the main thread.
    public static func resolve(chosen: String?, spec: ExternalToolSpec = .primary) -> ToolStatus {
        let status = resolve(
            chosen: chosen,
            spec: spec,
            automatic: { ExternalTool.locate(spec) },
            locateChosen: { ExternalTool.locate(spec, chosen: $0) },
            version: { ExternalTool.version(of: $0, arguments: spec.versionArguments) }
        )
        switch status {
        case let .found(path, version): DebugLog.shared.record(.tool, "\(spec.name) found \(path), version \(version)")
        case let .chosen(path, version): DebugLog.shared.record(.tool, "\(spec.name) chosen \(path), version \(version)")
        case .notFound: DebugLog.shared.record(.tool, "\(spec.name) not found", isError: true)
        case let .chosenFails(path, reason): DebugLog.shared.record(.tool, "Chosen \(spec.name) can't run (\(path)): \(reason)", isError: true)
        case .checking: break
        }
        return status
    }
}
