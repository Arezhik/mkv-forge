import Foundation
import MKVForgeCore

/// Launch hooks for XCUITest. Active only when the process was started with
/// `--uitesting`. Settings go to an isolated defaults suite that is cleared on
/// every launch, and optional `UITEST_*` directories are applied as if the
/// person had chosen those folders. The real `UserDefaults.standard` domain is
/// never read or written in this mode.
enum UITestingLaunch {
    static let argument = "--uitesting"
    static let suiteName = "com.arezhik.MKVForge.uitesting"
    static let sourceKey = "UITEST_SOURCE_DIR"
    static let outputKey = "UITEST_OUTPUT_DIR"
    static let videoKey = "UITEST_VIDEO_DIR"
    static let audioKey = "UITEST_AUDIO_DIR"

    static var isActive: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// Isolated suite while testing, otherwise the ordinary app defaults.
    static let defaults: UserDefaults = makeDefaults()

    static func prepare() {
        _ = defaults
    }

    /// Chosen folders for each role, already checked to be real directories.
    static func folderSeed(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        directoryExists: (String) -> Bool = AppSettings.isFolder
    ) -> [FolderRole: String] {
        guard isActive else { return [:] }
        var seed: [FolderRole: String] = [:]
        let keys: [(FolderRole, String)] = [
            (.source, sourceKey),
            (.output, outputKey),
            (.video, videoKey),
            (.audio, audioKey),
        ]
        for (role, key) in keys {
            if let url = UITestingEnvironment.directory(
                named: key,
                from: environment,
                directoryExists: directoryExists
            ) {
                seed[role] = url.path
            }
        }
        return seed
    }

    private static func makeDefaults() -> UserDefaults {
        guard isActive else { return .standard }
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        guard let store = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the UI testing defaults suite \(suiteName)")
        }
        return store
    }
}
