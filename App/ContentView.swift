import AppKit
import SwiftUI
import MKVForgeCore

// The main window (docs/design/v1-layout-contract_v2.md §1–§9, §11, §12; v2.1 addendum
// §2). From top to bottom: toolbar (title + subtitle, mode switch, primary action), the
// MKVToolNix-not-found banner, the folder panel and Scan row, the queue table, and the
// bottom bar. Every text, enablement and status comes from MKVForgeCore (StatusLines,
// ScanCaption, RowDisplay, EmptyState, Workflow), so the rules are tested on Linux.
// Controls write the model on the next run-loop turn, never during a view update (L10).
// All of the main window is in this file until the Mac-side project regeneration
// (docs/LESSONS.md L19): Linux agents can't add files to the Xcode project.

struct ContentView: View {
    // The only reader of the environment in the main window. Every subview gets `model`
    // from its parent: on macOS, Table cells, context menus and toolbar items are hosted in
    // separate AppKit views that don't reliably inherit it (docs/LESSONS.md L31).
    @EnvironmentObject private var model: AppModel
    @State private var selected = TableSelection()

    var body: some View {
        VStack(spacing: 0) {
            if model.toolStatus.showsBanner {
                ToolBanner(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            FolderPanel(model: model)
            Divider()
            QueueTable(model: model, selection: selection)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(model: model)
        }
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ModePicker(model: model)
            }
            ToolbarItem(placement: .primaryAction) {
                PrimaryButton(model: model)
            }
        }
        .navigationTitle("MKVForge")
        .navigationSubtitle(StatusLines.subtitle(model.workflow, model.current, toolUsable: model.toolUsable))
        .background {
            WindowEvents(name: "Main").allowsHitTesting(false)
            MainWindowAccessor(model: model).allowsHitTesting(false)
        }
        .onChange(of: model.toolStatus.showsBanner) { _, shows in
            // The banner is announced once when it appears (v2 §11).
            if shows { model.announce(StatusLines.toolMissingBanner) }
        }
    }

    /// The table selection, cleared by a mode switch in the same update that switches
    /// (Split and Remux rows never share a selection). It belongs to one visit of a mode:
    /// it reads as empty once `modeSwitchCount` moves on, so nothing writes state during
    /// the switch (L10).
    private var selection: Binding<Set<String>> {
        let visit = model.modeSwitchCount
        let stored = $selected
        return Binding(
            get: { stored.wrappedValue.visit == visit ? stored.wrappedValue.ids : [] },
            set: { ids in stored.wrappedValue = TableSelection(visit: visit, ids: ids) }
        )
    }
}

/// Selected row ids and the mode visit they were selected in.
private struct TableSelection {
    var visit = 0
    var ids: Set<String> = []
}

// MARK: Toolbar (v2 §2, §6)

private struct ModePicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Picker("Mode", selection: modeBinding) {
            Text("Split").tag(ScanMode.split)
            Text("Remux").tag(ScanMode.remux)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(minWidth: 168)
        .disabled(!model.enablement.modeSwitch)
        .help(model.enablement.modeSwitch ? "" : Workflow.busyHelp)
        .accessibilityLabel("Mode")
    }

    private var modeBinding: Binding<ScanMode> {
        Binding(
            get: { [model] in model.activeMode },
            set: { [model] mode in Task { @MainActor in model.selectMode(mode) } }
        )
    }
}

