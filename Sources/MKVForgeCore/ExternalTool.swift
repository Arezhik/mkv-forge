import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// External command-line tool locator and runner (docs/LESSONS.md L15). Rules:
// - Search order: /opt/homebrew/bin (Apple silicon Homebrew), /usr/local/bin (Intel
//   Homebrew), /Applications/<Prefix>*.app/Contents/MacOS, then PATH. An app launched
//   from Finder gets a short PATH, so the fixed folders must come first.
// - Every executable in the spec must be found. A partial install counts as missing.
// - Each run logs the command, the exit code, and stderr (flattened, cut at 2,000
//   characters). Standard output stays out of the log. A past tool failure on an
//   Intel Mac (exit 4, empty stderr) was found from exactly these lines.
// - Cancelling the calling Task kills the process with SIGKILL. terminate() alone was
//   not enough on Linux when called off the launching thread.
// - The version is recorded at launch and in the exported debug log header.
// - Every run gets LC_ALL set to a UTF-8 locale (`ToolEnvironment`). Under the C or
//   POSIX locale, which an app opened from Finder and the swift Docker image both get,
//   mkvmerge cuts file names at the first non-ASCII byte and still exits 0.

/// What to look for. Edit `ExternalToolSpec.primary` for this app.
public struct ExternalToolSpec: Equatable, Sendable {
    /// Display name, such as "mkvmerge".
    public var name: String
    /// Every executable the app needs. All must be found.
    public var executables: [String]
    /// App bundles in /Applications whose names start with this, such as "MKVToolNix".
    public var appBundlePrefix: String?
    /// Arguments that print a version on the first line, such as ["--version"] or ["-version"].
    public var versionArguments: [String]

    public init(name: String, executables: [String], appBundlePrefix: String? = nil, versionArguments: [String] = ["--version"]) {
        self.name = name
        self.executables = executables
        self.appBundlePrefix = appBundlePrefix
        self.versionArguments = versionArguments
    }

    public static let primary = ExternalToolSpec(
        name: "mkvmerge",
        executables: ["mkvmerge"],
        appBundlePrefix: "MKVToolNix",
        versionArguments: ["--version"]
    )
}

/// Executable name to full path, for every executable in the spec.
public struct ExternalToolPaths: Equatable, Sendable {
    public var paths: [String: String]

    public init(paths: [String: String]) {
        self.paths = paths
    }

    public subscript(_ executable: String) -> String? { paths[executable] }
}

public enum ToolFailure: Error, Equatable, LocalizedError {
    case notInstalled(String)
    case couldNotStart(String)
    case failed(tool: String, status: Int32)

    public var errorDescription: String? {
        switch self {
        case let .notInstalled(name):
            return "\(name) is not installed. Install it with Homebrew or from its website, then try again."
        case let .couldNotStart(name):
            return "\(name) could not be started."
        case let .failed(tool, status):
            return "\(tool) stopped with exit code \(status). Export the debug log for details."
        }
    }
}

public enum ExternalTool {
    /// The fixed folders searched first, in order (Apple silicon Homebrew, then Intel Homebrew).
    public static let fixedFolders = ["/opt/homebrew/bin", "/usr/local/bin"]

    /// The search order as people read it in Settings (layout contract v2 §8; replaces the
    /// illustrative list of assumption A8). Same order `locate` uses.
    public static func searchLocations(_ spec: ExternalToolSpec = .primary) -> [String] {
        var places = fixedFolders
        if let prefix = spec.appBundlePrefix, !prefix.isEmpty {
            places.append("/Applications/\(prefix)*.app/Contents/MacOS")
        }
        places.append("PATH")
        return places
    }

    /// `Looked in /opt/homebrew/bin, /usr/local/bin, /Applications/MKVToolNix*.app/Contents/MacOS and PATH.`
    public static func searchDescription(_ spec: ExternalToolSpec = .primary) -> String {
        let places = searchLocations(spec)
        guard let last = places.last else { return "" }
        let head = places.dropLast().joined(separator: ", ")
        return head.isEmpty ? "Looked in \(last)." : "Looked in \(head) and \(last)."
    }

