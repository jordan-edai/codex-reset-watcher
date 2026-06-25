import AppKit
import SwiftUI

@MainActor
final class MainWindowController: ObservableObject {
    private static let mainIdentifier = NSUserInterfaceItemIdentifier("codex-reset-watcher-main-window")
    private static let mainTitle = "Codex Reset Watcher"

    private weak var window: NSWindow?

    func register(_ window: NSWindow) {
        guard Self.looksLikeMainWindow(window) else {
            return
        }
        window.identifier = Self.mainIdentifier
        if self.window == nil || self.window?.isVisible != true {
            self.window = window
        }

        Task { @MainActor [weak self, weak window] in
            guard let self, let window else {
                return
            }
            self.consolidateMainWindows(preferred: self.window ?? window)
        }
    }

    func show(create: @escaping () -> Void) {
        if let window = registeredWindow() ?? findMainWindow() {
            register(window)
            bringForward(window)
            return
        }

        create()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            if let window = self.findMainWindow() {
                self.register(window)
                self.bringForward(window)
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func registeredWindow() -> NSWindow? {
        guard let window,
              window.isVisible || window.isMiniaturized
        else {
            return nil
        }
        return window
    }

    private func findMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.identifier == Self.mainIdentifier || Self.looksLikeMainWindow(window)
        }
    }

    private func bringForward(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func consolidateMainWindows(preferred preferredWindow: NSWindow) {
        let mainWindows = NSApp.windows.filter(Self.looksLikeMainWindow)
        guard mainWindows.count > 1 else {
            if let only = mainWindows.first {
                only.identifier = Self.mainIdentifier
                window = only
            }
            return
        }

        let keeper = preferredMainWindow(from: mainWindows, fallback: preferredWindow)
        keeper.identifier = Self.mainIdentifier
        window = keeper

        for duplicate in mainWindows where duplicate !== keeper {
            duplicate.close()
        }
    }

    private func preferredMainWindow(from windows: [NSWindow], fallback: NSWindow) -> NSWindow {
        if let keyWindow = NSApp.keyWindow,
           windows.contains(where: { $0 === keyWindow }) {
            return keyWindow
        }
        if let mainWindow = NSApp.mainWindow,
           windows.contains(where: { $0 === mainWindow }) {
            return mainWindow
        }
        if windows.contains(where: { $0 === fallback }) {
            return fallback
        }
        return windows[0]
    }

    private static func looksLikeMainWindow(_ window: NSWindow) -> Bool {
        window.title == mainTitle && window.styleMask.contains(.titled)
    }
}

struct MainWindowReader: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        WindowResolvingView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowResolvingView)?.resolveWindow()
    }

    private final class WindowResolvingView: NSView {
        let onResolve: @MainActor (NSWindow) -> Void

        init(onResolve: @escaping @MainActor (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindow()
        }

        func resolveWindow() {
            guard let window else {
                return
            }
            Task { @MainActor in
                onResolve(window)
            }
        }
    }
}
