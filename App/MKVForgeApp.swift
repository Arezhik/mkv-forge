import SwiftUI
import MKVForgeCore

// One `Window` scene, a Settings scene, and the menus (docs/design/v1-layout-contract_v2.md
// §1, §8, §11, §12; v2.1 addendum §2.3). MKVForge has no drag and drop, no Open…, and no
// Dock or Open With intake. Folders come from Choose… buttons.
/// The SwiftUI app entry point. MKVForge splits `.mkv` files into `.mka` and remuxes
/// video-only `.mkv` files with a matching `.mka`, in folder batches, using `mkvmerge`.
@main
struct MKVForgeApp: App {
    // The app delegate owns the model, so ⌘Q (applicationShouldTerminate) reaches it.
    // The App doesn't observe the model: an App that does re-runs this body, and its
    // menus, on every model change (docs/LESSONS.md L9). Views observe it through
    // .environmentObject; menus observe only `CommandState` (L11).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("MKVForge", id: "main") {
            ContentView()
                .environmentObject(appDelegate.model)
                .defaultAppStorage(UITestingLaunch.defaults)
        }
        .defaultSize(width: 980, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(model: appDelegate.model, commands: appDelegate.model.commands)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
                .defaultAppStorage(UITestingLaunch.defaults)
        }
        .windowResizability(.contentSize)
    }
}

/// Menu bar items. Every toolbar button is also here (L4). Key equivalents live only on
/// these items, so no shortcut is registered twice. They read only `CommandFlags` (L9).
struct AppCommands: Commands {
    let model: AppModel
    @ObservedObject var commands: CommandState

    private var flags: CommandFlags { commands.flags }

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            Button("Split") {
                model.selectMode(.split)
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(!flags.canSwitchMode || flags.mode == .split)

            Button("Remux") {
                model.selectMode(.remux)
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(!flags.canSwitchMode || flags.mode == .remux)

            Divider()
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Select All Ready") {
                model.selectAllReady()
            }
            .disabled(!flags.canSelect)

            Button("Deselect All") {
                model.deselectAll()
            }
            .disabled(!flags.canSelect)
        }

        CommandMenu("Batch") {
            // Scan ⌘R becomes Stop Scan, Esc while scanning (v2.1 §2.3).
            Button(flags.isScanning ? "Stop Scan" : "Scan") {
                if flags.isScanning {
                    model.stopScan()
                } else {
                    model.scan()
                }
            }
            .keyboardShortcut(flags.isScanning ? KeyboardShortcut.cancelAction : KeyboardShortcut("r", modifiers: .command))
            .disabled(!(flags.canScan || flags.isScanning))

            Divider()

            Button(flags.runTitle) {
                model.startRun()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!flags.canRun)

            // Esc also cancels while the main window is key (AppModel's key monitor).
            Button(flags.isCancelling ? "Cancelling…" : "Cancel") {
                model.cancelBatch()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!flags.canCancel)
        }

        CommandGroup(replacing: .help) {
            Button("Export Debug Log…") {
                model.exportDebugLog()
            }
        }
    }
}