    public static func locate(_ spec: ExternalToolSpec = .primary) -> ExternalToolPaths? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? []
        return locate(
            spec,
            executableExists: { FileManager.default.isExecutableFile(atPath: $0) },
            applications: names,
            searchPath: ProcessInfo.processInfo.environment["PATH"] ?? ""
        )
    }

    /// `applications` is the names inside `/Applications`, such as `MKVToolNix.app`.
    public static func locate(
        _ spec: ExternalToolSpec,
        executableExists: (String) -> Bool,
        applications: [String],
        searchPath: String
    ) -> ExternalToolPaths? {
        let bundles: [String]
        if let prefix = spec.appBundlePrefix, !prefix.isEmpty {
            bundles = applications.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".app") }.sorted()
        } else {
            bundles = []
        }
        func find(_ name: String) -> String? {
            for folder in fixedFolders {
                let path = "\(folder)/\(name)"
                if executableExists(path) { return path }
            }
            for bundle in bundles {
                let path = "/Applications/\(bundle)/Contents/MacOS/\(name)"
                if executableExists(path) { return path }
            }
            for directory in searchPath.split(separator: ":", omittingEmptySubsequences: true) {
                let path = (String(directory) as NSString).appendingPathComponent(name)
                if executableExists(path) { return path }
            }
            return nil
        }
        var found: [String: String] = [:]
        for executable in spec.executables {
            guard let path = find(executable) else { return nil }
            found[executable] = path
        }
        return found.isEmpty ? nil : ExternalToolPaths(paths: found)
    }

    /// The copy the user chose in Settings, when there is one. `chosen` may be the
    /// executable itself, an app bundle such as `MKVToolNix-103.app`, or the folder that
    /// holds the executables. A chosen copy that can't be found is not found: there's no
    /// silent fallback to the default search (AGENTS.md, L15). With no choice, this is
    /// the default search.
    public static func locate(_ spec: ExternalToolSpec = .primary, chosen: String?) -> ExternalToolPaths? {
        guard let chosen, !chosen.isEmpty else { return locate(spec) }
        return locate(spec, chosen: chosen, executableExists: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    public static func locate(_ spec: ExternalToolSpec, chosen: String, executableExists: (String) -> Bool) -> ExternalToolPaths? {
        let trimmed = chosen.hasSuffix("/") && chosen.count > 1 ? String(chosen.dropLast()) : chosen
        let folder: String
        if spec.executables.contains((trimmed as NSString).lastPathComponent) {
            // The executable itself; the others live next to it.
            folder = (trimmed as NSString).deletingLastPathComponent
        } else if trimmed.hasSuffix(".app") {
            folder = trimmed + "/Contents/MacOS"
        } else {
            folder = trimmed
        }
        var found: [String: String] = [:]
        for executable in spec.executables {
            let path = (folder as NSString).appendingPathComponent(executable)
            guard executableExists(path) else { return nil }
            found[executable] = path
        }
        return found.isEmpty ? nil : ExternalToolPaths(paths: found)
    }

    /// The first line the tool prints for its version arguments.
    public static func version(of executable: String, arguments: [String] = ExternalToolSpec.primary.versionArguments) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ToolEnvironment.forTools()
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line, !line.isEmpty else { return nil }
        return line
    }
}

/// The environment every tool run gets: the app's own, with `LC_ALL` forced to a UTF-8
/// locale that exists on this platform. mkvmerge converts arguments and file names with
/// the locale's character set. Under C or POSIX it silently cuts "Show [é].mkv" to
/// "Show [", and an LC_* value naming a locale that isn't installed makes it abort. macOS
/// has no C.UTF-8 and minimal Linux images have no en_US.UTF-8, hence one name each.
public enum ToolEnvironment {
    #if canImport(Darwin)
    public static let utf8Locale = "en_US.UTF-8"
    #else
    public static let utf8Locale = "C.UTF-8"
    #endif

    public static func forTools(inheriting inherited: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = inherited
        environment["LC_ALL"] = utf8Locale
        return environment
    }
}

/// One run of an external command.
public struct ToolCommandResult: Equatable, Sendable {
    public var status: Int32
    public var standardOutput: Data
    public var standardError: Data

    public init(status: Int32, standardOutput: Data, standardError: Data) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum ToolCommand {
    /// Runs the tool off the main thread. Cancelling the calling task kills the process.
    /// `onStdoutLine` is each complete stdout line, split on `\n` and `\r`, as the bytes
    /// arrive. The returned buffer is still the full stdout.
    public static func run(
        executable: String,
        arguments: [String],
        onStdoutLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ToolCommandResult {
        let runner = CommandRunner()
        return try await withTaskCancellationHandler {
            try await runner.start(executable: executable, arguments: arguments, onStdoutLine: onStdoutLine)
        } onCancel: {
            runner.cancel()
        }
    }
}

/// Owns the running `Process` so a cancel from another task can terminate it.
private final class CommandRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let process = self.process
        lock.unlock()
        guard let process else { return }
        stop(process)
    }

