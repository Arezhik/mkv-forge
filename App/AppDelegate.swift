import AppKit
import MKVForgeCore

/// App lifecycle hooks. MKVForge takes no files from the Dock or Finder's Open With,
/// so there is no `application(_:open:)` handler and no document types in Info.plist.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created on first use, from the App's body at launch.
    private(set) lazy var model = AppModel()

    /// ⌘Q, the Dock's Quit, logout and shutdown: G1 while a batch runs (v2.1 §1.4).
    /// Never holds `.terminateLater` across a file.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.shouldTerminate()
    }

    /// One window and no documents: closing it quits (v2.1 §1.6).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Auto-detect runs again when the app becomes active (v2 §9).
    func applicationDidBecomeActive(_ notification: Notification) {
        model.detectTool()
        model.refreshNotificationStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.willTerminate()
        DebugLog.shared.record(.lifecycle, "Quit")
    }
}
