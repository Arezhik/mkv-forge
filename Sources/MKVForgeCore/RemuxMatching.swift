import Foundation

// Remux pairing when Match on MKA Name is on (issue #33, layout contract v2.2).
// Rules:
// - Key K is the .mka file name without its extension. Video stem V matches when V
//   starts with K, case-insensitive, including V == K. No delimiter and no fuzzy step.
// - One .mkv for a .mka and one .mka for that .mkv is a Ready pair. The row name and the
//   output file are V (`<V>.mkv`).
// - Two or more matches on either side: every file still in that group is an Issue row,
//   `Ambiguous match`, and nothing is picked automatically.
// - A pick locks one pair (Ready, `Matched by you`) and the rest are scored again.
// - Picks belong to one scan. A new scan, a folder change or a setting change drops them.
// - Typos, punctuation and spacing differences do not match (Open Questions 2–5). A close
//   name is an ordinary no-match Issue, never a Ready pair.
// - Exact base-name matching (the setting off) does not use this file.

/// One side of a Remux pair the user chose. Paths are the scan's full paths.
public struct RemuxPick: Equatable, Hashable, Sendable, Codable {
    public var audioPath: String
    public var videoPath: String

    public init(audioPath: String, videoPath: String) {
        self.audioPath = audioPath
        self.videoPath = videoPath
    }
}

/// A file the Choose Match menu can pair with the row.
public struct RemuxCandidate: Equatable, Sendable, Identifiable {
    public var id: String { path }
    public var fileName: String
    public var path: String
    public var stem: String

    public init(fileName: String, path: String, stem: String) {
        self.fileName = fileName
        self.path = path
        self.stem = stem
    }
}

/// Which folder an ambiguous row came from. The menu lists the other side.
public enum RemuxSide: Equatable, Sendable {
    case audio
    case video
}

/// The Choose Match menu for one ambiguous row. Never has a selected item.
public struct RemuxMatchMenu: Equatable, Sendable {
    public var fileName: String
    public var side: RemuxSide
    /// This row's candidates only, sorted like the queue.
    public var candidates: [RemuxCandidate]

    public init(fileName: String, side: RemuxSide, candidates: [RemuxCandidate]) {
        self.fileName = fileName
        self.side = side
        self.candidates = candidates
    }

    /// `Pair X.mka with`.
    public var sectionTitle: String { "Pair \(fileName) with" }

    /// `X.mka, Issue, Ambiguous match, 2 possible matches`.
    public var rowAccessibilityLabel: String {
        let noun = candidates.count == 1 ? "match" : "matches"
        return "\(fileName), Issue, Ambiguous match, \(candidates.count) possible \(noun)"
    }
}

/// One top-level Remux file, or one duplicate-name group, after the cheap checks.
public struct RemuxListedFile: Equatable, Sendable {
    public var name: String
    public var path: String
    public var stem: String
    public var role: FolderRole
    /// Empty, unreadable or still changing. Duplicate groups leave this empty.
    public var cheapIssues: [ScanIssue]
    /// Set when this stem has more than one file in the folder. Not prefix-matched.
    public var duplicateFileNames: [String]?
    /// Filled after `mkvmerge -J`. Nil when the file was not probed.
    public var probe: MediaProbe?

    public init(name: String, path: String, stem: String, role: FolderRole, cheapIssues: [ScanIssue], duplicateFileNames: [String]? = nil, probe: MediaProbe? = nil) {
        self.name = name
        self.path = path
        self.stem = stem
        self.role = role
        self.cheapIssues = cheapIssues
        self.duplicateFileNames = duplicateFileNames
        self.probe = probe
    }
}

/// Everything a Remux scan needs to rebuild rows after a pick, without reading the disk again.
public struct RemuxInventory: Equatable, Sendable {
    public var videos: [RemuxListedFile]
    public var audios: [RemuxListedFile]
    public var outputFolder: String
    public var outputIsVideoFolder: Bool
    /// `<stem>.mkv` names that were already in the Output folder at scan time.
    public var existingOutputNames: Set<String>

    public init(videos: [RemuxListedFile], audios: [RemuxListedFile], outputFolder: String, outputIsVideoFolder: Bool, existingOutputNames: Set<String>) {
        self.videos = videos
        self.audios = audios
        self.outputFolder = outputFolder
        self.outputIsVideoFolder = outputIsVideoFolder
        self.existingOutputNames = existingOutputNames
    }

    public func withProbes(_ probes: [String: MediaProbe]) -> RemuxInventory {
        var copy = self
        copy.videos = videos.map { file in
            var file = file
            if let probe = probes[file.path] { file.probe = probe }
            return file
        }
        copy.audios = audios.map { file in
            var file = file
            if let probe = probes[file.path] { file.probe = probe }
            return file
        }
        return copy
    }
}

