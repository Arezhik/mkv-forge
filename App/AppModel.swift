import AppKit
import Foundation
import MKVForgeCore

/// Where `mkvmerge` was found at launch. The Settings override and the not-found
/// banner come with the app UI phase (docs/design/v1-layout-contract_v2.md §8, §9).
enum ToolStatus: Equatable, Sendable {
    case checking
    case found(path: String, version: String)
    case notFound

    /// Window subtitle.
    var subtitle: String {
        switch self {
        case .checking: return "Looking for MKVToolNix…"
        case .found: return "MKVToolNix found"
        case .notFound: return "MKVToolNix not found"
        }
    }

    /// One line for the window and Settings.
    var detail: String {
        switch self {
        case .checking: return "Looking for mkvmerge…"
        case let .found(path, version): return "\(version) at \(path)"
        case .notFound: return "mkvmerge not found"
        }
    }
}

/// Owns the debug log and the tool check. The window watches this object.
/// The real work (scanning, validation, running mkvmerge) belongs in the MKVForgeCore
/// package so it can be tested with `swift test` on Linux; this class only feeds it.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var toolStatus: ToolStatus = .checking

    init() {
        DebugLog.shared.configure(directory: DebugLog.libraryLogsDirectory, mirror: { AppLog.write($0) })
        logLaunch()
        detectTool()
    }

    /// Looks for mkvmerge off the main thread and logs the result.
    func detectTool() {
        Task {
            let status = await Task.detached(priority: .utility) { () -> ToolStatus in
                let spec = ExternalToolSpec.primary
                guard let tools = ExternalTool.locate(spec) else {
                    DebugLog.shared.record(.tool, "\(spec.name) not found", isError: true)
                    return .notFound
                }
                let first = spec.executables.first ?? spec.name
                let path = tools[first] ?? ""
                let version = ExternalTool.version(of: path, arguments: spec.versionArguments) ?? "unknown version"
                let paths = spec.executables.compactMap { tools[$0] }.joined(separator: ", ")
                DebugLog.shared.record(.tool, "\(spec.name) found \(paths), version \(version)")
                return .found(path: path, version: version)
            }.value
            toolStatus = status
        }
    }

    // MARK: Debug log

    /// Help menu. The file lands on the Desktop, with a save panel if that fails.
    func exportDebugLog() {
        let settings = SettingsSummary.current()
        Task {
            let environment = await Task.detached(priority: .userInitiated) {
                DebugMachine.environment(settings: settings)
            }.value
            let name = DebugLogDocument.fileName(at: Date())
            DebugLog.shared.record(.lifecycle, "Exporting debug log \(name)")
            let text = DebugLogDocument.document(
                environment: environment,
                logText: DebugLog.shared.recentText(),
                homeDirectory: NSHomeDirectory()
            )
            DebugLogExporter.write(text: text, fileName: name)
        }
    }

    private func logLaunch() {
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        DebugLog.shared.record(.lifecycle, "Launched \(AppVersion.marketing) (\(AppVersion.build)), \(system)")
        DebugLog.shared.record(.lifecycle, "Settings \(SettingsSummary.current())")
    }
}
