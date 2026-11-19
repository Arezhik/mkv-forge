import SwiftUI
import MKVForgeCore

// Phase 1 shell (docs/design/v1-layout-contract_v2.md §1, §8, §12): one `Window`
// scene, a Settings scene, and Help > Export Debug Log. MKVForge has no drag and
// drop, no Open…, and no Dock or Open With intake. Folders come from Choose…
// buttons, added with the app UI phase (docs/scaffold.md).
@main
struct MKVForgeApp: App {
    // @State, not @StateObject (first built in CI with the 2026-11-04 generator): an
    // App that observes the model re-runs this body, and its menus, on every model
    // change (docs/LESSONS.md L9). Views observe the model through .environmentObject.
    @State private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("MKVForge", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            AppCommands(model: model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

/// Menu bar items. Every toolbar button must also be here (L4).
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Export Debug Log…") {
                model.exportDebugLog()
            }
        }
    }
}