/// Strings for the Match on MKA Name switch and the ambiguous-match rows (v2.2 §A, §B).
public enum MatchOnMKAName {
    public static let label = "Match on MKA Name"
    public static let helpLine1 = "Pairs each .mka with the video file whose name starts with the .mka name. The finished file keeps the full video name."
    public static let helpLine2 = "Changing this clears the Remux queue. Scan again afterward."
    public static let disabledHelp = "Available when Remux isn't running."
    public static let clearedAnnouncement = "Remux queue cleared. Scan again."
    public static let chooseMatchHint = "Lists the files this one could pair with."

    public static func pairedAnnouncement(audioFileName: String, videoFileName: String) -> String {
        "Paired \(audioFileName) with \(videoFileName)."
    }

    /// VoiceOver: `Choose match for X.mka`. The button title stays `Choose Match`.
    public static func chooseMatchLabel(fileName: String) -> String {
        "Choose match for \(fileName)"
    }

    /// `Unmatch X Extended from X.mka`.
    public static func unmatchLabel(videoName: String, audioFileName: String) -> String {
        "Unmatch \(videoName) from \(audioFileName)"
    }
}

/// The Settings switch stays off while this mode is scanning or running a batch (v2.2 §A.3).
public enum RemuxMatchLock {
    public static func isLocked(activity: Activity, workingMode: ScanMode?) -> Bool {
        activity.isBusy && workingMode == .remux
    }
}

/// Prefix pairing, ambiguity and pick resolution. No I/O.
public enum RemuxMatcher {
    /// True when `videoStem` starts with `key`, ignoring case. `Alien` matches `Aliens`.
    /// `Alien (1979)` does not match `Aliens (1979)`. Nothing is normalized.
    public static func videoStem(_ videoStem: String, hasPrefixKey key: String) -> Bool {
        guard !key.isEmpty else { return false }
        return videoStem.range(of: key, options: [.anchored, .caseInsensitive]) != nil
    }

    /// Rows for this inventory and these picks. Picks that no longer match an edge are dropped.
    public static func items(inventory: RemuxInventory, picks: [RemuxPick]) -> (items: [ScanItem], picks: [RemuxPick]) {
        let plan = plan(inventory, picks: picks)
        return (plan.items, plan.appliedPicks)
    }

    /// Files a scan should identify: both sides of a one-to-one pair, and every ambiguous
    /// file, skipping any file the cheap checks already rejected. Unmatched files and
    /// duplicate-name groups are not read.
    public static func probePaths(inventory: RemuxInventory) -> [String] {
        let plan = plan(inventory, picks: [])
        var paths: [String] = []
        for pair in plan.pairs where pair.video.cheapIssues.isEmpty { paths.append(pair.video.path) }
        for pair in plan.pairs where pair.audio.cheapIssues.isEmpty { paths.append(pair.audio.path) }
        for row in plan.ambiguous where row.file.cheapIssues.isEmpty { paths.append(row.file.path) }
        return paths
    }

    // MARK: Planning

    private struct Pairing {
        var video: RemuxListedFile
        var audio: RemuxListedFile
        var byYou: Bool
    }

    private struct Ambiguous {
        var file: RemuxListedFile
        var candidates: [RemuxListedFile]
    }

    private struct Plan {
        var items: [ScanItem]
        var appliedPicks: [RemuxPick]
        var pairs: [Pairing]
        var ambiguous: [Ambiguous]
    }