private struct PrimaryButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let enablement = model.enablement
        Group {
            switch model.workflow.primaryAction(model.activeMode) {
            case let .run(title, systemImage):
                Button {
                    model.primaryAction()
                } label: {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!enablement.primary)
            case .cancel:
                Button {
                    model.primaryAction()
                } label: {
                    Label(PrimaryAction.cancel.title, systemImage: "stop.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            case .cancelling:
                Button {} label: {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                        Text(PrimaryAction.cancelling.title)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
        }
        .frame(minWidth: 96)
        .help(enablement.primaryHelp ?? "")
    }
}

// MARK: Banner (v2 §9)

private struct ToolBanner: View {
    @ObservedObject var model: AppModel

    private static let downloadPage = URL(string: StatusLines.downloadURL) ?? URL(fileURLWithPath: "/")

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Link("Get MKVToolNix ↗", destination: Self.downloadPage)
                .accessibilityLabel("Get MKVToolNix, opens in browser")
            Button("Choose mkvmerge…") {
                model.chooseTool()
            }
            SettingsLink {
                Text("Settings…")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if case .chosenFails = model.toolStatus { return model.toolStatus.settingsStatus }
        return StatusLines.toolMissingBanner
    }

    private var message: String {
        if case let .chosenFails(_, reason) = model.toolStatus { return reason }
        return StatusLines.toolMissingBannerDetail
    }
}

// MARK: Folder panel and Scan row (v2 §3, v2.1 §2.2)

private struct FolderPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let state = model.current
        let enablement = model.enablement
        VStack(alignment: .leading, spacing: 7) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                ForEach(state.roles, id: \.self) { role in
                    GridRow {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(FolderDisplay.label(role))
                                .font(.system(size: 12.5))
                            Text(FolderDisplay.holds(role, mode: state.mode))
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 92, alignment: .trailing)
                        .accessibilityHidden(true)

                        FolderField(model: model, role: role, path: state.folder(role), menuEnabled: enablement.folderMenus)

                        Button("Choose…") {
                            model.chooseFolder(role)
                        }
                        .disabled(!enablement.chooseFolders)
                        .accessibilityLabel(FolderDisplay.chooseLabel(role))
                    }
                }
            }
            ScanRow(model: model)
        }
        .padding(16)
    }
}

private struct FolderField: View {
    @ObservedObject var model: AppModel
    let role: FolderRole
    let path: String?
    let menuEnabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let path {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(FolderDisplay.name(path))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(FolderDisplay.abbreviated(path, home: NSHomeDirectory()))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(.tertiary)
                Text(FolderDisplay.emptyText)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
        .help(path ?? FolderDisplay.emptyText)
        .contextMenu {
            Button("Show in Finder") {
                if let path { model.reveal(path: path) }
            }
            .disabled(path == nil || !menuEnabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FolderDisplay.accessibilityLabel(role, path: path, home: NSHomeDirectory()))
    }
}

private struct ScanRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let scanning = model.workflow.activity.isScanning
        let caption = model.scanCaption
        let enablement = model.enablement
        HStack(spacing: 6) {
            Spacer()
            if scanning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
            Text(caption)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(captionColor(scanning: scanning))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(scanning ? ScanCaption.escHelp : (model.scanFailed ? caption : ""))
                .accessibilityLabel("Scan status")
                .accessibilityValue(caption.replacingOccurrences(of: "Scanning… ", with: "Scanning, "))
            Button {
                model.scan()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(!enablement.scan)
            .help(enablement.scanHelp ?? "")
        }
    }

    private func captionColor(scanning: Bool) -> Color {
        if scanning { return Color.primary }
        if model.scanFailed { return Color.orange }
        return Color.secondary
    }
}

// MARK: Queue table (v2 §4, v2.1 §2.4)

private struct QueueTable: View {
    @ObservedObject var model: AppModel
    @Binding var selection: Set<String>

