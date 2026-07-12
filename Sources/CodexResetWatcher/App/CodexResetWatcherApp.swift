import AppKit
import SwiftUI

@main
struct CodexResetWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceModeRawValue = CodexAppearanceMode.auto.rawValue
    @StateObject private var store = ResetCreditsStore()
    @StateObject private var mainWindowController = MainWindowController()

    private var appearanceMode: CodexAppearanceMode {
        CodexAppearanceMode(rawValue: appearanceModeRawValue) ?? .auto
    }

    var body: some Scene {
        WindowGroup("Codex Reset Watcher", id: "main") {
            ContentView(store: store, appearanceModeRawValue: $appearanceModeRawValue)
                .preferredColorScheme(appearanceMode.colorScheme)
                .onAppear {
                    applyAppearanceMode()
                }
                .onChange(of: appearanceModeRawValue) {
                    applyAppearanceMode()
                }
                .background {
                    MainWindowReader { window in
                        mainWindowController.register(window)
                    }
                }
                .frame(
                    minWidth: CodexStyle.Size.mainWindowMinWidth,
                    idealWidth: CodexStyle.Size.mainWindowDefaultWidth,
                    minHeight: CodexStyle.Size.mainWindowMinHeight,
                    idealHeight: CodexStyle.Size.mainWindowDefaultHeight
                )
                .task {
                    store.start()
                }
        }
        .defaultSize(
            width: CodexStyle.Size.mainWindowDefaultWidth,
            height: CodexStyle.Size.mainWindowDefaultHeight
        )
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
            MenuBarStatusView(
                store: store,
                mainWindowController: mainWindowController,
                appearanceModeRawValue: $appearanceModeRawValue
            )
                .preferredColorScheme(appearanceMode.colorScheme)
                .onAppear {
                    applyAppearanceMode()
                }
                .onChange(of: appearanceModeRawValue) {
                    applyAppearanceMode()
                }
                .task {
                    store.start()
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.statusSymbolName)
                Text(store.menuBarTitle)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Codex Reset Watcher")
            .accessibilityValue(store.menuBarTitle)
            .help("Codex Reset Watcher: \(store.menuBarTitle)")
        }
        .menuBarExtraStyle(.window)
    }

    private func applyAppearanceMode() {
        NSApp.appearance = appearanceMode.nsAppearance
    }
}