    private static func plan(_ inventory: RemuxInventory, picks: [RemuxPick]) -> Plan {
        var items: [ScanItem] = []
        var consumedVideo: Set<String> = []
        var consumedAudio: Set<String> = []

        for video in inventory.videos where video.duplicateFileNames != nil {
            let audio = inventory.audios.first { $0.stem == video.stem && !consumedAudio.contains($0.path) }
            items.append(duplicateItem(video: video, audio: audio, inventory: inventory))
            consumedVideo.insert(video.path)
            if let audio { consumedAudio.insert(audio.path) }
        }
        for audio in inventory.audios where audio.duplicateFileNames != nil && !consumedAudio.contains(audio.path) {
            let video = inventory.videos.first { $0.stem == audio.stem && !consumedVideo.contains($0.path) && $0.duplicateFileNames == nil }
            items.append(duplicateItem(video: video, audio: audio, inventory: inventory))
            consumedAudio.insert(audio.path)
            if let video { consumedVideo.insert(video.path) }
        }

        let poolV = inventory.videos.filter { $0.duplicateFileNames == nil && !consumedVideo.contains($0.path) }
        let poolA = inventory.audios.filter { $0.duplicateFileNames == nil && !consumedAudio.contains($0.path) }
        let audioByPath = Dictionary(uniqueKeysWithValues: poolA.map { ($0.path, $0) })
        let videoByPath = Dictionary(uniqueKeysWithValues: poolV.map { ($0.path, $0) })

        var audioToVideos: [String: [RemuxListedFile]] = [:]
        var videoToAudios: [String: [RemuxListedFile]] = [:]
        for audio in poolA {
            audioToVideos[audio.path] = poolV
                .filter { videoStem($0.stem, hasPrefixKey: audio.stem) }
                .sorted { ScanResult.nameOrder($0.name, $1.name) }
        }
        for video in poolV {
            videoToAudios[video.path] = poolA
                .filter { videoStem(video.stem, hasPrefixKey: $0.stem) }
                .sorted { ScanResult.nameOrder($0.name, $1.name) }
        }

        var goneAudio: Set<String> = []
        var goneVideo: Set<String> = []
        var locked: [Pairing] = []
        var applied: [RemuxPick] = []
        for pick in picks {
            if goneAudio.contains(pick.audioPath) || goneVideo.contains(pick.videoPath) { continue }
            guard let audio = audioByPath[pick.audioPath], let video = videoByPath[pick.videoPath] else { continue }
            guard audioToVideos[audio.path]?.contains(where: { $0.path == video.path }) == true else { continue }
            locked.append(Pairing(video: video, audio: audio, byYou: true))
            applied.append(pick)
            goneAudio.insert(audio.path)
            goneVideo.insert(video.path)
        }
        for path in audioToVideos.keys {
            audioToVideos[path]?.removeAll { goneVideo.contains($0.path) }
        }
        for path in videoToAudios.keys {
            videoToAudios[path]?.removeAll { goneAudio.contains($0.path) }
        }

        var usedAudio: Set<String> = []
        var usedVideo: Set<String> = []
        var automatic: [Pairing] = []
        for audio in poolA where !goneAudio.contains(audio.path) {
            let videos = audioToVideos[audio.path] ?? []
            guard videos.count == 1, let video = videos.first else { continue }
            let audios = videoToAudios[video.path] ?? []
            guard audios.count == 1, audios[0].path == audio.path else { continue }
            automatic.append(Pairing(video: video, audio: audio, byYou: false))
            usedAudio.insert(audio.path)
            usedVideo.insert(video.path)
        }

        var ambiguous: [Ambiguous] = []
        for audio in poolA where !goneAudio.contains(audio.path) && !usedAudio.contains(audio.path) {
            let videos = audioToVideos[audio.path] ?? []
            if videos.isEmpty {
                items.append(unmatched(audio, missing: .noMatchingMKV, inventory: inventory))
            } else {
                ambiguous.append(Ambiguous(file: audio, candidates: videos))
                items.append(ambiguousItem(audio, candidates: videos))
            }
        }
        for video in poolV where !goneVideo.contains(video.path) && !usedVideo.contains(video.path) {
            let audios = videoToAudios[video.path] ?? []
            if audios.isEmpty {
                items.append(unmatched(video, missing: .noMatchingMKA, inventory: inventory))
            } else {
                ambiguous.append(Ambiguous(file: video, candidates: audios))
                items.append(ambiguousItem(video, candidates: audios))
            }
        }

        let pairs = locked + automatic
        for pair in pairs {
            items.append(pairItem(pair, inventory: inventory))
        }
        return Plan(items: items, appliedPicks: applied, pairs: pairs, ambiguous: ambiguous)
    }

    // MARK: Rows

    private static func pairItem(_ pair: Pairing, inventory: RemuxInventory) -> ScanItem {
        let video = pair.video
        let audio = pair.audio
        var issues = video.cheapIssues + audio.cheapIssues
        var notes: [ScanNote] = []
        let videoRead = read(video, role: .video)
        let audioRead = read(audio, role: .audio)
        issues += videoRead.issues + audioRead.issues
        if let note = videoRead.note { notes.append(note) }

        let outputName = video.stem + ".mkv"
        if inventory.outputIsVideoFolder {
            issues.append(.outputIsVideoFolder)
        } else if inventory.existingOutputNames.contains(outputName) {
            issues.append(.outputAlreadyExists(fileName: outputName))
        }
        if pair.byYou && issues.isEmpty {
            notes.insert(.matchedByYou(videoFileName: video.name, audioFileName: audio.name), at: 0)
        }
        return ScanItem(
            baseName: video.stem,
            sourcePath: video.path,
            mkaPath: audio.path,
            outputPath: join(inventory.outputFolder, outputName),
            sourceInfo: videoRead.info,
            mkaInfo: audioRead.info,
            issues: issues,
            notes: notes,
            rowID: video.stem
        )
    }

