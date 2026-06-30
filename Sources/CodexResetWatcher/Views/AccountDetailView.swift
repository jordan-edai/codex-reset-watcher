import SwiftUI

struct AccountDetailView: View {
    let detail: AccountDetailState
    let cachedAccountCount: Int
    let onRefresh: () -> Void
    let onForget: (AccountSnapshotID) -> Void
    let onClearStale: () -> Void
    let onClearCached: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.section) {
            headerCard

            if detail.isCached {
                snapshotBanner
            }

            ForEach(detail.errorMessages, id: \.self) { message in
                errorBanner(message)
            }

            if detail.usageWindows.isEmpty, detail.credits.isEmpty, detail.isRefreshing {
                loadingState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CodexStyle.Spacing.stack) {
                        resetSection
                        NudgeCardView(nudge: detail.nudge)

                        if !detail.usageWindows.isEmpty {
                            usageSection
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            footer
        }
        .padding(CodexStyle.Spacing.page)
        .background(CodexPalette.appBackground)
    }

    private var headerCard: some View {
        HStack(spacing: 13) {
            CodexArtworkThumbnail()
                .frame(width: CodexStyle.Size.artworkWidth, height: CodexStyle.Size.artworkHeight)

            VStack(alignment: .leading, spacing: 5) {
                Label(detail.planLabel, systemImage: "terminal.fill")
                    .font(CodexStyle.Typography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(CodexPalette.mutedText)

                Text("Codex Reset Watcher")
                    .font(CodexStyle.Typography.appTitle)

                Text(detail.statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)

                Text("\(detail.isActive ? "Active" : "Account"): \(detail.accountLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(detail.availableCount)")
                    .font(CodexStyle.Typography.largeMetric)
                    .monospacedDigit()
                Text(resetCountLabel)
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
            }
            .padding(.horizontal, 4)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: CodexPalette.cardBackground, border: CodexPalette.softBorder)
    }

    private var resetCountLabel: String {
        let plural = detail.availableCount == 1 ? "reset" : "resets"
        return detail.isCached ? "\(plural) last seen" : "\(plural) banked"
    }

    private var snapshotBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            CodexIconBadge(
                systemName: detail.isStale ? "clock.badge.exclamationmark" : "clock.arrow.circlepath",
                tone: detail.isStale ? .warning : .neutral,
                size: CodexStyle.Size.iconBadge,
                symbolSize: CodexStyle.Icon.content
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.statusTitle)
                    .font(CodexStyle.Typography.cardTitle)
                Text(detail.isStale ? "The displayed reset window has passed. Sign into this Codex account to refresh it." : "This is a local snapshot. Sign into this Codex account to refresh it.")
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(
            background: detail.isStale ? CodexTone.warning.background : CodexTone.neutral.background,
            border: detail.isStale ? CodexTone.warning.border : CodexTone.neutral.border,
            shadow: false
        )
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.stack) {
            CodexSectionHeader(title: "Usage windows", detail: detail.isCached ? "Cached last-seen limits" : "Live limits")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CodexStyle.Spacing.panel) {
                ForEach(detail.usageWindows) { window in
                    UsageLimitCardView(window: window, isCached: detail.isCached)
                }
            }
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.stack) {
            CodexSectionHeader(
                title: "Reset expiry",
                detail: "\(detail.availableCount) \(detail.isCached ? "last seen" : "available")"
            )

            if !hasResetRows {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(detail.credits.enumerated()), id: \.element.id) { index, credit in
                        CreditRowView(credit: credit, ordinal: index + 1)
                    }
                    ForEach(0..<missingCreditCount, id: \.self) { offset in
                        MissingResetExpiryRowView(ordinal: detail.credits.count + offset + 1)
                    }
                }
            }
        }
    }

    private var hasResetRows: Bool {
        !detail.credits.isEmpty || missingCreditCount > 0
    }

    private var missingCreditCount: Int {
        max(0, detail.availableCount - detail.credits.count)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("Checking the Codex fuel gauge...")
                .font(CodexStyle.Typography.sectionTitle)
            Text("Fetching 5h, weekly, and reset-stash windows.")
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Label(footerStatus, systemImage: detail.isCached ? "clock.arrow.circlepath" : "clock")
                .font(.subheadline)
                .foregroundStyle(CodexPalette.secondaryText)

            Spacer()

            if detail.canForget, let snapshotID = detail.snapshotID {
                Button {
                    onForget(snapshotID)
                } label: {
                    Label(detail.isStale ? "Forget stale" : "Forget snapshot", systemImage: "trash")
                }
            }

            if detail.staleSnapshotCount > 0 {
                Button {
                    onClearStale()
                } label: {
                    Label("Clear stale", systemImage: "clock.badge.exclamationmark")
                }
            }

            if detail.isCached, cachedAccountCount > 0 {
                Button {
                    onClearCached()
                } label: {
                    Label("Clear cached", systemImage: "xmark.circle")
                }
            }

            Button {
                onRefresh()
            } label: {
                Label(detail.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(!detail.canRefresh || detail.isRefreshing)
        }
    }

    private var footerStatus: String {
        if detail.isCached {
            return "Cached snapshot"
        }
        return "Updates every 5 min"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30))
                .foregroundStyle(CodexPalette.secondaryText)
                .accessibilityHidden(true)
            Text(emptyStateTitle)
                .font(CodexStyle.Typography.sectionTitle)
            Text(emptyStateDetail)
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .codexPanel(shadow: false)
    }

    private var emptyStateTitle: String {
        if detail.isCached {
            return "No reset expiries saved."
        }
        if !detail.errorMessages.isEmpty {
            return "Reset expiries unavailable."
        }
        return "No banked resets right now."
    }

    private var emptyStateDetail: String {
        if detail.isCached {
            return "This snapshot did not include reset-credit expiry rows."
        }
        if !detail.errorMessages.isEmpty {
            return "Reset stash did not refresh. Try again in a bit."
        }
        return "Codex answered, but the reset stash is empty."
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CodexPalette.warningOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .foregroundStyle(CodexPalette.primaryText)
                .lineLimit(3)
        }
        .padding(CodexStyle.Spacing.rowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codexPanel(
            background: CodexPalette.warningOrange.opacity(0.10),
            border: CodexPalette.warningOrange.opacity(0.24),
            shadow: false
        )
    }

}