    func start(
        executable: String,
        arguments: [String],
        onStdoutLine: (@Sendable (String) -> Void)?
    ) async throws -> ToolCommandResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ToolCommandResult, Error>) in
            let resume = ResumeBox(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try self.blocking(executable: executable, arguments: arguments, onStdoutLine: onStdoutLine) }
                resume.resume(result)
            }
        }
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    /// Stores the process. Returns false when cancel already won.
    private func adopt(_ process: Process) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if cancelled { return false }
        self.process = process
        return true
    }

    /// `terminate()` is not enough on Linux when it is called off the thread that
    /// launched the tool. SIGKILL makes Cancel stop the tool immediately.
    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        if pid > 0 {
            kill(pid, SIGKILL)
        }
    }

    private func forget() {
        lock.lock()
        process = nil
        lock.unlock()
    }

    private func blocking(
        executable: String,
        arguments: [String],
        onStdoutLine: (@Sendable (String) -> Void)?
    ) throws -> ToolCommandResult {
        let command = ToolCommandFormatting.line(executable: executable, arguments: arguments)
        if isCancelled {
            ToolCommandFormatting.logCancelled(command)
            throw CancellationError()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ToolEnvironment.forTools()
        process.standardInput = FileHandle.nullDevice
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        guard adopt(process) else {
            ToolCommandFormatting.logCancelled(command)
            throw CancellationError()
        }
        DebugLog.shared.record(.tool, "command \(command)")
        do {
            try process.run()
        } catch {
            forget()
            DebugLog.shared.record(.error, "command \(command) could not start", isError: true)
            throw ToolFailure.couldNotStart((executable as NSString).lastPathComponent)
        }
        if isCancelled {
            stop(process)
        }
        let stdout = PipeReader(stdoutPipe.fileHandleForReading)
        let stderr = PipeReader(stderrPipe.fileHandleForReading)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdout.readToEnd(onLine: onStdoutLine)
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderr.readToEnd()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()
        let status = process.terminationStatus
        forget()
        let failed = status != 0
        DebugLog.shared.record(.tool, "exit \(status)", isError: failed)
        if let stderrText = ToolCommandFormatting.stderrText(stderr.data) {
            DebugLog.shared.record(.tool, "stderr \(stderrText)", isError: failed)
        } else if failed {
            DebugLog.shared.record(.tool, "stderr was empty", isError: true)
        }
        if isCancelled {
            ToolCommandFormatting.logCancelled(command)
            throw CancellationError()
        }
        return ToolCommandResult(status: status, standardOutput: stdout.data, standardError: stderr.data)
    }
}

/// How a tool invocation is written into the debug log. Standard output stays out.
enum ToolCommandFormatting {
    static func line(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).map { part in
            if part.contains(where: { $0 == " " || $0 == "\"" }) {
                return "\"\(part.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return part
        }.joined(separator: " ")
    }

    static func stderrText(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let raw = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let flat = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        let trimmed = flat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let limit = 2000
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

    static func logCancelled(_ command: String) {
        DebugLog.shared.record(.tool, "command cancelled \(command)")
    }
}

/// Splits stdout chunks on `\n` and `\r` (`\r\n` is one break). A trailing `\r` is held
/// until the next byte, so a split `\r\n` does not become an empty line.
struct StdoutLineSplitter {
    private var pending = Data()

    mutating func append(_ chunk: Data) -> [String] {
        guard !chunk.isEmpty else { return [] }
        pending.append(chunk)
        return pull(flush: false)
    }

    mutating func finish() -> [String] {
        pull(flush: true)
    }

