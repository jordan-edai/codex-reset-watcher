import AppKit
import SwiftUI

enum CodexPalette {
    static var appBackground: Color {
        Color(lightHex: 0xF5F4F2, darkHex: 0x262628)
    }

    static var contentBackground: Color {
        appBackground
    }

    static var sidebarBackground: Color {
        Color(lightHex: 0xEFEEEC, darkHex: 0x2E2E30)
    }

    static var cardBackground: Color {
        Color(lightHex: 0xFFFFFF, darkHex: 0x323234)
    }

    static var panelBackground: Color {
        cardBackground
    }

    static var elevatedBackground: Color {
        cardBackground
    }

    static var menuPopoverBackground: Color {
        Color(lightHex: 0xF5F4F2, darkHex: 0x2A2A2C)
    }

    static var rowBackground: Color {
        panelBackground
    }

    static var selectedRowBackground: Color {
        Color(lightHex: 0xE8F2FE, darkHex: 0x1F3448)
    }

    static var warningRowBackground: Color {
        warningOrange.opacity(0.10)
    }

    static var primaryText: Color {
        Color(lightHex: 0x1D1D1F, darkHex: 0xFFFFFF)
    }

    static var secondaryText: Color {
        primaryText.opacity(0.58)
    }

    static var mutedText: Color {
        primaryText.opacity(0.42)
    }

    static var border: Color {
        primaryText.opacity(0.10)
    }

    static var softBorder: Color {
        primaryText.opacity(0.07)
    }

    static var selectedBorder: Color {
        accent.opacity(0.30)
    }

    static var hairline: Color {
        primaryText.opacity(0.08)
    }

    static var accent: Color {
        neutralAccent
    }

    static var neutralAccent: Color {
        Color(lightHex: 0x007AFF, darkHex: 0x0A84FF)
    }

    static var meterTrack: Color {
        primaryText.opacity(0.09)
    }

    static var availableGreen: Color {
        Color(lightHex: 0x34C759, darkHex: 0x30D158)
    }

    static var warningOrange: Color {
        Color(lightHex: 0xF0A500, darkHex: 0xFFD60A)
    }

    static var urgentRed: Color {
        Color(lightHex: 0xD70015, darkHex: 0xFF453A)
    }

    static var attentionAmber: Color {
        Color(lightHex: 0xF0A500, darkHex: 0xFFD60A)
    }

    static var titlebarBackground: Color {
        Color(lightHex: 0xEFEEEC, darkHex: 0x2E2E30)
    }

    static var controlBackground: Color {
        primaryText.opacity(0.06)
    }
}

extension Color {
    init(lightHex: UInt, darkHex: UInt) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: bestMatch == .darkAqua ? darkHex : lightHex)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
