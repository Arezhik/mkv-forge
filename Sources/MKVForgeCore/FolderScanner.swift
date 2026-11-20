import Foundation

// Folder scans (docs/scaffold.md, Split, Remux, Validation / Scan Rules). Rules:
// - Top level only. Hidden and `._` files, subfolders, and other extensions are skipped.
// - Exact base-name matching. Remux rows are the union of the Video and Audio folders.
// - Cheap file checks run first (duplicate, orphan, empty, unreadable, still changing).
//   A row with any of them isn't identified, so a half-copied file is never read.
// - Then `mkvmerge -J` on the rest, at most `maxConcurrentProbes` at a time (L16), and
//   the track checks. Existing output is checked on every scan and never overwritten.
// - Folder walks and probes run off the main thread; cancelling the scan task stops it.
// - Progress (layout contract v2.1 §2.2): `.listing` first, then `.reading(current:total:)`
//   with total = MKV files (Split) or names (Remux) and current = names finished + 1,
//   capped at total, so it never shows `0 of 9` and shows `9 of 9` while the last file is
//   read. Updates are throttled to about 10 a second (L9); the first and last always go out.

public enum ScanError: Error, Equatable, LocalizedError {
    case folderNotReadable(FolderRole, path: String)

    public var errorDescription: String? {
        switch self {
        case let .folderNotReadable(role, path):
            return "The \(role.displayName) folder can't be read: \(path)"
        }
    }
}

public struct FolderScanner: Sendable {
    /// Files modified less than this long before the scan are flagged as still changing.
    public static let stillChangingInterval: TimeInterval = 60

    public var lister: any FolderListing
    public var identifier: any TrackIdentifying
    public var now: @Sendable () -> Date
    public var maxConcurrentProbes: Int
    /// Smallest gap between two progress updates. Tests set 0 to see every update.
    public var progressInterval: TimeInterval = ProgressThrottle.defaultInterval

    public init(lister: any FolderListing = LocalFolderLister(), identifier: any TrackIdentifying, now: @escaping @Sendable () -> Date = { Date() }, maxConcurrentProbes: Int = 4) {
        self.lister = lister
        self.identifier = identifier
        self.now = now
        self.maxConcurrentProbes = max(1, maxConcurrentProbes)
    }

    // MARK: Split

    public func scanSplit(source: String, output: String, progress: (@Sendable (ScanProgress) -> Void)? = nil) async throws -> ScanResult {
        let scannedAt = now()
        DebugLog.shared.record(.queue, "Scan Split started")
        var reporter = ScanProgressReporter(report: progress, interval: progressInterval)
        reporter.listing()
        let groups = ScanFilter.byBaseName(ScanFilter.candidates(try list(source, .source), fileExtension: "mkv"))
        try Task.checkCancellation()

        var items: [String: ScanItem] = [:]
        var toProbe: [String: String] = [:]
        for (name, files) in groups {
            let file = files[0]
            let path = Self.join(source, file.name)
            var issues: [ScanIssue] = []
            if files.count > 1 {
                issues.append(.duplicateName(.source, fileNames: files.map(\.name)))
            } else {
                issues += cheapIssues(file, role: .source, scannedAt: scannedAt)
            }
            let outputName = name + ".mka"
            let outputPath = Self.join(output, outputName)
            if lister.fileExists(atPath: outputPath) {
                issues.append(.outputExists(fileName: outputName))
            }
            if files.count == 1 && !issues.contains(where: Self.blocksProbe) {
                toProbe[name] = path
            }
            items[name] = ScanItem(baseName: name, sourcePath: path, outputPath: outputPath, issues: issues)
        }

        reporter.start(total: groups.count, finished: groups.count - toProbe.count)
        let probes = try await probeAll(toProbe) { _ in reporter.finish() }
        for (name, probe) in probes {
            guard var item = items[name] else { continue }
            let fileName = (item.sourcePath.map { ($0 as NSString).lastPathComponent }) ?? name
            var issues = item.issues
            switch probe {
            case let .unreadable(detail):
                issues.append(.unreadable(.source, fileName: fileName, detail: detail))
            case let .readable(info):
                item.sourceInfo = info
                issues += Self.containerIssues(info, role: .source, fileName: fileName)
                if info.isMatroska && !info.tracks.isEmpty {
                    let audio = info.count(of: .audio)
                    let subtitles = info.count(of: .subtitles)
                    if audio == 0 && subtitles == 0 {
                        issues.append(.noAudioOrSubtitles(fileName: fileName))
                    } else if audio == 0 {
                        issues.append(.noAudio(fileName: fileName))
                    } else if subtitles == 0 {
                        issues.append(.noSubtitles(fileName: fileName))
                    }
                }
            }
            items[name] = ScanItem(baseName: name, sourcePath: item.sourcePath, outputPath: item.outputPath, sourceInfo: item.sourceInfo, issues: issues)
        }
        let result = ScanResult(mode: .split, scannedAt: scannedAt, items: Array(items.values))
        DebugLog.shared.record(.queue, "Scan Split finished: \(result.nameCount) files, \(result.flaggedCount) flagged")
        return result
    }