    private mutating func pull(flush: Bool) -> [String] {
        var lines: [String] = []
        var cursor = pending.startIndex
        var lineStart = pending.startIndex
        while cursor < pending.endIndex {
            let byte = pending[cursor]
            let isCR = byte == 13
            let isLF = byte == 10
            if !isCR && !isLF {
                cursor = pending.index(after: cursor)
                continue
            }
            if lineStart < cursor {
                lines.append(Self.decode(pending.subdata(in: lineStart..<cursor)))
            }
            let after = pending.index(after: cursor)
            if isCR, after == pending.endIndex, !flush {
                pending.removeSubrange(..<cursor)
                return lines
            }
            if isCR, after < pending.endIndex, pending[after] == 10 {
                cursor = pending.index(after: after)
            } else {
                cursor = after
            }
            lineStart = cursor
        }
        pending.removeSubrange(..<lineStart)
        if flush, !pending.isEmpty {
            lines.append(Self.decode(pending))
            pending.removeAll()
        }
        return lines
    }

    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

/// What one read of a pipe returned. `.end` is a real EOF (zero bytes).
/// `.failed` is not EOF: the next `.bytes` must still be delivered.
enum PipePull: Equatable {
    case bytes(Data)
    case end
    /// `EINTR` or `EAGAIN`. Not EOF, and not a failed read.
    case interrupted
    case failed(Int32)
}

/// Assembles pipe chunks into the full buffer and into lines.
/// A `.failed` pull does not end the stream. The reader stops on `.end`, or after
/// `failureLimit` failures in a row so a dead descriptor cannot hang the batch.
struct PipeAssembler {
    static let failureLimit = 8

    private var splitter = StdoutLineSplitter()
    private var consecutiveFailures = 0
    private(set) var data = Data()

    /// True when the reader should keep going. False on EOF or the failure limit.
    mutating func take(_ pull: PipePull, onLine: ((String) -> Void)?) -> Bool {
        switch pull {
        case .interrupted:
            return true
        case .end:
            finish(onLine)
            return false
        case let .failed(code):
            consecutiveFailures += 1
            DebugLog.shared.record(.error, "Reading the tool pipe failed (errno \(code))", isError: true)
            if consecutiveFailures >= Self.failureLimit {
                finish(onLine)
                return false
            }
            return true
        case let .bytes(chunk):
            consecutiveFailures = 0
            guard !chunk.isEmpty else { return true }
            data.append(chunk)
            guard let onLine else { return true }
            for line in splitter.append(chunk) {
                onLine(line)
            }
            return true
        }
    }

    private mutating func finish(_ onLine: ((String) -> Void)?) {
        guard let onLine else { return }
        for line in splitter.finish() {
            onLine(line)
        }
    }
}

/// One `read` of whatever is already in the pipe. `FileHandle.read(upToCount:)` is not
/// used: on Darwin it can block until `count` bytes or EOF, so a short `#GUI#progress`
/// stream would arrive only when mkvmerge exits. `poll` plus one `read` returns the
/// bytes already available, which is the same rule as `readabilityHandler` /
/// `availableData`. A zero-length read is EOF. A negative read is not.
private enum PipeFile {
    static func preferShortReads(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0 else { return }
        _ = fcntl(fd, F_SETFL, flags | Int32(O_NONBLOCK))
    }

    static func pull(_ fd: Int32) -> PipePull {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, nfds_t(1), -1)
        if ready < 0 {
            if errno == EINTR { return .interrupted }
            return .failed(errno)
        }
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = buffer.withUnsafeMutableBytes { raw -> Int in
            guard let base = raw.baseAddress else { return -1 }
            #if canImport(Darwin)
            return Darwin.read(fd, base, raw.count)
            #elseif canImport(Glibc)
            return Int(Glibc.read(fd, base, raw.count))
            #elseif canImport(Musl)
            return Int(Musl.read(fd, base, raw.count))
            #else
            return -1
            #endif
        }
        if count > 0 { return .bytes(Data(buffer.prefix(count))) }
        if count == 0 { return .end }
        let code = errno
        if code == EINTR || code == EAGAIN || code == EWOULDBLOCK { return .interrupted }
        return .failed(code)
    }
}

/// Reads a pipe on a background thread. `Pipe` and `FileHandle` are not sendable, so they stay in here.
private final class PipeReader: @unchecked Sendable {
    private let handle: FileHandle
    private(set) var data = Data()

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    /// Reads until a real EOF. The stored bytes are the whole stream. `onLine` sees each
    /// complete line as the chunks arrive; stderr is a different reader. A failed read
    /// does not end the stream.
    func readToEnd(onLine: (@Sendable (String) -> Void)? = nil) {
        let fd = handle.fileDescriptor
        PipeFile.preferShortReads(fd)
        var assembler = PipeAssembler()
        while assembler.take(PipeFile.pull(fd), onLine: onLine) {}
        data = assembler.data
    }
}

/// Resumes a continuation once. The process thread and a failure path must not both resume it.
private final class ResumeBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
