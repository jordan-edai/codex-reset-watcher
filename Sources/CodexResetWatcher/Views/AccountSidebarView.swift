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
                    Section("Cached snapshots") {
                        ForEach(Array(cached)) { row in
                            sidebarRow(row)
                                .tag(row.selection)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(CodexPalette.sidebarBackground)

            if !store.cachedSnapshots.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    if store.staleCachedSnapshotCount > 0 {
                        Button {
                            store.clearStaleSnapshots()
                        } label: {
                            Label("Clear stale", systemImage: "clock.badge.exclamationmark")
                        }
                    }

                    Button {
                        store.clearCachedSnapshots()
                    } label: {
                        Label("Clear cached", systemImage: "trash")
                    }
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
            ZStack {
                Circle()
                    .fill(row.isStale ? CodexTone.warning.iconBackground : CodexPalette.primaryText.opacity(0.08))
                Image(systemName: row.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(row.isStale ? CodexPalette.warningOrange : CodexPalette.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(row.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(row.isStale ? CodexPalette.warningOrange : CodexPalette.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

}