    // MARK: Remux

    public func scanRemux(video: String, audio: String, output: String, progress: (@Sendable (ScanProgress) -> Void)? = nil) async throws -> ScanResult {
        let scannedAt = now()
        DebugLog.shared.record(.queue, "Scan Remux started")
        var reporter = ScanProgressReporter(report: progress, interval: progressInterval)
        reporter.listing()
        let videos = ScanFilter.byBaseName(ScanFilter.candidates(try list(video, .video), fileExtension: "mkv"))
        let mkas = ScanFilter.byBaseName(ScanFilter.candidates(try list(audio, .audio), fileExtension: "mka"))
        try Task.checkCancellation()
        let outputIsVideoFolder = Self.sameFolder(video, output)

        var items: [String: ScanItem] = [:]
        var videoProbes: [String: String] = [:]
        var mkaProbes: [String: String] = [:]
        for name in Set(videos.keys).union(mkas.keys) {
            let videoFiles = videos[name] ?? []
            let mkaFiles = mkas[name] ?? []
            let videoPath = videoFiles.first.map { Self.join(video, $0.name) }
            let mkaPath = mkaFiles.first.map { Self.join(audio, $0.name) }
            var issues: [ScanIssue] = []
            if videoFiles.count > 1 { issues.append(.duplicateName(.video, fileNames: videoFiles.map(\.name))) }
            if mkaFiles.count > 1 { issues.append(.duplicateName(.audio, fileNames: mkaFiles.map(\.name))) }
            if videoFiles.isEmpty { issues.append(.noMatchingMKV) }
            if mkaFiles.isEmpty { issues.append(.noMatchingMKA) }
            if videoFiles.count == 1 { issues += cheapIssues(videoFiles[0], role: .video, scannedAt: scannedAt) }
            if mkaFiles.count == 1 { issues += cheapIssues(mkaFiles[0], role: .audio, scannedAt: scannedAt) }

            let outputName = name + ".mkv"
            let outputPath = Self.join(output, outputName)
            if outputIsVideoFolder {
                issues.append(.outputIsVideoFolder)
            } else if lister.fileExists(atPath: outputPath) {
                issues.append(.outputExists(fileName: outputName))
            }
            if !issues.contains(where: Self.blocksProbe), let videoPath, let mkaPath {
                videoProbes[name] = videoPath
                mkaProbes[name] = mkaPath
            }
            items[name] = ScanItem(baseName: name, sourcePath: videoPath, mkaPath: mkaPath, outputPath: outputPath, issues: issues)
        }

        var keyed: [String: String] = [:]
        for (name, path) in videoProbes { keyed["v:" + name] = path }
        for (name, path) in mkaProbes { keyed["a:" + name] = path }
        // A name is finished when both of its files are read.
        var pending: [String: Int] = [:]
        for name in videoProbes.keys { pending[name] = 2 }
        reporter.start(total: items.count, finished: items.count - videoProbes.count)
        let probes = try await probeAll(keyed) { key in
            let name = String(key.dropFirst(2))
            let left = (pending[name] ?? 1) - 1
            pending[name] = left
            if left == 0 { reporter.finish() }
        }

        for name in videoProbes.keys {
            guard let item = items[name], let videoPath = item.sourcePath, let mkaPath = item.mkaPath else { continue }
            var issues = item.issues
            var videoInfo: MediaInfo?
            var mkaInfo: MediaInfo?
            let videoName = (videoPath as NSString).lastPathComponent
            let mkaName = (mkaPath as NSString).lastPathComponent
            switch probes["v:" + name] {
            case let .unreadable(detail)?:
                issues.append(.unreadable(.video, fileName: videoName, detail: detail))
            case let .readable(info)?:
                videoInfo = info
                issues += Self.containerIssues(info, role: .video, fileName: videoName)
                if info.isMatroska && !info.tracks.isEmpty {
                    if info.count(of: .video) == 0 { issues.append(.noVideoTrack(fileName: videoName)) }
                    let extraAudio = info.count(of: .audio)
                    let extraSubtitles = info.count(of: .subtitles)
                    if extraAudio + extraSubtitles > 0 {
                        issues.append(.extraTracks(fileName: videoName, audio: extraAudio, subtitles: extraSubtitles))
                    }
                }
            case nil:
                break
            }
            switch probes["a:" + name] {
            case let .unreadable(detail)?:
                issues.append(.unreadable(.audio, fileName: mkaName, detail: detail))
            case let .readable(info)?:
                mkaInfo = info
                issues += Self.containerIssues(info, role: .audio, fileName: mkaName)
                if info.isMatroska && !info.tracks.isEmpty && info.count(of: .audio) + info.count(of: .subtitles) == 0 {
                    issues.append(.mkaHasNoAudioOrSubtitles(fileName: mkaName))
                }
            case nil:
                break
            }
            items[name] = ScanItem(baseName: name, sourcePath: videoPath, mkaPath: mkaPath, outputPath: item.outputPath, sourceInfo: videoInfo, mkaInfo: mkaInfo, issues: issues)
        }
        let result = ScanResult(mode: .remux, scannedAt: scannedAt, items: Array(items.values))
        DebugLog.shared.record(.queue, "Scan Remux finished: \(result.nameCount) names, \(result.pairCount) pairs, \(result.flaggedCount) flagged")
        return result
    }

