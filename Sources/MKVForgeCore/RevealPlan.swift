import Foundation

// Show in Finder (layout contract v2 §7; L7). Rules:
// - After a finish or a Cancel that wrote files: open the Output folder and select this
//   run's outputs when they are all in that folder; otherwise open the folder.
// - Check that each file exists first; a missing file is left out.

public enum RevealPlan: Equatable, Sendable {
    /// Select these files in Finder.
    case select([String])
    /// Show this folder.
    case folder(String)
    /// Nothing to show; `reason` is for the log and a short message.
    case nothing(reason: String)

    public static func plan(outputFolder: String, outputs: [String], exists: (String) -> Bool) -> RevealPlan {
        let present = outputs.filter(exists)
        let folder = standard(outputFolder)
        if !present.isEmpty, present.allSatisfy({ standard(($0 as NSString).deletingLastPathComponent) == folder }) {
            return .select(present)
        }
        if exists(outputFolder) { return .folder(outputFolder) }
        return .nothing(reason: "The Output folder isn't there anymore.")
    }

    /// One file or folder (a row's Show in Finder, a folder field's menu).
    public static func plan(item path: String, exists: (String) -> Bool) -> RevealPlan {
        exists(path) ? .select([path]) : .nothing(reason: "\((path as NSString).lastPathComponent) isn't there anymore.")
    }

    static func standard(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