    private static func ambiguousItem(_ file: RemuxListedFile, candidates: [RemuxListedFile]) -> ScanItem {
        let otherIsVideo = file.role == .audio
        let menu = RemuxMatchMenu(
            fileName: file.name,
            side: otherIsVideo ? .audio : .video,
            candidates: candidates.map { RemuxCandidate(fileName: $0.name, path: $0.path, stem: $0.stem) }
        )
        return ScanItem(
            baseName: file.name,
            sourcePath: file.role == .video ? file.path : nil,
            mkaPath: file.role == .audio ? file.path : nil,
            outputPath: join("", file.name),
            issues: [.ambiguousMatch(fileName: file.name, otherCount: candidates.count, otherIsVideo: otherIsVideo)],
            rowID: file.path,
            matchMenu: menu
        )
    }

    private static func unmatched(_ file: RemuxListedFile, missing: ScanIssue, inventory: RemuxInventory) -> ScanItem {
        var issues = file.cheapIssues
        issues.append(missing)
        let outputName = file.stem + ".mkv"
        if inventory.outputIsVideoFolder {
            issues.append(.outputIsVideoFolder)
        } else if inventory.existingOutputNames.contains(outputName) {
            issues.append(.outputExists(fileName: outputName))
        }
        return ScanItem(
            baseName: file.stem,
            sourcePath: file.role == .video ? file.path : nil,
            mkaPath: file.role == .audio ? file.path : nil,
            outputPath: join(inventory.outputFolder, outputName),
            issues: issues,
            rowID: file.stem
        )
    }

    private static func duplicateItem(video: RemuxListedFile?, audio: RemuxListedFile?, inventory: RemuxInventory) -> ScanItem {
        let stem = video?.stem ?? audio?.stem ?? ""
        var issues: [ScanIssue] = []
        if let names = video?.duplicateFileNames {
            issues.append(.duplicateName(.video, fileNames: names))
        }
        if let names = audio?.duplicateFileNames {
            issues.append(.duplicateName(.audio, fileNames: names))
        }
        if video == nil { issues.append(.noMatchingMKV) }
        if audio == nil { issues.append(.noMatchingMKA) }
        if let video, video.duplicateFileNames == nil { issues += video.cheapIssues }
        if let audio, audio.duplicateFileNames == nil { issues += audio.cheapIssues }
        let outputName = stem + ".mkv"
        if inventory.outputIsVideoFolder {
            issues.append(.outputIsVideoFolder)
        } else if inventory.existingOutputNames.contains(outputName) {
            issues.append(.outputExists(fileName: outputName))
        }
        return ScanItem(
            baseName: stem,
            sourcePath: video?.path,
            mkaPath: audio?.path,
            outputPath: join(inventory.outputFolder, outputName),
            issues: issues,
            rowID: stem
        )
    }

    /// Track checks for one probed file. Cheap issues are added by the caller. A file that
    /// should have been probed and wasn't is unreadable, so a pair is never Ready with no tracks.
    private static func read(_ file: RemuxListedFile, role: FolderRole) -> (issues: [ScanIssue], info: MediaInfo?, note: ScanNote?) {
        if file.cheapIssues.contains(where: FolderScanner.blocksProbe) { return ([], nil, nil) }
        guard let probe = file.probe else {
            return ([.unreadable(role, fileName: file.name, detail: nil)], nil, nil)
        }
        switch probe {
        case let .unreadable(detail):
            return ([.unreadable(role, fileName: file.name, detail: detail)], nil, nil)
        case let .readable(info):
            var issues = FolderScanner.containerIssues(info, role: role, fileName: file.name)
            var note: ScanNote?
            if info.isMatroska && !info.tracks.isEmpty {
                if role == .video {
                    if info.count(of: .video) == 0 { issues.append(.noVideoTrack(fileName: file.name)) }
                    let extraAudio = info.count(of: .audio)
                    let extraSubtitles = info.count(of: .subtitles)
                    if extraAudio + extraSubtitles > 0 {
                        note = .videoOnly(fileName: file.name, audio: extraAudio, subtitles: extraSubtitles)
                    }
                } else if info.count(of: .audio) + info.count(of: .subtitles) == 0 {
                    issues.append(.mkaHasNoAudioOrSubtitles(fileName: file.name))
                }
            }
            return (issues, info, note)
        }
    }

    private static func join(_ folder: String, _ name: String) -> String {
        (folder as NSString).appendingPathComponent(name)
    }
}
