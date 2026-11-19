import SwiftUI
import MKVForgeCore

/// One line for the debug log header and the launch line. Phase 1 has no stored settings yet;
/// the MKVToolNix location override and batch-finish options come with the app UI phase.
enum SettingsSummary {
    static func current() -> String {
        "none yet"
    }
}

/// Opened from the app menu and ⌘, (docs/design/v1-layout-contract_v2.md §8).
/// Phase 1 shows only where mkvmerge was found.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("MKVToolNix") {
                LabeledContent("mkvmerge") {
                    Text(model.toolStatus.detail)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .padding(.vertical, 8)
    }
}
