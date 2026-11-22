import XCTest
@testable import MKVForgeCore

final class AppSettingsTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "mkvforge-tests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaults() {
        let (settings, dropped) = AppSettings.load(from: defaults, folderExists: { _ in true })
        XCTAssertEqual(settings, AppSettings())
        XCTAssertEqual(settings.activeMode, .split)
        XCTAssertTrue(settings.notifyWhenFinished && settings.bounceWhenFinished)
        XCTAssertNil(settings.chosenToolPath)
        XCTAssertTrue(dropped.isEmpty)
    }

    func testSaveAndLoadRoundTrip() {
        var settings = AppSettings()
        settings.activeMode = .remux
        settings.setFolder("/s", .split, .source)
        settings.setFolder("/v", .remux, .video)
        settings.setFolder("/a", .remux, .audio)
        settings.setFolder("/o", .remux, .output)
        settings.chosenToolPath = "/opt/mkvmerge"
        settings.notifyWhenFinished = false
        settings.save(to: defaults)
        let (loaded, dropped) = AppSettings.load(from: defaults, folderExists: { _ in true })
        XCTAssertEqual(loaded, settings)
        XCTAssertTrue(dropped.isEmpty)
        XCTAssertEqual(defaults.string(forKey: "folder.remux.video"), "/v")
        XCTAssertEqual(defaults.string(forKey: "mkvmergePath"), "/opt/mkvmerge")
    }

    func testClearingRemovesKeys() {
        var settings = AppSettings()
        settings.setFolder("/s", .split, .source)
        settings.chosenToolPath = "/x"
        settings.save(to: defaults)
        settings.setFolder(nil, .split, .source)
        settings.chosenToolPath = nil
        settings.save(to: defaults)
        XCTAssertNil(defaults.object(forKey: AppSettings.Key.folder(.split, .source)))
        XCTAssertNil(defaults.object(forKey: AppSettings.Key.chosenToolPath))
    }

    /// Q7: a remembered folder that's gone is shown as not chosen, and logged.
    func testMissingRememberedFolderIsNotChosen() throws {
        let logs = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-log-\(UUID().uuidString)")
        DebugLog.shared.configure(directory: logs)
        defer {
            DebugLog.shared.reset()
            try? FileManager.default.removeItem(at: logs)
        }
        defaults.set("/gone", forKey: AppSettings.Key.folder(.split, .source))
        defaults.set("/here", forKey: AppSettings.Key.folder(.split, .output))
        let (settings, dropped) = AppSettings.load(from: defaults, folderExists: { $0 == "/here" })
        XCTAssertNil(settings.folder(.split, .source))
        XCTAssertEqual(settings.folder(.split, .output), "/here")
        XCTAssertEqual(dropped, ["Split Source"])
        XCTAssertTrue(DebugLog.shared.recentText().contains("Remembered Split Source folder is gone; shown as not chosen"))
    }

    func testRealFolderCheck() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-settings-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try Data("x".utf8).write(to: URL(fileURLWithPath: dir + "/file"))
        XCTAssertTrue(AppSettings.isFolder(dir))
        XCTAssertFalse(AppSettings.isFolder(dir + "/file"), "a file is not a folder")
        XCTAssertFalse(AppSettings.isFolder(dir + "/missing"))
    }

    func testUnknownModeFallsBackToSplit() {
        defaults.set("bogus", forKey: AppSettings.Key.activeMode)
        XCTAssertEqual(AppSettings.load(from: defaults).settings.activeMode, .split)
    }

    func testMatchOnMKANameDefaultsOnAndPersistsOff() {
        XCTAssertTrue(AppSettings().matchOnMKAName)
        let (fresh, _) = AppSettings.load(from: defaults, folderExists: { _ in true })
        XCTAssertTrue(fresh.matchOnMKAName, "a missing key stays on")
        var settings = AppSettings()
        settings.matchOnMKAName = false
        settings.save(to: defaults)
        XCTAssertFalse(AppSettings.load(from: defaults, folderExists: { _ in true }).settings.matchOnMKAName)
    }

    func testSummaryHasNoPaths() {
        var settings = AppSettings()
        settings.setFolder("/Users/secret/Rips", .split, .source)
        settings.chosenToolPath = "/Users/secret/mkvmerge"
        XCTAssertFalse(settings.summary.contains("secret"))
        XCTAssertEqual(settings.summary, "mode Split, folders Split 1/2 Remux 0/3, mkvmerge chosen, notification on, Dock bounce on, match on MKA name on")
        XCTAssertEqual(AppSettings.Key.all.count, 10)
    }
}

final class ToolStatusTests: XCTestCase {
    private let paths = ExternalToolPaths(paths: ["mkvmerge": "/opt/homebrew/bin/mkvmerge"])

    func testAutomaticFound() {
        let status = ToolStatus.resolve(chosen: nil, automatic: { self.paths }, locateChosen: { _ in XCTFail(); return nil }, version: { _ in "mkvmerge v92.0 ('Everglow') 64-bit" })
        XCTAssertEqual(status, .found(path: "/opt/homebrew/bin/mkvmerge", version: "mkvmerge v92.0 ('Everglow') 64-bit"))
        XCTAssertEqual(status.settingsStatus, "Found · v92.0")
        XCTAssertEqual(status.version, "mkvmerge v92.0 ('Everglow') 64-bit")
        XCTAssertTrue(status.isUsable)
        XCTAssertFalse(status.showsBanner)
        XCTAssertFalse(status.canUseAutomatic)
    }

