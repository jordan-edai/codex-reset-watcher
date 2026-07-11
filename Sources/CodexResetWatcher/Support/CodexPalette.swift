import AppKit
import SwiftUI

enum CodexPalette {
    enum Reference {
        static let lightCardBackground: UInt = 0xFFFFFF
        static let darkCardBackground: UInt = 0x323234
        static let lightSecondaryText: UInt = 0x54545A
        static let darkSecondaryText: UInt = 0xD1D1D6
        static let lightMutedText: UInt = 0x6E6E73
        static let darkMutedText: UInt = 0xAEAEB2
        static let lightNeutralText: UInt = 0x0057C9
        static let darkNeutralText: UInt = 0x66A9FF
        static let lightAvailableText: UInt = 0x16703A
        static let darkAvailableText: UInt = 0x63D98A
        static let lightWarningText: UInt = 0x7A4D00
        static let darkWarningText: UInt = 0xFFD60A
        static let lightUrgentText: UInt = 0xB00020
        static let darkUrgentText: UInt = 0xFF6961
        static let lightAvailableMeter: UInt = 0x34C759
        static let darkAvailableMeter: UInt = 0x30D158
        static let lightWarningMeter: UInt = 0xF0A500
        static let darkWarningMeter: UInt = 0xFFD60A
        static let lightUrgentMeter: UInt = 0xD70015
        static let darkUrgentMeter: UInt = 0xFF453A
    }

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
        Color(lightHex: Reference.lightCardBackground, darkHex: Reference.darkCardBackground)
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
        Color(lightHex: Reference.lightSecondaryText, darkHex: Reference.darkSecondaryText)
    }

    static var mutedText: Color {
        Color(lightHex: Reference.lightMutedText, darkHex: Reference.darkMutedText)
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

    static var neutralText: Color {
        Color(lightHex: Reference.lightNeutralText, darkHex: Reference.darkNeutralText)
    }

    static var meterTrack: Color {
        primaryText.opacity(0.09)
    }

    static var availableGreen: Color {
        Color(lightHex: Reference.lightAvailableMeter, darkHex: Reference.darkAvailableMeter)
    }

    static var availableText: Color {
        Color(lightHex: Reference.lightAvailableText, darkHex: Reference.darkAvailableText)
    }

    static var warningOrange: Color {
        Color(lightHex: Reference.lightWarningMeter, darkHex: Reference.darkWarningMeter)
    }

    static var warningText: Color {
        Color(lightHex: Reference.lightWarningText, darkHex: Reference.darkWarningText)
    }

    static var urgentRed: Color {
        Color(lightHex: Reference.lightUrgentMeter, darkHex: Reference.darkUrgentMeter)
    }

    static var urgentText: Color {
        Color(lightHex: Reference.lightUrgentText, darkHex: Reference.darkUrgentText)
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
