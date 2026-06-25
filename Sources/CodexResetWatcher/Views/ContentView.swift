import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ResetCreditsStore

    var body: some View {
        HStack(spacing: 0) {
            AccountSidebarView(store: store)
                .frame(width: CodexStyle.Size.sidebarWidth)

            Divider()

            AccountDetailView(
                detail: store.detail(),
                cachedAccountCount: store.cachedSnapshots.count,
                onRefresh: {
                    Task {
                        await store.refresh()
                    }
                },
                onForget: { id in
                    store.forgetSnapshot(id: id)
                },
                onClearCached: {
                    store.clearCachedSnapshots()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
