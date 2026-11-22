import Foundation

// Settings and remembered state (issue #5; layout contract v2 §1, §8). Rules:
// - Folders are remembered per mode and role, as plain paths (no App Sandbox, so no
//   security-scoped bookmarks). The active mode is remembered too.
// - A remembered folder that no longer exists at launch counts as not chosen and is
//   logged; there's no alert (Phase 5 Q7).
// - The chosen mkvmerge is remembered as chosen. A missing copy is an error, not a
//   silent fallback (L15). Nil means the automatic search.
// - The notification and Dock bounce switches default to on (v2 §13).
// - The window frame is restored by SwiftUI itself (Phase 5 Q9), so it isn't stored here.

public struct AppSettings: Equatable, Sendable {
    public var activeMode: ScanMode = .split
    /// Folder paths by mode and role.
    public var folders: [ScanMode: [FolderRole: String]] = [:]
    /// The mkvmerge chosen in Settings (the binary, an app bundle, or a folder). Nil = automatic.
    public var chosenToolPath: String?
    public var notifyWhenFinished = true
    public var bounceWhenFinished = true
    /// Remux only. On: pair each .mka with a video whose name starts with the .mka name.
    /// Off: exact base-name matching. Default on (issue #33). Not saved until the user changes it,
    /// so a fresh install stays on.
    public var matchOnMKAName = true

    public init() {}

    public func folder(_ mode: ScanMode, _ role: FolderRole) -> String? {
        folders[mode]?[role]
    }

    public mutating func setFolder(_ path: String?, _ mode: ScanMode, _ role: FolderRole) {
        var byRole = folders[mode] ?? [:]
        byRole[role] = (path?.isEmpty ?? true) ? nil : path
        folders[mode] = byRole
    }

    // MARK: Keys

    public enum Key {
        public static let activeMode = "activeMode"
        public static let chosenToolPath = "mkvmergePath"
        public static let notify = "notifyWhenFinished"
        public static let bounce = "bounceWhenFinished"
        public static let matchOnMKAName = "matchOnMKAName"

        public static func folder(_ mode: ScanMode, _ role: FolderRole) -> String {
            "folder.\(mode.rawValue).\(role.rawValue)"
        }

        /// Every key this app writes.
        public static var all: [String] {
            var keys = [activeMode, chosenToolPath, notify, bounce, matchOnMKAName]
            for mode in [ScanMode.split, .remux] {
                for role in ModeState.roles(for: mode) { keys.append(folder(mode, role)) }
            }
            return keys
        }
    }

    // MARK: Loading and saving

    /// Reads the settings. `folderExists` decides whether a remembered folder still exists;
    /// the ones that don't are left out and returned in `dropped` as `"<Mode> <Role>"`.
    public static func load(from defaults: UserDefaults, folderExists: (String) -> Bool = AppSettings.isFolder) -> (settings: AppSettings, dropped: [String]) {
        var settings = AppSettings()
        if let raw = defaults.string(forKey: Key.activeMode), let mode = ScanMode(rawValue: raw) {
            settings.activeMode = mode
        }
        var dropped: [String] = []
        for mode in [ScanMode.split, .remux] {
            for role in ModeState.roles(for: mode) {
                guard let path = defaults.string(forKey: Key.folder(mode, role)), !path.isEmpty else { continue }
                if folderExists(path) {
                    settings.setFolder(path, mode, role)
                } else {
                    dropped.append("\(mode.displayName) \(role.displayName)")
                }
            }
        }
        if let path = defaults.string(forKey: Key.chosenToolPath), !path.isEmpty {
            settings.chosenToolPath = path
        }
        if defaults.object(forKey: Key.notify) != nil { settings.notifyWhenFinished = defaults.bool(forKey: Key.notify) }
        if defaults.object(forKey: Key.bounce) != nil { settings.bounceWhenFinished = defaults.bool(forKey: Key.bounce) }
        if defaults.object(forKey: Key.matchOnMKAName) != nil { settings.matchOnMKAName = defaults.bool(forKey: Key.matchOnMKAName) }
        for name in dropped {
            DebugLog.shared.record(.lifecycle, "Remembered \(name) folder is gone; shown as not chosen")
        }
        return (settings, dropped)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(activeMode.rawValue, forKey: Key.activeMode)
        for mode in [ScanMode.split, .remux] {
            for role in ModeState.roles(for: mode) {
                let key = Key.folder(mode, role)
                if let path = folder(mode, role) { defaults.set(path, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        if let chosenToolPath { defaults.set(chosenToolPath, forKey: Key.chosenToolPath) } else { defaults.removeObject(forKey: Key.chosenToolPath) }
        defaults.set(notifyWhenFinished, forKey: Key.notify)
        defaults.set(bounceWhenFinished, forKey: Key.bounce)
        defaults.set(matchOnMKAName, forKey: Key.matchOnMKAName)
    }

    public static func isFolder(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// One line for the debug log header. No paths (no user content, L13).
    public var summary: String {
        let split = ModeState.roles(for: .split).filter { folder(.split, $0) != nil }.count
        let remux = ModeState.roles(for: .remux).filter { folder(.remux, $0) != nil }.count
        return "mode \(activeMode.displayName), folders Split \(split)/2 Remux \(remux)/3, "
            + "mkvmerge \(chosenToolPath == nil ? "automatic" : "chosen"), "
            + "notification \(notifyWhenFinished ? "on" : "off"), Dock bounce \(bounceWhenFinished ? "on" : "off"), "
            + "match on MKA name \(matchOnMKAName ? "on" : "off")"
    }
}

extension ScanMode {
    /// `Split` / `Remux`: the mode switch segments and the primary action.
    public var displayName: String {
        switch self {
        case .split: return "Split"
        case .remux: return "Remux"
        }
    }
}
