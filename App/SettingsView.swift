import SwiftUI
import MKVForgeCore

/// Opened from the app menu and ⌘, (docs/design/v1-layout-contract_v2.md §8). One pane,
/// 540 pt wide, height fitted to the content, not resizable.
/// - MKVToolNix: the mkvmerge in use and its status, Choose… (the MKVToolNix app or the
///   mkvmerge binary), Use Automatic, and the real search list. A chosen copy that's
///   missing or doesn't run shows "Can't run this mkvmerge"; there's no fallback (L15).
/// - When a batch finishes: two mini switches, on by default. If macOS doesn't allow
///   MKVForge's notifications, an inline note offers Open System Settings….
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private static let downloadPage = URL(string: StatusLines.downloadURL) ?? URL(fileURLWithPath: "/")

    var body: some View {
        Form {
            Section {
                LabeledContent("mkvmerge") {
                    HStack(spacing: 8) {
                        Text(model.toolStatus.settingsPath ?? "")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .help(model.toolStatus.settingsPath ?? "")
                        Label(model.toolStatus.settingsStatus, systemImage: model.toolStatus.settingsSymbol)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(model.toolStatus.isWarning ? Color.orange : Color.secondary)
                            .fixedSize()
                    }
                }
                LabeledContent("Location") {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(model.toolStatus.locationHelp)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            if model.toolStatus.showsBanner {
                                Link("Get MKVToolNix ↗", destination: Self.downloadPage)
                                    .accessibilityLabel("Get MKVToolNix, opens in browser")
                                Button("Search Again") {
                                    model.detectTool()
                                }
                            }
                            Button("Use Automatic") {
                                model.useAutomaticTool()
                            }
                            .disabled(!model.toolStatus.canUseAutomatic)
                            Button("Choose…") {
                                model.chooseTool()
                            }
                        }
                    }
                }
            } header: {
                // Grouped Form headers are a group title on macOS, not a static
                // text, and the form may uppercase them. The label and identifier
                // stay the exact section name.
                Text("MKVToolNix")
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("mkvToolNixSection")
                    .accessibilityLabel("MKVToolNix")
                    .accessibilityAddTraits(.isHeader)
            } footer: {
                if model.toolStatus != .notFound {
                    Text(ExternalTool.searchDescription())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Remux") {
                let locked = model.remuxMatchLocked
                Toggle(isOn: matchBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MatchOnMKAName.label)
                        Text(MatchOnMKAName.helpLine1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(MatchOnMKAName.helpLine2)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        if locked {
                            Text(MatchOnMKAName.disabledHelp)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(locked)
                .accessibilityLabel(MatchOnMKAName.label)
                .accessibilityHint(locked ? MatchOnMKAName.disabledHelp : "\(MatchOnMKAName.helpLine1) \(MatchOnMKAName.helpLine2)")
            }

            Section("When a batch finishes") {
                Toggle(isOn: notifyBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Send a notification")
                        Text("Only when MKVForge isn't the active app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel("Send a notification")
                .accessibilityHint("Only when MKVForge isn't the active app.")

                if model.settings.notifyWhenFinished && model.notificationsBlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text("Notifications are off for MKVForge in System Settings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Open System Settings…") {
                            model.openNotificationSettings()
                        }
                    }
                }

                Toggle(isOn: bounceBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bounce the Dock icon")
                        Text("Once, only when MKVForge is in the background.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityLabel("Bounce the Dock icon")
                .accessibilityHint("Once, only when MKVForge is in the background.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
        .navigationTitle("MKVForge Settings")
        .onAppear {
            model.refreshNotificationStatus()
        }
    }

    // Controls write the model on the next run-loop turn, not during a view update (L10).
    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { [model] in model.settings.notifyWhenFinished },
            set: { [model] value in Task { @MainActor in model.setNotify(value) } }
        )
    }

    private var bounceBinding: Binding<Bool> {
        Binding(
            get: { [model] in model.settings.bounceWhenFinished },
            set: { [model] value in Task { @MainActor in model.setBounce(value) } }
        )
    }

    private var matchBinding: Binding<Bool> {
        Binding(
            get: { [model] in model.settings.matchOnMKAName },
            set: { [model] value in Task { @MainActor in model.setMatchOnMKAName(value) } }
        )
    }
}
