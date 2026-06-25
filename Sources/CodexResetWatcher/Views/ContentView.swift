import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ResetCreditsStore

    var body: some View {
        NavigationSplitView {
            AccountSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 280)
        } detail: {
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
        }
    }
}
