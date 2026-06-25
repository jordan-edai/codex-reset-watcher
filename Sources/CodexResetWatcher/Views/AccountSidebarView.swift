import SwiftUI

struct AccountSidebarView: View {
    @ObservedObject var store: ResetCreditsStore

    private var selection: Binding<AccountSelection?> {
        Binding {
            store.selectedAccount
        } set: { newValue in
            if let newValue {
                store.select(newValue)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                if let active = store.sidebarRows.first {
                    Section("Active account") {
                        sidebarRow(active)
                            .tag(active.selection)
                    }
                }

                let cached = store.sidebarRows.dropFirst()
                if !cached.isEmpty {
                    Section("Other accounts") {
                        ForEach(Array(cached)) { row in
                            sidebarRow(row)
                                .tag(row.selection)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            if !store.cachedSnapshots.isEmpty {
                Divider()
                Button {
                    store.clearCachedSnapshots()
                } label: {
                    Label("Clear cached", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CodexPalette.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sidebarRow(_ row: AccountSidebarRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(row.isStale ? CodexPalette.warningOrange : CodexPalette.secondaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(row.isStale ? CodexPalette.warningOrange : CodexPalette.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
