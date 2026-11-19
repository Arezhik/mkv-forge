import Foundation

/// Reads the tracks of one file. The app uses `MKVMergeIdentifier`; tests use a fake.
public protocol TrackIdentifying: Sendable {
    func identify(_ path: String) async throws -> MediaProbe
}

/// Runs `mkvmerge -J <absolute path>` through `ToolCommand`, which logs the command,
/// exit code, and stderr, and kills the process when the scan is cancelled (L15).
public struct MKVMergeIdentifier: TrackIdentifying {
    public let executable: String

    public init(executable: String) {
        self.executable = executable
    }

    public func identify(_ path: String) async throws -> MediaProbe {
        let result = try await ToolCommand.run(executable: executable, arguments: ["-J", path])
        return IdentificationParser.parse(status: result.status, output: result.standardOutput)
    }
}
