import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ResetCreditsStore
    @Binding var appearanceModeRawValue: String

    var body: some View {
        HStack(spacing: 0) {
            AccountSidebarView(store: store)
                .frame(width: CodexStyle.Size.sidebarWidth)
                .background(CodexPalette.sidebarBackground)

            Divider()

            AccountDetailView(
                detail: store.detail(),
                cachedAccountCount: store.cachedSnapshots.count,
                appearanceModeRawValue: $appearanceModeRawValue,
                onRefresh: {
                    Task {
                        await store.refresh()
                    }
                },
                onForget: { id in
                    store.forgetSnapshot(id: id)
                },
                onClearStale: {
                    store.clearStaleSnapshots()
                },
                onClearCached: {
                    store.clearCachedSnapshots()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
