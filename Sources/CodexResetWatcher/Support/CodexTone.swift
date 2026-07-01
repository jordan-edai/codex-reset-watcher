import SwiftUI

enum CodexTone {
    case neutral
    case selected
    case success
    case attention
    case warning
    case danger
    case muted

    var foreground: Color {
        switch self {
        case .neutral:
            return CodexPalette.neutralAccent
        case .selected:
            return CodexPalette.neutralAccent
        case .success:
            return CodexPalette.availableGreen
        case .attention:
            return CodexPalette.attentionAmber
        case .warning:
            return CodexPalette.warningOrange
        case .danger:
            return CodexPalette.urgentRed
        case .muted:
            return CodexPalette.secondaryText
        }
    }

    var background: Color {
        switch self {
        case .neutral, .selected, .muted:
            return CodexPalette.elevatedBackground
        case .success:
            return CodexPalette.elevatedBackground
        case .attention:
            return CodexPalette.attentionAmber.opacity(CodexStyle.Opacity.tintBackground)
        case .warning:
            return CodexPalette.warningRowBackground
        case .danger:
            return CodexPalette.urgentRed.opacity(CodexStyle.Opacity.tintBackground)
        }
    }

    var border: Color {
        switch self {
        case .neutral:
            return CodexPalette.neutralAccent.opacity(CodexStyle.Opacity.tintBorder)
        case .selected:
            return CodexPalette.selectedBorder
        case .success:
            return CodexPalette.availableGreen.opacity(CodexStyle.Opacity.tintBorder)
        case .attention:
            return CodexPalette.attentionAmber.opacity(CodexStyle.Opacity.strongTintBorder)
        case .warning:
            return CodexPalette.warningOrange.opacity(CodexStyle.Opacity.strongTintBorder)
        case .danger:
            return CodexPalette.urgentRed.opacity(CodexStyle.Opacity.strongTintBorder)
        case .muted:
            return CodexPalette.softBorder
        }
    }

    var badgeForeground: Color {
        switch self {
        case .attention, .warning:
            return .black.opacity(0.82)
        case .success, .danger:
            return .white
        case .neutral, .selected, .muted:
            return CodexPalette.primaryText
        }
    }

    var iconBackground: Color {
        switch self {
        case .neutral, .selected:
            return CodexPalette.neutralAccent.opacity(0.07)
        case .success:
            return CodexPalette.availableGreen.opacity(0.08)
        case .attention:
            return CodexPalette.attentionAmber.opacity(0.12)
        case .warning:
            return CodexPalette.warningOrange.opacity(0.10)
        case .danger:
            return CodexPalette.urgentRed.opacity(0.10)
        case .muted:
            return CodexPalette.primaryText.opacity(0.04)
        }
    }

    static func usage(remainingPercent: Int?) -> CodexTone {
        guard let remainingPercent else {
            return .muted
        }
        if remainingPercent <= 15 {
            return .danger
        }
        if remainingPercent <= 30 {
            return .warning
        }
        return .success
    }

    static func resetUrgency(_ urgency: ResetExpiryUrgency) -> CodexTone {
        switch urgency.level {
        case .normal:
            return .success
        case .approaching:
            return .attention
        case .soon:
            return .warning
        case .urgent, .expired:
            return .danger
        case .inactive, .unknown:
            return .muted
        }
    }
}
