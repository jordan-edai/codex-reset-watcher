import SwiftUI

enum CodexPalette {
    static var appBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var panelBackground: Color {
        cardBackground
    }

    static var menuPopoverBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var rowBackground: Color {
        panelBackground
    }

    static var selectedRowBackground: Color {
        accent.opacity(0.06)
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
        Color.primary.opacity(0.13)
    }

    static var softBorder: Color {
        Color.primary.opacity(0.08)
    }

    static var selectedBorder: Color {
        accent.opacity(0.24)
    }

    static var accent: Color {
        availableGreen
    }

    static var meterTrack: Color {
        Color.primary.opacity(0.08)
    }

    static var availableGreen: Color {
        Color(red: 0.0, green: 0.45, blue: 0.16)
    }

    static var warningOrange: Color {
        Color(red: 0.82, green: 0.34, blue: 0.02)
    }

    static var urgentRed: Color {
        Color(red: 0.78, green: 0.10, blue: 0.10)
    }

    static var attentionAmber: Color {
        Color(red: 0.94, green: 0.67, blue: 0.04)
    }
}
