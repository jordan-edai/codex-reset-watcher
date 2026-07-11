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
                .font(CodexStyle.Typography.sidebarDetail.weight(.semibold))
                .foregroundStyle(.secondary)
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
                    .fill(.secondary.opacity(row.isStale ? 0.16 : 0.10))
                Image(systemName: row.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(CodexStyle.Typography.sidebarTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(row.detail)
                    .font(CodexStyle.Typography.sidebarDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

}
