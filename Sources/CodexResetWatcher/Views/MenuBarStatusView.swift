import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    private static let visibleResetCreditLimit = 4

    @ObservedObject var store: ResetCreditsStore
    @ObservedObject var mainWindowController: MainWindowController
    @Binding var menuBarMetricRawValue: String
    @Binding var appearanceModeRawValue: String
    @Environment(\.openWindow) private var openWindow

    private var menuBarMetric: MenuBarMetric {
        MenuBarMetric(rawValue: menuBarMetricRawValue) ?? .weekly
    }

    private var menuBarMetricSelection: Binding<String> {
        Binding {
            menuBarMetric.rawValue
        } set: { newValue in
            menuBarMetricRawValue = MenuBarMetric(rawValue: newValue)?.rawValue ?? MenuBarMetric.weekly.rawValue
        }
    }

    private var appearanceModeSelection: Binding<String> {
        Binding {
            CodexAppearanceMode(rawValue: appearanceModeRawValue)?.rawValue ?? CodexAppearanceMode.auto.rawValue
        } set: { newValue in
            appearanceModeRawValue = CodexAppearanceMode(rawValue: newValue)?.rawValue ?? CodexAppearanceMode.auto.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header

            Divider()

            dynamicContent
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            footer
        }
        .padding(CodexStyle.Spacing.menuPadding)
        .frame(width: CodexStyle.Size.menuWidth)
        .background(CodexPalette.menuPopoverBackground)
    }

    private var dynamicContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(store.errorMessages, id: \.self) { message in
                errorRow(message)
            }

            displaySettingsSection

            Divider()

            currentLimitsSection
            resetRows

            Divider()

            nudgeRow
        }
    }

    private var footer: some View {
        HStack {
            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Spacer()

            Button("Open") {
                showMainWindow()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .controlSize(.small)
    }

    private var currentLimitsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            menuSectionHeader(MenuBarSection.currentLimits.rawValue, detail: currentLimitsDetail)

            if store.usageWindows.isEmpty {
                emptyLimitsRow
            } else {
                ForEach(store.usageWindows) { window in
                    limitRow(window)
                }
            }
        }
    }

    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            menuSectionHeader(MenuBarSection.displaySettings.rawValue)
            menuBarDisplayRow
            appearanceRow
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            CodexArtworkThumbnail(compact: true)
                .frame(width: CodexStyle.Size.menuArtworkWidth, height: CodexStyle.Size.menuArtworkHeight)

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex limits")
                    .font(CodexStyle.Typography.menuTitle)
                    .foregroundStyle(CodexPalette.primaryText)
                Text(DateFormatting.checked(store.lastChecked))
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                Text("Active: \(store.accountDisplayLabel)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 2) {
                Text(menuResetCountValue)
                    .font(.system(size: 27, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(CodexPalette.primaryText)
                Text(menuResetCountLabel)
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var menuBarDisplayRow: some View {
        HStack(spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: "menubar.rectangle", tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 2) {
                Text("Menu bar")
                    .font(CodexStyle.Typography.menuRowTitle)
                    .foregroundStyle(CodexPalette.primaryText)
                    .lineLimit(1)
                Text("Week or 5h in title")
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            CodexSegmentedPicker("Menu bar limit", selection: menuBarMetricSelection) {
                ForEach(MenuBarMetric.allCases) { metric in
                    Text(metric.pickerTitle)
                        .tag(metric.rawValue)
                }
            }
            .frame(width: CodexStyle.Size.menuControlWidth)
        }
        .codexRow(minHeight: 50)
    }

    private var appearanceRow: some View {
        HStack(spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: "circle.lefthalf.filled", tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 2) {
                Text("Appearance")
                    .font(CodexStyle.Typography.menuRowTitle)
                    .foregroundStyle(CodexPalette.primaryText)
                    .lineLimit(1)
                Text("Light, dark, or system")
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            CodexSegmentedPicker("Appearance", selection: appearanceModeSelection) {
                ForEach(CodexAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .frame(width: CodexStyle.Size.menuControlWidth)
        }
        .codexRow(minHeight: 50)
    }

    private func limitRow(_ window: UsageLimitDisplay) -> some View {
        return HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(
                systemName: window.kind == .weekly ? "calendar" : "clock",
                tone: limitTone(window),
                size: 24,
                symbolSize: CodexStyle.Icon.menu
            )
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 4) {
                Text(window.title)
                    .font(CodexStyle.Typography.menuRowTitle)
                    .lineLimit(1)
                Text(limitSubtitle(window))
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                LimitMeterView(
                    label: "\(window.title) remaining",
                    remainingPercent: window.remainingPercent,
                    tone: limitTone(window),
                    height: CodexStyle.Meter.menuHeight
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(limitMetricText(window))
                .font(CodexStyle.Typography.menuMetric)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: CodexStyle.Size.menuMetricColumn, alignment: .trailing)
        }
        .codexRow(isSelected: menuBarMetric.matches(window.kind), minHeight: 56)
    }

    private var resetRows: some View {
        VStack(alignment: .leading, spacing: 7) {
            menuSectionHeader(MenuBarSection.bankedResetsExpiration.rawValue, detail: resetCountDetail)

            ForEach(visibleResetCredits, id: \.element.id) { index, credit in
                resetExpiryRow(index: index, credit: credit)
            }

            ForEach(0..<missingVisibleResetCreditCount, id: \.self) { offset in
                missingResetExpiryRow(index: visibleResetCredits.count + offset)
            }

            if totalResetCreditCount > Self.visibleResetCreditLimit {
                moreResetsRow
            }

            if totalResetCreditCount == 0, store.creditsErrorMessage == nil {
                emptyResetRow
            }
        }
    }

    private func resetExpiryRow(index: Int, credit: ResetCreditDisplay) -> some View {
        let urgency = ResetExpiryUrgency.make(expiresAt: credit.expiresAt, isAvailable: credit.isAvailable)
        let tone = CodexTone.resetUrgency(urgency)

        return HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: resetIconName(for: urgency), tone: tone, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reset \(index + 1) expires:")
                    .font(CodexStyle.Typography.menuRowTitle)
                    .lineLimit(1)

                if let status = urgency.visibleExpiryStatus {
                    Text(status)
                        .font(CodexStyle.Typography.menuRowMeta)
                        .fontWeight(.semibold)
                        .foregroundStyle(tone.foreground)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text(DateFormatting.weekdayDate(credit.expiresAt))
                Text(DateFormatting.timeOnly(credit.expiresAt))
            }
            .font(CodexStyle.Typography.menuDate)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
        }
        .codexRow(minHeight: urgency.visibleExpiryStatus == nil ? 52 : 58)
    }

    private func missingResetExpiryRow(index: Int) -> some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: "calendar.badge.questionmark", tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            Text("Reset \(index + 1) expires:")
                .font(CodexStyle.Typography.menuRowTitle)
                .lineLimit(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("Expiry")
                Text("unavailable")
            }
            .font(CodexStyle.Typography.menuDate)
            .multilineTextAlignment(.trailing)
            .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
        }
        .codexRow(minHeight: 52)
    }

    private var moreResetsRow: some View {
        Button {
            showMainWindow()
        } label: {
            HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
                CodexIconBadge(systemName: "ellipsis", tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                    .frame(width: CodexStyle.Size.menuIconColumn)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(hiddenResetCreditCount) more reset \(hiddenResetCreditCount == 1 ? "credit" : "credits")")
                        .font(CodexStyle.Typography.menuRowTitle)
                        .foregroundStyle(CodexPalette.primaryText)
                        .lineLimit(1)

                    Text(hiddenResetCreditDetail)
                        .font(CodexStyle.Typography.menuRowMeta)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let nextHiddenExpiry {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(DateFormatting.weekdayDate(nextHiddenExpiry))
                        Text(DateFormatting.timeOnly(nextHiddenExpiry))
                    }
                    .font(CodexStyle.Typography.menuDate)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
                } else {
                    Text("Desktop")
                        .font(CodexStyle.Typography.menuRowMeta)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                        .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
                }
            }
        }
        .buttonStyle(.plain)
        .codexRow(minHeight: 50)
    }

    private var hiddenResetCreditCount: Int {
        max(0, totalResetCreditCount - Self.visibleResetCreditLimit)
    }

    private var nextHiddenExpiry: Date? {
        store.availableCreditDisplays.dropFirst(Self.visibleResetCreditLimit).first?.expiresAt
    }

    private var hiddenResetCreditDetail: String {
        if nextHiddenExpiry != nil {
            return "Next additional expiry"
        }
        return "Some dates unavailable"
    }

    private var totalResetCreditCount: Int {
        max(store.availableCreditDisplays.count, store.resetCountState.count ?? 0)
    }

    private var visibleResetRowCount: Int {
        min(totalResetCreditCount, Self.visibleResetCreditLimit)
    }

    private var visibleResetCredits: [(offset: Int, element: ResetCreditDisplay)] {
        Array(store.availableCreditDisplays.prefix(Self.visibleResetCreditLimit).enumerated())
    }

    private var missingVisibleResetCreditCount: Int {
        max(0, visibleResetRowCount - visibleResetCredits.count)
    }

    private func menuSectionHeader(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CodexStyle.Typography.menuRowMeta.weight(.semibold))
                .foregroundStyle(CodexPalette.secondaryText)

            Spacer()

            if let detail {
                Text(detail)
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }

    private var emptyLimitsRow: some View {
        HStack(alignment: .top, spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: "gauge.with.dots.needle.0percent", tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 2) {
                Text(emptyLimitsTitle)
                    .font(CodexStyle.Typography.menuRowTitle)
                    .foregroundStyle(CodexPalette.primaryText)
                    .lineLimit(1)

                Text(emptyLimitsDetail)
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .codexRow(minHeight: 50)
    }

    private var emptyLimitsTitle: String {
        switch store.liveState {
        case .loading:
            return "Checking current limits"
        case .signedOut:
            return "Sign in to Codex"
        case .partial, .failed:
            return "Current limits unavailable"
        case .live, .cached:
            return "No current limits shown"
        }
    }

    private var emptyLimitsDetail: String {
        switch store.liveState {
        case .loading:
            return "Waiting for Codex to respond."
        case .signedOut:
            return "Sign in, then refresh."
        case .partial, .failed:
            return "Refresh to try the live check again."
        case .live, .cached:
            return "Codex did not return a usable limit."
        }
    }

    private var currentLimitsDetail: String {
        switch store.liveState {
        case .loading:
            return "Checking"
        case .live:
            return "Live"
        case .partial:
            return "Partial"
        case .signedOut:
            return "Sign in required"
        case .failed:
            return "Unavailable"
        case .cached:
            return "Saved"
        }
    }

    private var menuResetCountValue: String {
        switch store.resetCountState {
        case .loading:
            return "..."
        case .unavailable:
            return "-"
        case let .known(count):
            return "\(count)"
        }
    }

    private var menuResetCountLabel: String {
        switch store.resetCountState {
        case .loading:
            return "checking reset credits"
        case .unavailable:
            return "reset count unavailable"
        case let .known(count):
            return count == 1 ? "reset credit available" : "reset credits available"
        }
    }

    private var resetCountDetail: String {
        switch store.resetCountState {
        case .loading:
            return "Checking"
        case .unavailable:
            return "Count unavailable"
        case let .known(count):
            return "\(count) available"
        }
    }

    private func resetIconName(for urgency: ResetExpiryUrgency) -> String {
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
            return "calendar.badge.questionmark"
        }
    }

    private var nudgeRow: some View {
        HStack(alignment: .top, spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: store.statusSymbolName, tone: nudgeTone, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.nudge.title)
                        .font(CodexStyle.Typography.menuRowTitle)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(store.nudge.detail)
                        .font(CodexStyle.Typography.menuRowMeta)
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                Text(store.nudge.message)
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .codexRow(background: nudgeTone.background, border: nudgeTone.border, minHeight: 66)
    }

    private var nudgeTone: CodexTone {
        switch store.nudge.tier {
        case .spend:
            return .success
        case .blocked, .expiringReset:
            return .danger
        case .deadline, .useIfBlocked:
            return .warning
        case .waitFiveHour, .hold, .steady:
            return .neutral
        case .noResets, .unavailable:
            return .muted
        }
    }

    private var emptyResetRow: some View {
        HStack(spacing: CodexStyle.Spacing.rowGap) {
            CodexIconBadge(systemName: emptyResetIconName, tone: .muted, size: 24, symbolSize: CodexStyle.Icon.menu)
                .frame(width: CodexStyle.Size.menuIconColumn)

            VStack(alignment: .leading, spacing: 2) {
                Text(emptyResetTitle)
                    .font(CodexStyle.Typography.menuRowTitle)
                    .foregroundStyle(CodexPalette.primaryText)

                Text(emptyResetDetail)
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .codexRow(minHeight: 48)
    }

    private var emptyResetIconName: String {
        switch store.resetCountState {
        case .loading:
            return "arrow.clockwise"
        case .unavailable:
            return "questionmark.circle"
        case .known:
            return "checkmark.seal"
        }
    }

    private var emptyResetTitle: String {
        switch store.resetCountState {
        case .loading:
            return "Checking reset credits"
        case .unavailable:
            return "Reset count unavailable"
        case .known:
            return "No reset credits available"
        }
    }

    private var emptyResetDetail: String {
        switch store.resetCountState {
        case .loading:
            return "Waiting for Codex to respond."
        case .unavailable:
            return "Refresh to try again."
        case .known:
            return "Codex reported none."
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CodexIconBadge(systemName: "exclamationmark.triangle.fill", tone: .warning, size: 24, symbolSize: 13)
                .frame(width: CodexStyle.Size.menuIconColumn)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(CodexPalette.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .codexRow(background: CodexTone.warning.background, border: CodexTone.warning.border, minHeight: 50)
    }

    private func limitTone(_ window: UsageLimitDisplay) -> CodexTone {
        if window.limitReached {
            return .danger
        }
        return CodexTone.usage(remainingPercent: window.remainingPercent)
    }

    private func limitMetricText(_ window: UsageLimitDisplay) -> String {
        if window.limitReached {
            return "Blocked"
        }
        return remainingText(window.remainingPercent)
    }

    private func limitSubtitle(_ window: UsageLimitDisplay) -> String {
        if window.limitReached {
            return "Blocked · \(resetText(window))"
        }
        if menuBarMetric.matches(window.kind) {
            return "Menu bar · \(selectedResetText(window))"
        }
        return resetText(window)
    }

    private func remainingText(_ value: Int?) -> String {
        guard let value else {
            return "Unknown"
        }
        return "\(value)% left"
    }

    private func resetText(_ window: UsageLimitDisplay) -> String {
        if let resetDate = window.window.resetDate {
            return "Resets \(DateFormatting.weekdayDate(resetDate)), \(DateFormatting.timeOnly(resetDate))"
        }
        guard let seconds = window.window.resetAfterSeconds else {
            return "Reset time unavailable"
        }
        let duration = DateFormatting.duration(seconds: seconds)
        return duration == "now" ? "Resets now" : "Resets in \(duration)"
    }

    private func selectedResetText(_ window: UsageLimitDisplay) -> String {
        guard let resetDate = window.window.resetDate else {
            guard let seconds = window.window.resetAfterSeconds else {
                return "reset time unavailable"
            }
            let duration = DateFormatting.duration(seconds: seconds)
            return duration == "now" ? "resets now" : "resets in \(duration)"
        }

        switch window.kind {
        case .weekly:
            return "resets \(DateFormatting.weekdayName(resetDate))"
        case .fiveHour:
            return "resets \(DateFormatting.timeOnly(resetDate))"
        case .generic:
            return "resets \(DateFormatting.weekdayDate(resetDate))"
        }
    }

    private func showMainWindow() {
        mainWindowController.show {
            openWindow(id: "main")
        }
    }
}