private struct UsageLimitCardView: View {
    let window: UsageLimitDisplay
    let isCached: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 9) {
                    CodexIconBadge(systemName: iconName, tone: tone, size: CodexStyle.Size.smallIconBadge)
                    Text(window.title)
                        .font(CodexStyle.Typography.cardTitle)
                }
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(CodexStyle.Typography.cardMetric)
                    .monospacedDigit()
            }

            LimitMeterView(label: "\(window.title) remaining", remainingPercent: window.remainingPercent, tint: tint)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text(isCached ? "Last seen used" : "Used")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(percentText(window.usedPercent))
                        .monospacedDigit()
                }
                GridRow {
                    Text(resetDurationLabel)
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(resetDurationValue)
                }
                GridRow {
                    Text(isCached ? "Cached reset at" : "Resets at")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(resetDateValue)
                }
            }
            .font(CodexStyle.Typography.caption)
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: CodexPalette.elevatedBackground, border: CodexPalette.softBorder, shadow: false)
    }

    private var iconName: String {
        switch window.kind {
        case .fiveHour:
            return "clock"
        case .weekly:
            return "calendar"
        case .generic:
            return "gauge"
        }
    }

    private var tint: Color {
        tone.foreground
    }

    private var tone: CodexTone {
        CodexTone.usage(remainingPercent: window.remainingPercent)
    }

    private var resetDurationLabel: String {
        guard window.window.resetAfterSeconds != nil else {
            return isCached ? "Cached reset" : "Resets"
        }
        if isCached {
            return resetDurationValue == "passed" ? "Cached reset" : "Cached reset in"
        }
        return resetDurationValue == "now" ? "Resets" : "Resets in"
    }

    private var resetDurationValue: String {
        guard window.window.resetAfterSeconds != nil else {
            return "Unavailable"
        }
        let duration = DateFormatting.duration(seconds: window.window.resetAfterSeconds)
        if isCached, duration == "now" {
            return "passed"
        }
        return duration
    }

    private var resetDateValue: String {
        guard window.window.resetDate != nil else {
            return "Unavailable"
        }
        return DateFormatting.weekdayCompact(window.window.resetDate)
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)%"
    }
}

private struct LimitMeterView: View {
    let label: String
    let remainingPercent: Int?
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .fill(CodexPalette.meterTrack)
                RoundedRectangle(cornerRadius: CodexStyle.Radius.pill, style: .continuous)
                    .fill(tint)
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: CodexStyle.Meter.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(remainingPercent.map { "\($0)%" } ?? "Unknown")
    }

    private var clampedValue: CGFloat {
        let value = CGFloat(max(0, min(100, remainingPercent ?? 0)))
        return value / 100
    }
}

private struct NudgeCardView: View {
    let nudge: UsageNudge

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CodexIconBadge(
                systemName: iconName,
                tone: tone,
                size: CodexStyle.Size.iconBadge,
                symbolSize: CodexStyle.Icon.content
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(nudge.title)
                        .font(CodexStyle.Typography.cardTitle)
                    Spacer()
                    Text(nudge.detail)
                        .font(CodexStyle.Typography.caption)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                Text(nudge.message)
                    .font(CodexStyle.Typography.body)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CodexStyle.Spacing.panel)
        .codexPanel(background: tone.background, border: tone.border, shadow: false)
    }

    private var iconName: String {
        switch nudge.tier {
        case .spend:
            return "bolt.fill"
        case .expiringReset:
            return "exclamationmark.octagon.fill"
        case .deadline:
            return "bolt.badge.clock"
        case .useIfBlocked:
            return "bolt.badge.clock"
        case .waitFiveHour:
            return "hourglass"
        case .hold:
            return "shield.fill"
        case .steady:
            return "gauge"
        case .noResets:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    private var tone: CodexTone {
        switch nudge.tier {
        case .spend:
            return .success
        case .expiringReset:
            return .danger
        case .deadline:
            return .warning
        case .useIfBlocked:
            return .warning
        case .waitFiveHour, .hold, .steady:
            return .neutral
        case .noResets, .unavailable:
            return .muted
        }
    }
}
