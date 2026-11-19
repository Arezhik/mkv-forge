import AppKit
import MKVForgeCore

/// App lifecycle hooks. MKVForge takes no files from the Dock or Finder's Open With,
/// so there is no `application(_:open:)` handler and no document types in Info.plist.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        DebugLog.shared.record(.lifecycle, "Quit")
    }
}