    func testAutomaticNotFound() {
        let status = ToolStatus.resolve(chosen: nil, automatic: { nil }, locateChosen: { _ in nil }, version: { _ in nil })
        XCTAssertEqual(status, .notFound)
        XCTAssertTrue(status.showsBanner)
        XCTAssertEqual(status.settingsStatus, "Not found")
        XCTAssertEqual(status.locationHelp, ExternalTool.searchDescription())
    }

    func testChosenRuns() {
        let status = ToolStatus.resolve(chosen: "/x/mkvmerge", automatic: { self.paths },
                                        locateChosen: { ExternalToolPaths(paths: ["mkvmerge": $0]) }, version: { _ in "mkvmerge v88.0" })
        XCTAssertEqual(status, .chosen(path: "/x/mkvmerge", version: "mkvmerge v88.0"))
        XCTAssertEqual(status.settingsStatus, "Chosen · v88.0")
        XCTAssertTrue(status.canUseAutomatic)
    }

    /// L15: a stale chosen path is "Can't run", never a silent fallback.
    func testStaleChosenPathDoesNotFallBack() {
        let status = ToolStatus.resolve(chosen: "/gone/mkvmerge", automatic: { self.paths }, locateChosen: { _ in nil }, version: { _ in "v1" })
        XCTAssertEqual(status, .chosenFails(path: "/gone/mkvmerge", reason: ToolStatus.chosenMissingReason))
        XCTAssertNil(status.executable)
        XCTAssertNil(status.version)
        XCTAssertTrue(status.showsBanner)
        XCTAssertEqual(status.settingsStatus, "Can't run this mkvmerge")
        XCTAssertEqual(status.settingsPath, "/gone/mkvmerge")
        XCTAssertEqual(status.locationHelp, ToolStatus.chosenMissingReason)
        XCTAssertTrue(status.canUseAutomatic)
    }

    func testChosenThatDoesNotRun() {
        let status = ToolStatus.resolve(chosen: "/x/mkvmerge", automatic: { self.paths },
                                        locateChosen: { ExternalToolPaths(paths: ["mkvmerge": $0]) }, version: { _ in nil })
        XCTAssertEqual(status, .chosenFails(path: "/x/mkvmerge", reason: ToolStatus.chosenDoesNotRunReason))
    }

    func testShortVersion() {
        XCTAssertEqual(ToolStatus.shortVersion("mkvmerge v92.0 ('Everglow') 64-bit"), "v92.0")
        XCTAssertEqual(ToolStatus.shortVersion("weird"), "weird")
        XCTAssertEqual(ToolStatus.checking.settingsStatus, "Looking…")
        XCTAssertFalse(ToolStatus.checking.isUsable)
    }

    func testSearchDescriptionListsTheRealSearchOrder() {
        XCTAssertEqual(ExternalTool.searchDescription(),
                       "Looked in /opt/homebrew/bin, /usr/local/bin, /Applications/MKVToolNix*.app/Contents/MacOS and PATH.")
        XCTAssertEqual(ExternalTool.searchLocations(), ["/opt/homebrew/bin", "/usr/local/bin", "/Applications/MKVToolNix*.app/Contents/MacOS", "PATH"])
    }
}

/// Runs the real mkvmerge. Skips when it isn't installed (the macOS CI jobs).
final class RealToolTests: XCTestCase {
    private func mkvmerge() throws -> String {
        guard let path = ExternalTool.locate(.primary)?["mkvmerge"] else {
            throw XCTSkip("mkvmerge isn't installed here; this test runs on Linux CI and in the agent environment")
        }
        return path
    }

    func testToolStatusWithRealMKVMerge() throws {
        let path = try mkvmerge()
        let automatic = ToolStatus.resolve(chosen: nil)
        guard case let .found(found, version) = automatic else { return XCTFail("\(automatic)") }
        XCTAssertEqual(found, path)
        XCTAssertTrue(ToolStatus.shortVersion(version).hasPrefix("v"), version)
        let chosen = ToolStatus.resolve(chosen: path)
        XCTAssertEqual(chosen.executable, path)
        XCTAssertEqual(chosen.settingsStatus.hasPrefix("Chosen · v"), true)
        let stale = ToolStatus.resolve(chosen: "/nonexistent-\(UUID().uuidString)/mkvmerge")
        XCTAssertNil(stale.executable, "L15: no fallback to the found copy")
        XCTAssertEqual(stale.settingsStatus, "Can't run this mkvmerge")
    }

    func testScanProgressWithRealMKVMerge() async throws {
        let tool = try mkvmerge()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mkvforge-progress-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        for folder in ["src", "out"] { try FileManager.default.createDirectory(atPath: "\(root)/\(folder)", withIntermediateDirectories: true) }
        try Data("1\n00:00:00,100 --> 00:00:00,500\nHi\n".utf8).write(to: URL(fileURLWithPath: "\(root)/s.srt"))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-q", "-o", "\(root)/src/E1.mkv", "\(root)/s.srt"]
        process.environment = ToolEnvironment.forTools()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        for n in 2...3 { try FileManager.default.copyItem(atPath: "\(root)/src/E1.mkv", toPath: "\(root)/src/E\(n).mkv") }

        let recorder = ScanProgressTests.Recorder()
        var scanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool), now: { Date().addingTimeInterval(120) })
        scanner.progressInterval = 0
        let result = try await scanner.scanSplit(source: "\(root)/src", output: "\(root)/out", progress: { recorder.append($0) })
        XCTAssertEqual(result.items.map(\.baseName), ["E1", "E2", "E3"])
        XCTAssertEqual(recorder.all.first, .listing)
        XCTAssertEqual(recorder.readings.map(\.0), [1, 2, 3, 3])
        XCTAssertTrue(recorder.readings.allSatisfy { $0.1 == 3 })
    }
}
