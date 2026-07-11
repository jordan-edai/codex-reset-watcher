import SwiftUI

struct AccountDetailView: View {
    let detail: AccountDetailState
    let cachedAccountCount: Int
    @Binding var appearanceModeRawValue: String
    let onRefresh: () -> Void
    let onForget: (AccountSnapshotID) -> Void
    let onClearStale: () -> Void
    let onClearCached: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.desktopSection) {
            headerCard

            if detail.isCached {
                snapshotBanner
            }

            ForEach(detail.errorMessages, id: \.self) { message in
                errorBanner(message)
            }

            if detail.usageWindows.isEmpty, detail.credits.isEmpty, detail.liveState == .loading {
                loadingState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CodexStyle.Spacing.desktopStack) {
                        NudgeCardView(nudge: detail.nudge)

                        if !detail.usageWindows.isEmpty {
                            usageSection
                        }

                        resetSection
                    }
                    .padding(.vertical, 2)
                }
            }

            footer
        }
        .padding(CodexStyle.Spacing.desktopPage)
        .background(CodexPalette.appBackground)
    }

    private var headerCard: some View {
        HStack(spacing: 10) {
            CodexArtworkThumbnail()
                .frame(width: CodexStyle.Size.compactArtworkWidth, height: CodexStyle.Size.compactArtworkHeight)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Label(detail.planLabel, systemImage: "terminal.fill")
                        .font(CodexStyle.Typography.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(CodexPalette.mutedText)
                        .labelStyle(.titleAndIcon)

                    Text("Codex Reset Watcher")
                        .font(CodexStyle.Typography.appTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Text("\(detail.statusDetail) · \(detail.isActive ? "Active" : "Account"): \(detail.accountLabel)")
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(resetCountValue)
                    .font(CodexStyle.Typography.largeMetric)
                    .monospacedDigit()
                Text(resetCountLabel)
                    .font(CodexStyle.Typography.caption)
                    .foregroundStyle(CodexPalette.secondaryText)
            }
            .padding(.horizontal, 4)
        }
        .padding(CodexStyle.Spacing.densePanel)
        .codexPanel(background: CodexPalette.cardBackground, border: CodexPalette.softBorder)
    }

    private var resetCountLabel: String {
        switch detail.resetCountState {
        case .loading:
            return "checking reset credits"
        case .unavailable:
            return "reset count unavailable"
        case let .known(count):
            let noun = count == 1 ? "reset credit" : "reset credits"
            return detail.isCached ? "\(noun) last seen" : "\(noun) available"
        }
    }

    private var resetCountValue: String {
        switch detail.resetCountState {
        case .loading:
            return "..."
        case .unavailable:
            return "-"
        case let .known(count):
            return "\(count)"
        }
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
                Text(detail.isStale ? "This saved reset time has passed. Refresh checks the account currently signed in to Codex." : "This saved snapshot does not update live. Refresh checks the account currently signed in to Codex.")
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
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.desktopStack) {
            CodexSectionHeader(title: "Current limits", detail: detail.isCached ? "Last saved values" : "Live from Codex")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: CodexStyle.Spacing.desktopStack)], spacing: CodexStyle.Spacing.desktopStack) {
                ForEach(detail.usageWindows) { window in
                    UsageLimitCardView(window: window, isCached: detail.isCached)
                }
            }
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: CodexStyle.Spacing.desktopStack) {
            CodexSectionHeader(
                title: "Reset credits",
                detail: resetSectionDetail
            )

            if !hasResetRows {
                emptyState
            } else {
                LazyVStack(spacing: 6) {
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
        guard let count = detail.resetCountState.count else {
            return 0
        }
        return max(0, count - detail.credits.count)
    }

    private var resetSectionDetail: String {
        switch detail.resetCountState {
        case .loading:
            return "Checking availability"
        case .unavailable:
            return "Count unavailable"
        case let .known(count):
            return "\(count) \(detail.isCached ? "last seen" : "available")"
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("Checking Codex usage...")
                .font(CodexStyle.Typography.sectionTitle)
            Text("Loading current limits and reset credits.")
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

            CodexSegmentedPicker("Appearance", selection: appearanceModeSelection) {
                ForEach(CodexAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .frame(width: 184)

            if hasSnapshotActions {
                Menu {
                    if detail.canForget, let snapshotID = detail.snapshotID {
                        Button {
                            onForget(snapshotID)
                        } label: {
                            Label(detail.isStale ? "Forget stale snapshot" : "Forget this snapshot", systemImage: "trash")
                        }
                    }

                    if detail.staleSnapshotCount > 0 {
                        Button {
                            onClearStale()
                        } label: {
                            Label("Clear stale snapshots", systemImage: "clock.badge.exclamationmark")
                        }
                    }

                    if cachedAccountCount > 0 {
                        Button {
                            onClearCached()
                        } label: {
                            Label("Clear all cached snapshots", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Label("Snapshots", systemImage: "archivebox")
                }
            }

            Button {
                onRefresh()
            } label: {
                Label(detail.isRefreshing ? "Refreshing" : detail.refreshActionTitle, systemImage: "arrow.clockwise")
            }
            .disabled(!detail.canRefresh || detail.isRefreshing)
        }
        .controlSize(.small)
    }

    private var footerStatus: String {
        if detail.isCached {
            return "Cached snapshot"
        }
        return "Updates every 5 min"
    }

    private var hasSnapshotActions: Bool {
        detail.canForget || detail.staleSnapshotCount > 0 || cachedAccountCount > 0
    }

    private var appearanceModeSelection: Binding<String> {
        Binding {
            CodexAppearanceMode(rawValue: appearanceModeRawValue)?.rawValue ?? CodexAppearanceMode.auto.rawValue
        } set: { newValue in
            appearanceModeRawValue = CodexAppearanceMode(rawValue: newValue)?.rawValue ?? CodexAppearanceMode.auto.rawValue
        }
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
            return "No reset-credit dates saved."
        }
        if detail.resetCountState == .loading {
            return "Checking reset credits..."
        }
        if detail.resetCountState == .unavailable {
            return "Reset-credit details are unavailable."
        }
        if !detail.errorMessages.isEmpty {
            return "Reset-credit dates are unavailable."
        }
        return "No reset credits available."
    }

    private var emptyStateDetail: String {
        if detail.isCached {
            return "This snapshot did not include expiry dates for its reset credits."
        }
        if detail.liveState == .signedOut {
            return "Sign in to Codex, then refresh."
        }
        if !detail.errorMessages.isEmpty {
            return "Codex did not return reset-credit details. Try Refresh."
        }
        return "Codex reports no available reset credits."
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
            background: CodexTone.warning.background,
            border: CodexTone.warning.border,
            shadow: false
        )
    }

}

private struct UsageLimitCardView: View {
    let window: UsageLimitDisplay
    let isCached: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 9) {
                    CodexIconBadge(systemName: iconName, tone: tone, size: CodexStyle.Size.smallIconBadge)
                    Text(window.title)
                        .font(CodexStyle.Typography.cardTitle)
                }
                Spacer()
                if window.limitReached {
                    CodexStatusBadge(text: "Limit reached", tone: .danger, filled: true)
                }
                Text(percentText(window.remainingPercent))
                    .font(CodexStyle.Typography.cardMetric)
                    .monospacedDigit()
            }

            LimitMeterView(label: "\(window.title) remaining", remainingPercent: window.remainingPercent, tone: tone)

            Grid(alignment: .leading, horizontalSpacing: 11, verticalSpacing: 1) {
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
        .padding(CodexStyle.Spacing.densePanel)
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

    private var tone: CodexTone {
        if window.limitReached {
            return .danger
        }
        return CodexTone.usage(remainingPercent: window.remainingPercent)
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

private struct NudgeCardView: View {
    let nudge: UsageNudge

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CodexIconBadge(
                systemName: iconName,
                tone: tone,
                size: CodexStyle.Size.smallIconBadge,
                symbolSize: CodexStyle.Icon.badge
            )

            VStack(alignment: .leading, spacing: 2) {
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CodexStyle.Spacing.densePanel)
        .codexPanel(background: tone.background, border: tone.border, shadow: false)
    }

    private var iconName: String {
        switch nudge.tier {
        case .spend:
            return "bolt.fill"
        case .blocked:
            return "exclamationmark.octagon.fill"
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
        case .blocked, .expiringReset:
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
