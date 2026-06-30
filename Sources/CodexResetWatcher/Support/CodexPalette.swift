import SwiftUI

enum CodexPalette {
    static var appBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var contentBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var sidebarBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var cardBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var panelBackground: Color {
        cardBackground
    }

    static var elevatedBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var menuPopoverBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var rowBackground: Color {
        panelBackground
    }

    static var selectedRowBackground: Color {
        elevatedBackground
    }

    static var warningRowBackground: Color {
        warningOrange.opacity(0.10)
    }

    static var primaryText: Color {
        Color.primary
    }

    static var secondaryText: Color {
        Color.primary.opacity(0.72)
    }

    static var mutedText: Color {
        Color.primary.opacity(0.58)
    }

    static var border: Color {
        Color.primary.opacity(0.11)
    }

    static var softBorder: Color {
        Color.primary.opacity(0.07)
    }

    static var selectedBorder: Color {
        accent.opacity(0.24)
    }

    static var hairline: Color {
        Color.primary.opacity(0.09)
    }

    static var accent: Color {
        neutralAccent
    }

    static var neutralAccent: Color {
        Color(red: 0.22, green: 0.27, blue: 0.34)
    }

    static var meterTrack: Color {
        Color.primary.opacity(0.08)
    }

    static var availableGreen: Color {
        Color(red: 0.0, green: 0.42, blue: 0.18)
    }

    static var warningOrange: Color {
        Color(red: 0.82, green: 0.36, blue: 0.05)
    }

    static var urgentRed: Color {
        Color(red: 0.78, green: 0.10, blue: 0.10)
    }

    static var attentionAmber: Color {
        Color(red: 0.94, green: 0.67, blue: 0.04)
    }
}
