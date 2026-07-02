import SwiftUI

struct CreditRowView: View {
    let credit: ResetCreditDisplay
    var ordinal: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            CodexIconBadge(
                systemName: iconName,
                tone: tone,
                size: CodexStyle.Size.smallIconBadge,
                symbolSize: CodexStyle.Icon.badge
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(ordinal.map { "Reset \($0) expires" } ?? "Reset expires")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                Text(credit.title ?? "Codex reset credit")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                if let hint = urgency.hint {
                    Text(hint)
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(tone.foreground)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 132, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(DateFormatting.weekdayCompact(credit.expiresAt))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(CodexPalette.primaryText)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: 176, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        HStack(alignment: .center, spacing: 11) {
            CodexIconBadge(
                systemName: "calendar.badge.questionmark",
                tone: .muted,
                size: CodexStyle.Size.smallIconBadge,
                symbolSize: CodexStyle.Icon.badge
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Reset \(ordinal) expires")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                Text("Codex reported this reset, but did not return an expiry date.")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
            }
            .frame(minWidth: 132, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text("Expiry unavailable")
                .font(CodexStyle.Typography.cardTitle)
                .foregroundStyle(CodexPalette.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: 176, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .codexPanel(background: CodexPalette.elevatedBackground, border: CodexPalette.softBorder, shadow: false)
    }
}
