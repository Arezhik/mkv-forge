import SwiftUI
import MKVForgeCore

/// Phase 1 placeholder for the main window. The app UI phase replaces this body with the
/// mode switch, folder panel, queue table, and bottom bar in
/// docs/design/v1-layout-contract_v2.md. No drop target: MKVForge uses Choose… buttons only.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ContentUnavailableView {
            Label("MKVForge", systemImage: "film")
        } description: {
            VStack(spacing: 6) {
                Text("Split and Remux are added in later phases.")
                Text(model.toolStatus.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        } actions: {
            if model.toolStatus == .notFound {
                Link("Get MKVToolNix", destination: Self.downloadPage)
            }
        }
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .navigationTitle("MKVForge")
        .navigationSubtitle(model.toolStatus.subtitle)
        .background {
            WindowEvents(name: "Main").allowsHitTesting(false)
        }
    }

    // A literal that always parses; the contract's decided link (§9).
    private static let downloadPage = URL(string: "https://mkvtoolnix.download/") ?? URL(fileURLWithPath: "/")
}
