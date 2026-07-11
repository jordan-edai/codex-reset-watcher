import SwiftUI
import AppKit

struct CodexArtworkThumbnail: View {
    var compact = false

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "UsageHeader", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: CodexStyle.Radius.artwork, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: CodexStyle.Radius.artwork, style: .continuous)
                            .stroke(CodexPalette.softBorder)
                    }
            } else {
                fallback
            }
        }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CodexStyle.Radius.artwork, style: .continuous)
                .fill(CodexPalette.elevatedBackground)
            Image(systemName: "terminal.fill")
                .font(.system(size: compact ? 16 : 22, weight: .semibold))
                .foregroundStyle(CodexPalette.neutralAccent)
        }
    }
}

struct CodexIconBadge: View {
    let systemName: String
    let tone: CodexTone
    var size: CGFloat = CodexStyle.Size.smallIconBadge
    var symbolSize: CGFloat = CodexStyle.Icon.badge

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: min(CodexStyle.Radius.row, size / 4), style: .continuous)
                    .fill(tone.iconBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: min(CodexStyle.Radius.row, size / 4), style: .continuous)
                    .stroke(tone.border)
            }
            .accessibilityHidden(true)
    }
}

struct CodexStatusBadge: View {
    let text: String
    let tone: CodexTone
    var filled = false

    var body: some View {
        Text(text)
            .font(CodexStyle.Typography.caption)
            .lineLimit(1)
            .foregroundStyle(filled ? tone.badgeForeground : tone.foreground)
            .padding(.horizontal, CodexStyle.Badge.horizontalPadding)
            .padding(.vertical, CodexStyle.Badge.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .fill(filled ? tone.foreground : tone.background)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .stroke(tone.border)
            }
    }
}

struct CodexSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CodexStyle.Typography.sectionTitle)
                .foregroundStyle(CodexPalette.primaryText)

            Spacer()

            if let detail {
                Text(detail)
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

struct CodexSegmentedPicker<Selection: Hashable, Content: View>: View {
    let label: String
    let selection: Binding<Selection>
    let content: () -> Content

    init(
        _ label: String,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.selection = selection
        self.content = content
    }

    var body: some View {
        Picker(label, selection: selection) {
            content()
        }
        .labelsHidden()
        .accessibilityLabel(label)
        .pickerStyle(.segmented)
        .background(CodexPalette.controlBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct LimitMeterView: View {
    let label: String
    let remainingPercent: Int?
    var tone: CodexTone? = nil
    var height: CGFloat = CodexStyle.Meter.height

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(CodexPalette.meterTrack)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(resolvedTone.meter)
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(remainingPercent.map { "\($0)%" } ?? "Unknown")
    }

    private var resolvedTone: CodexTone {
        tone ?? CodexTone.usage(remainingPercent: remainingPercent)
    }

    private var clampedValue: CGFloat {
        let value = CGFloat(max(0, min(100, remainingPercent ?? 0)))
        return value / 100
    }
}

struct CodexSummaryMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemName: String
    let tone: CodexTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CodexIconBadge(systemName: systemName, tone: tone, size: 26, symbolSize: 14)

                Text(title)
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(CodexStyle.Typography.summaryMetric)
                .foregroundStyle(CodexPalette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(CodexStyle.Typography.caption)
                .foregroundStyle(CodexPalette.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: CodexPalette.elevatedBackground, border: CodexPalette.softBorder, shadow: false)
    }
}
