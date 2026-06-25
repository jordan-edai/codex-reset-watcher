import SwiftUI

struct CreditRowView: View {
    let credit: ResetCredit
    var ordinal: Int?

    var body: some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.panel) {
            Image(systemName: credit.isAvailable ? "checkmark.seal.fill" : "clock.badge.xmark")
                .font(.title3)
                .foregroundStyle(urgencyTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(ordinal.map { "Reset \($0) expires:" } ?? "Reset expires:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.weekdayCompact(credit.expiresAt))
                        .font(CodexStyle.Typography.cardMetric)
                        .foregroundStyle(CodexPalette.primaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    Text(credit.title ?? "Codex reset credit")
                        .font(.subheadline)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                if let hint = urgency.hint {
                    Text(hint)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(urgencyTint)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(urgency.badge)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(badgeForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(urgencyTint, in: RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous))
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: rowBackground, border: urgencyTint.opacity(borderOpacity))
    }

    private var urgency: ResetExpiryUrgency {
        ResetExpiryUrgency.make(
            expiresAt: DateFormatting.parse(credit.expiresAt),
            isAvailable: credit.isAvailable
        )
    }

    private var urgencyTint: Color {
        switch urgency.level {
        case .normal:
            return CodexPalette.availableGreen
        case .approaching:
            return CodexPalette.attentionAmber
        case .soon:
            return CodexPalette.warningOrange
        case .urgent, .expired:
            return CodexPalette.urgentRed
        case .inactive, .unknown:
            return CodexPalette.secondaryText
        }
    }

    private var rowBackground: Color {
        switch urgency.level {
        case .normal:
            return CodexPalette.cardBackground
        case .approaching, .soon, .urgent, .expired:
            return urgencyTint.opacity(0.08)
        case .inactive, .unknown:
            return CodexPalette.cardBackground
        }
    }

    private var borderOpacity: Double {
        switch urgency.level {
        case .normal, .inactive, .unknown:
            return 0.18
        case .approaching:
            return 0.44
        case .soon, .urgent, .expired:
            return 0.56
        }
    }

    private var badgeForeground: Color {
        switch urgency.level {
        case .approaching:
            return .black.opacity(0.82)
        case .normal, .soon, .urgent, .expired:
            return .white
        case .inactive, .unknown:
            return .white
        }
    }
}
