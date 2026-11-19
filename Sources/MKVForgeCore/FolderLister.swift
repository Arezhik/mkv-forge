import Foundation

/// One entry at the top level of a folder. Symbolic links are followed.
public struct FileEntry: Equatable, Sendable {
    public var name: String
    public var isRegularFile: Bool
    public var size: Int64
    public var modified: Date
    public var isReadable: Bool

    public init(name: String, isRegularFile: Bool = true, size: Int64 = 1, modified: Date = .distantPast, isReadable: Bool = true) {
        self.name = name
        self.isRegularFile = isRegularFile
        self.size = size
        self.modified = modified
        self.isReadable = isReadable
    }

    /// The file name without its last extension. Matching uses it exactly (no case
    /// folding); Swift string equality already treats NFC and NFD names as equal.
    public var baseName: String { (name as NSString).deletingPathExtension }

    public var pathExtension: String { (name as NSString).pathExtension }
}

/// Folder access for scans. `LocalFolderLister` reads the disk; tests use a fake.
public protocol FolderListing: Sendable {
    /// The top-level entries of `folder`, unfiltered. Throws when the folder can't be read.
    func entries(in folder: String) throws -> [FileEntry]
    func fileExists(atPath path: String) -> Bool
}

public struct LocalFolderLister: FolderListing {
    public init() {}

    public func entries(in folder: String) throws -> [FileEntry] {
        let fileManager = FileManager.default
        let names = try fileManager.contentsOfDirectory(atPath: folder)
        return names.map { name in
            let path = (folder as NSString).appendingPathComponent(name)
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            guard let attributes = try? fileManager.attributesOfItem(atPath: resolved) else {
                // A broken link or a file that vanished mid-scan.
                return FileEntry(name: name, isRegularFile: false, size: 0, isReadable: false)
            }
            let type = attributes[.type] as? FileAttributeType
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            return FileEntry(
                name: name,
                isRegularFile: type == .typeRegular,
                size: size,
                modified: attributes[.modificationDate] as? Date ?? .distantPast,
                isReadable: fileManager.isReadableFile(atPath: resolved)
            )
        }
    }

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

public enum ScanFilter {
    /// Regular files with the given extension (any letter case), skipping hidden files,
    /// which includes macOS `._` AppleDouble files. Top level only: subfolders are skipped.
    public static func candidates(_ entries: [FileEntry], fileExtension: String) -> [FileEntry] {
        entries.filter { entry in
            !entry.name.hasPrefix(".")
                && entry.isRegularFile
                && entry.pathExtension.lowercased() == fileExtension.lowercased()
                && !entry.baseName.isEmpty
        }
    }

    /// Candidates grouped by exact base name. More than one entry means a duplicate name.
    public static func byBaseName(_ entries: [FileEntry]) -> [String: [FileEntry]] {
        var groups: [String: [FileEntry]] = [:]
        for entry in entries {
            groups[entry.baseName, default: []].append(entry)
        }
        for key in groups.keys {
            groups[key]?.sort { $0.name < $1.name }
        }
        return groups
    }
}