    var body: some View {
        let state = model.current
        let mode = state.mode
        let locked = model.workflow.activity.isBusy
        // Re-scan: the old rows stay, dimmed, until the new ones replace them in one step.
        let rescanning = model.workflow.activity.isScanning && !state.rows.isEmpty
        Table(state.rows, selection: $selection) {
            TableColumn("") { (row: QueueRow) in
                CheckboxCell(model: model, row: row, display: RowDisplay(row, mode: mode, locked: locked))
            }
            .width(28)
            TableColumn("Name") { (row: QueueRow) in
                NameCell(display: RowDisplay(row, mode: mode, locked: locked))
            }
            .width(min: 220, ideal: 300)
            TableColumn("Status") { (row: QueueRow) in
                StatusCell(display: RowDisplay(row, mode: mode, locked: locked))
            }
            .width(min: 140, ideal: 160, max: 200)
            TableColumn("Reason") { (row: QueueRow) in
                ReasonCell(display: RowDisplay(row, mode: mode, locked: locked))
            }
            .width(min: 220)
        }
        .alternatingRowBackgrounds()
        .contextMenu(forSelectionType: String.self) { ids in
            RowMenu(model: model, ids: ids)
        }
        .onKeyPress(.space) {
            // Space toggles the selected rows' checkboxes (v2 §11).
            guard model.enablement.checkboxes, !selection.isEmpty else { return .ignored }
            let ids = selection
            Task { @MainActor in model.toggle(ids) }
            return .handled
        }
        .opacity(rescanning ? 0.45 : 1)
        .disabled(rescanning)
        .overlay {
            if let empty = EmptyState.make(model.workflow, state, toolUsable: model.toolUsable) {
                EmptyStateView(state: empty)
                    .padding(.top, 28)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct CheckboxCell: View {
    // A plain `let`: row cells only write, and each one observing the model would redraw
    // every row on every change. `row` and `display` are values the Table re-evaluates.
    let model: AppModel
    let row: QueueRow
    let display: RowDisplay

    var body: some View {
        if row.isFlagged {
            toggle.accessibilityValue("not selectable")
        } else {
            toggle
        }
    }

    private var toggle: some View {
        Toggle(display.checkboxLabel, isOn: checkedBinding)
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(!display.checkboxEnabled)
            .help(display.checkboxHelp ?? "")
            .accessibilityLabel(display.checkboxLabel)
            .accessibilityHint(display.checkboxHelp ?? "")
    }

    private var checkedBinding: Binding<Bool> {
        let id = row.id
        let checked = row.isChecked
        return Binding(
            get: { checked },
            set: { [model] value in Task { @MainActor in model.setChecked(id, value) } }
        )
    }
}

private struct NameCell: View {
    let display: RowDisplay

    var body: some View {
        Text(display.name)
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.tail)
            .help(display.nameHelp)
            .accessibilityLabel(display.accessibilityLabel)
    }
}

private struct StatusCell: View {
    let display: RowDisplay

    var body: some View {
        HStack(spacing: 5) {
            if display.showsSpinner {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(display.spinnerLabel ?? "")
            } else if let symbol = display.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(statusColor(display.tint))
                    .accessibilityHidden(true)
            }
            Text(display.statusText)
                .lineLimit(1)
        }
    }
}

private struct ReasonCell: View {
    let display: RowDisplay

    var body: some View {
        Text(display.reason)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(display.reasonHelp ?? "")
    }
}

/// Semantic system colors, so they adapt to Increase Contrast and dark mode (v2 §11).
private func statusColor(_ tint: StatusTint) -> Color {
    switch tint {
    case .secondary: return Color.secondary
    case .orange: return Color.orange
    case .yellow: return Color.yellow
    case .green: return Color.green
    case .red: return Color.red
    case .accent: return Color.accentColor
    }
}

/// Row context menu: Show in Finder for a Done row, Select All Ready / Deselect All.
/// Flagged rows keep this menu for the overrides feature (#14).
private struct RowMenu: View {
    // A plain `let`: the menu is built when it opens.
    let model: AppModel
    let ids: Set<String>

    var body: some View {
        if let path = outputPath {
            Button("Show in Finder") {
                model.reveal(path: path)
            }
            Divider()
        }
        Button("Select All Ready") {
            model.selectAllReady()
        }
        .disabled(!model.enablement.selectAll)
        Button("Deselect All") {
            model.deselectAll()
        }
        .disabled(!model.enablement.selectAll)
    }

    private var outputPath: String? {
        guard ids.count == 1, let id = ids.first, let row = model.current.row(id) else { return nil }
        return RowDisplay(row, mode: model.current.mode, locked: true).outputPath
    }
}

private struct EmptyStateView: View {
    let state: EmptyState

    var body: some View {
        ContentUnavailableView {
            Label(state.title, systemImage: symbol)
        } description: {
            Text(state.message)
        } actions: {
            if state.showsStopScanHint {
                HStack(spacing: 6) {
                    Text("esc")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.6), lineWidth: 1))
                    Text("Stop Scan")
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Press Escape to stop the scan")
            }
        }
    }

    private var symbol: String {
        if state.showsStopScanHint { return "magnifyingglass" }
        switch state.title {
        case "Can't scan yet": return "exclamationmark.triangle"
        case "No files found": return "tray"
        case "Ready to scan": return "arrow.clockwise"
        default: return "folder"
        }
    }
}

// MARK: Bottom bar (v2 §7)

private struct BottomBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let workflow = model.workflow
        let state = model.current
        let summary = StatusLines.summary(workflow, state)
        HStack(spacing: 12) {
            Text("\(Text(summary.bold).fontWeight(.semibold))\(summary.rest)")
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityLabel(summary.plain)
            Spacer(minLength: 12)
            if StatusLines.showsShowInFinder(workflow, state) {
                Button("Show in Finder") {
                    model.showOutputsInFinder()
                }
                .controlSize(.small)
            }
            if let column = StatusLines.progressColumn(workflow, state) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(column.caption.isEmpty ? " " : column.caption)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(column.completed), total: Double(max(column.total, 1)))
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                }
                .frame(width: 152)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Batch progress")
                .accessibilityValue(StatusLines.progressAccessibilityValue(column))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
