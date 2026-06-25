import SwiftUI

enum CodexPalette {
    static var appBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var subtleBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var menuPopoverBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var menuRowBackground: Color {
        Color.primary.opacity(0.045)
    }

    static var menuAccentBackground: Color {
        Color.accentColor.opacity(0.12)
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

    static var availableGreen: Color {
        Color(red: 0.0, green: 0.52, blue: 0.18)
    }

    static var warningOrange: Color {
        Color(red: 0.86, green: 0.36, blue: 0.02)
    }

    static var urgentRed: Color {
        Color(red: 0.78, green: 0.10, blue: 0.10)
    }

    static var attentionAmber: Color {
        Color(red: 0.94, green: 0.67, blue: 0.04)
    }
}
