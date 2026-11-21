import Foundation
@testable import MKVForgeCore

/// Small builders for the presentation-layer tests.
enum UIFixture {
    static let time = Date(timeIntervalSince1970: 1_800_047_520)

    static func ready(_ name: String, mode: ScanMode = .split) -> ScanItem {
        let ext = mode == .split ? "mka" : "mkv"
        let info = MediaInfo(containerType: "Matroska", tracks: [TrackInfo(id: 0, kind: .audio), TrackInfo(id: 1, kind: .subtitles)])
        return ScanItem(baseName: name, sourcePath: "/s/\(name).mkv", mkaPath: mode == .remux ? "/a/\(name).mka" : nil,
                        outputPath: "/o/\(name).\(ext)", sourceInfo: info, mkaInfo: mode == .remux ? info : nil)
    }

    static func flagged(_ name: String, _ issues: [ScanIssue] = [.noAudio(fileName: "x.mkv")]) -> ScanItem {
        ScanItem(baseName: name, sourcePath: "/s/\(name).mkv", outputPath: "/o/\(name).mka", issues: issues)
    }

    static func scan(_ items: [ScanItem], mode: ScanMode = .split) -> ScanResult {
        ScanResult(mode: mode, scannedAt: time, items: items)
    }

    static func state(_ items: [ScanItem], mode: ScanMode = .split) -> ModeState {
        var state = ModeState(mode: mode)
        for role in ModeState.roles(for: mode) { state.setFolder("/\(role.rawValue)", for: role) }
        state.applyScan(scan(items, mode: mode))
        return state
    }

    static func summary(_ mode: ScanMode = .split, filesInRun: Int, flagged: Int = 0, _ statuses: [JobStatus], stopped: Bool = false) -> BatchSummary {
        var summary = BatchSummary(mode: mode, filesInRun: filesInRun, flagged: flagged)
        for status in statuses { summary.record(status) }
        summary.stopped = stopped
        return summary
    }
}
