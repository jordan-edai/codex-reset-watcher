import AppKit

enum MenuPopoverSizing {
    static func maximumDynamicContentHeight(for visibleScreenHeight: CGFloat) -> CGFloat {
        max(
            CodexStyle.Size.menuMinimumDynamicContentHeight,
            visibleScreenHeight
                - CodexStyle.Size.menuFixedChromeHeight
                - CodexStyle.Size.menuScreenEdgeInset
        )
    }

    @MainActor
    static func currentMaximumDynamicContentHeight() -> CGFloat {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        return maximumDynamicContentHeight(
            for: activeScreen?.visibleFrame.height ?? CodexStyle.Size.menuFallbackScreenHeight
        )
    }
}
