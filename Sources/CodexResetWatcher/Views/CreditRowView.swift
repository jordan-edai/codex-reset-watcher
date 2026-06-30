import SwiftUI

struct CreditRowView: View {
    let credit: ResetCreditDisplay
    var ordinal: Int?

    var body: some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.panel) {
            CodexIconBadge(
                systemName: iconName,
                tone: tone,
                size: CodexStyle.Size.iconBadge,
                symbolSize: CodexStyle.Icon.content
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(ordinal.map { "Reset \($0) expires:" } ?? "Reset expires:")
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.weekdayCompact(credit.expiresAt))
                        .font(CodexStyle.Typography.cardMetric)
                        .foregroundStyle(CodexPalette.primaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    Text(credit.title ?? "Codex reset credit")
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                if let hint = urgency.hint {
                    Text(hint)
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(tone.foreground)
                        .lineLimit(1)
                }
            }

            Spacer()

            CodexStatusBadge(text: urgency.badge, tone: tone, filled: usesFilledBadge)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: rowBackground, border: tone.border, shadow: false)
    }

    private var urgency: ResetExpiryUrgency {
        ResetExpiryUrgency.make(
            expiresAt: credit.expiresAt,
            isAvailable: credit.isAvailable
        )
    }

    private var iconName: String {
        switch urgency.level {
        case .normal:
            return "calendar.badge.clock"
        case .approaching, .soon:
            return "clock.badge.exclamationmark"
        case .urgent, .expired:
            return "exclamationmark.octagon.fill"
        case .inactive:
            return "clock.badge.xmark"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var tone: CodexTone {
        CodexTone.resetUrgency(urgency)
    }

    private var usesFilledBadge: Bool {
        switch urgency.level {
        case .normal:
            return false
        case .approaching:
            return false
        case .soon:
            return true
        case .urgent, .expired:
            return true
        case .inactive, .unknown:
            return false
        }
    }

    private var rowBackground: Color {
        switch urgency.level {
        case .normal:
            return CodexPalette.elevatedBackground
        case .approaching, .soon, .urgent, .expired:
            return tone.background
        case .inactive, .unknown:
            return CodexPalette.elevatedBackground
        }
    }
}

struct MissingResetExpiryRowView: View {
    let ordinal: Int

    var body: some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.panel) {
            CodexIconBadge(
                systemName: "calendar.badge.questionmark",
                tone: .muted,
                size: CodexStyle.Size.iconBadge,
                symbolSize: CodexStyle.Icon.content
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Reset \(ordinal) expires:")
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text("Expiry unavailable")
                        .font(CodexStyle.Typography.cardTitle)
                        .foregroundStyle(CodexPalette.primaryText)
                }

                Text("Codex reported this reset, but did not return an expiry date.")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            CodexStatusBadge(text: "Check again", tone: .muted)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: CodexPalette.elevatedBackground, border: CodexPalette.softBorder, shadow: false)
    }
}