    // MARK: Shared

    private func list(_ folder: String, _ role: FolderRole) throws -> [FileEntry] {
        do {
            return try lister.entries(in: folder)
        } catch {
            DebugLog.shared.record(.error, "Scan: \(role.displayName) folder can't be read", isError: true)
            throw ScanError.folderNotReadable(role, path: folder)
        }
    }

    func cheapIssues(_ file: FileEntry, role: FolderRole, scannedAt: Date) -> [ScanIssue] {
        var issues: [ScanIssue] = []
        if file.size == 0 {
            issues.append(.emptyFile(role, fileName: file.name))
        } else if !file.isReadable {
            issues.append(.unreadable(role, fileName: file.name, detail: "no permission to read it"))
        }
        // A future modification date (a share's clock running ahead) also counts.
        if scannedAt.timeIntervalSince(file.modified) < Self.stillChangingInterval {
            issues.append(.stillChanging(role, fileName: file.name))
        }
        return issues
    }

    /// Issues that mean the file isn't worth identifying: it can't run anyway, or reading
    /// it now could hit a half-copied file. An existing output doesn't block identifying,
    /// so every other problem shows in the same scan.
    static func blocksProbe(_ issue: ScanIssue) -> Bool {
        if case .outputExists = issue { return false }
        if case .outputIsVideoFolder = issue { return false }
        return true
    }

    static func containerIssues(_ info: MediaInfo, role: FolderRole, fileName: String) -> [ScanIssue] {
        if !info.isMatroska { return [.notMatroska(role, fileName: fileName, containerType: info.containerType)] }
        if info.tracks.isEmpty { return [.noTracks(role, fileName: fileName)] }
        return []
    }

    /// Identifies every path, keyed like the input, at most `maxConcurrentProbes` at once.
    private func probeAll(_ paths: [String: String], onResult: (String) -> Void) async throws -> [String: MediaProbe] {
        let identifier = self.identifier
        let work = paths.sorted { $0.key < $1.key }
        var results: [String: MediaProbe] = [:]
        try await withThrowingTaskGroup(of: (String, MediaProbe).self) { group in
            var next = 0
            func addNext() {
                guard next < work.count else { return }
                let (key, path) = work[next]
                next += 1
                group.addTask {
                    try Task.checkCancellation()
                    return (key, try await identifier.identify(path))
                }
            }
            for _ in 0..<min(maxConcurrentProbes, work.count) { addNext() }
            while let (key, probe) = try await group.next() {
                results[key] = probe
                try Task.checkCancellation()
                onResult(key)
                addNext()
            }
        }
        return results
    }

    static func join(_ folder: String, _ name: String) -> String {
        (folder as NSString).appendingPathComponent(name)
    }

    /// True when two folder paths name the same folder (symlinks resolved, `..` and
    /// trailing slashes removed).
    static func sameFolder(_ a: String, _ b: String) -> Bool {
        func normal(_ path: String) -> String {
            URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        }
        return normal(a) == normal(b)
    }
}

/// Where a scan is (layout contract v2.1 §2.2).
public enum ScanProgress: Equatable, Sendable {
    /// Listing the folders; the total isn't known yet.
    case listing
    /// Reading files with `mkvmerge -J`. `current` counts from 1 and never passes `total`.
    case reading(current: Int, total: Int)
}

/// Turns finished-name counts into throttled progress updates. Used from one task only.
struct ScanProgressReporter {
    private let report: (@Sendable (ScanProgress) -> Void)?
    private var throttle: ProgressThrottle
    private var total = 0
    private var finished = 0

    init(report: (@Sendable (ScanProgress) -> Void)?, interval: TimeInterval) {
        self.report = report
        self.throttle = ProgressThrottle(minimumInterval: interval)
    }

    func listing() {
        report?(.listing)
    }

    /// `finished` is the names that need no reading (flagged by the cheap checks).
    mutating func start(total: Int, finished: Int) {
        self.total = total
        self.finished = max(0, min(finished, total))
        publish(force: true)
    }

    mutating func finish() {
        finished = min(finished + 1, total)
        publish(force: finished >= total)
    }

    /// `current` = names finished + 1, capped at the total (Q4).
    static func current(finished: Int, total: Int) -> Int {
        min(finished + 1, total)
    }

    private mutating func publish(force: Bool) {
        guard let report, total > 0 else { return }
        if throttle.shouldPublish(force: force) {
            report(.reading(current: Self.current(finished: finished, total: total), total: total))
        }
    }
}
