import SwiftUI

@main
struct CodexResetWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ResetCreditsStore()

    var body: some Scene {
        WindowGroup("Codex Reset Watcher", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 620, idealWidth: 700, minHeight: 540, idealHeight: 590)
                .task {
                    store.start()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Codex Reset Watcher") {
                Button("Refresh") {
                    Task {
                        await store.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarStatusView(store: store)
                .task {
                    store.start()
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.statusSymbolName)
                Text(store.menuBarTitle)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
