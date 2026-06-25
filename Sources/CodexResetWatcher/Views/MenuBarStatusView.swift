import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var store: ResetCreditsStore
    @Binding var menuBarMetricRawValue: String
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ForEach(store.errorMessages, id: \.self) { message in
                errorRow(message)
            }

            HStack(spacing: 10) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: CodexStyle.Size.menuIconColumn)
                    .foregroundStyle(CodexPalette.secondaryText)

                Label("Menu bar", systemImage: "menubar.rectangle")
                    .labelStyle(.titleOnly)
                    .font(CodexStyle.Typography.menuRowTitle)
                    .foregroundStyle(CodexPalette.primaryText)
                    .lineLimit(1)

                Spacer()

                Picker("Menu bar display", selection: menuBarMetricSelection) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.pickerTitle)
                            .tag(metric.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: CodexStyle.Size.menuControlWidth)
            }
            .codexRow(minHeight: 44)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.usageWindows) { window in
                    limitRow(window)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                nudgeRow

                ForEach(Array(store.availableCreditDisplays.prefix(4).enumerated()), id: \.element.id) { index, credit in
                    resetExpiryRow(index: index, credit: credit)
                }

                if store.availableCreditDisplays.isEmpty, store.creditsErrorMessage == nil {
                    emptyResetRow
                }
            }

            if !store.cachedSnapshots.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Other accounts")
                        .font(CodexStyle.Typography.menuRowMeta.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryText)
                        .padding(.horizontal, 2)

                    ForEach(store.cachedSnapshots.prefix(3)) { snapshot in
                        cachedAccountRow(snapshot)
                    }
                }
            }

            Divider()

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
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(CodexStyle.Spacing.menuPadding)
        .frame(width: CodexStyle.Size.menuWidth)
        .background(CodexPalette.menuPopoverBackground)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.panel) {
            HeaderArtworkView()
                .frame(width: CodexStyle.Size.menuArtworkWidth, height: CodexStyle.Size.menuArtworkHeight)
                .clipShape(RoundedRectangle(cornerRadius: CodexStyle.Radius.artwork, style: .continuous))

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

            Spacer(minLength: 12)

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.top, 1)
    }

    private func limitRow(_ window: UsageLimitDisplay) -> some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            Image(systemName: window.kind == .weekly ? "calendar" : "clock")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: CodexStyle.Size.menuIconColumn)
                .foregroundStyle(CodexPalette.primaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .font(CodexStyle.Typography.menuRowTitle)
                    .lineLimit(1)
                Text(resetText(window))
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(remainingText(window.remainingPercent))
                .font(CodexStyle.Typography.menuMetric)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: CodexStyle.Size.menuMetricColumn, alignment: .trailing)
        }
        .codexRow(isSelected: menuBarMetric.matches(window.kind))
    }

    private func resetExpiryRow(index: Int, credit: ResetCreditDisplay) -> some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: CodexStyle.Size.menuIconColumn)
                .foregroundStyle(credit.isAvailable ? CodexPalette.availableGreen : CodexPalette.secondaryText)

            Text("Reset \(index + 1) expires:")
                .font(CodexStyle.Typography.menuRowTitle)
                .lineLimit(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(DateFormatting.weekdayDate(credit.expiresAt))
                Text(DateFormatting.timeOnly(credit.expiresAt))
            }
            .font(CodexStyle.Typography.menuDate)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
        }
        .codexRow(minHeight: 54)
    }

    private func cachedAccountRow(_ snapshot: CodexAccountSnapshot) -> some View {
        Button {
            store.selectCachedAccount(snapshot.id)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
                Image(systemName: snapshot.isStale() ? "clock.badge.exclamationmark" : "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: CodexStyle.Size.menuIconColumn)
                    .foregroundStyle(snapshot.isStale() ? CodexPalette.warningOrange : CodexPalette.secondaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.effectiveLabel)
                        .font(CodexStyle.Typography.menuRowTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(snapshot.isStale() ? "Stale snapshot" : "Cached snapshot")
                        .font(CodexStyle.Typography.menuRowMeta)
                        .foregroundStyle(snapshot.isStale() ? CodexPalette.warningOrange : CodexPalette.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Text(DateFormatting.timeOnly(snapshot.lastChecked))
                    .font(CodexStyle.Typography.menuRowMeta)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
                    .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
            }
        }
        .buttonStyle(.plain)
        .codexRow(minHeight: 48)
    }

    private var nudgeRow: some View {
        HStack(alignment: .center, spacing: CodexStyle.Spacing.rowGap) {
            Image(systemName: store.statusSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: CodexStyle.Size.menuIconColumn)
                .foregroundStyle(nudgeTint)

            Text(store.nudge.title)
                .font(CodexStyle.Typography.menuRowTitle)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(store.nudge.detail)
                .font(CodexStyle.Typography.menuRowMeta)
                .foregroundStyle(CodexPalette.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: CodexStyle.Size.menuDateColumn, alignment: .trailing)
        }
        .codexRow(minHeight: 44)
    }

    private var nudgeTint: Color {
        switch store.nudge.tier {
        case .spend:
            return CodexPalette.availableGreen
        case .expiringReset:
            return CodexPalette.urgentRed
        case .deadline, .useIfBlocked:
            return CodexPalette.warningOrange
        case .waitFiveHour, .hold, .steady:
            return CodexPalette.accent
        case .noResets, .unavailable:
            return CodexPalette.secondaryText
        }
    }

    private var emptyResetRow: some View {
        HStack(spacing: CodexStyle.Spacing.rowGap) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: CodexStyle.Size.menuIconColumn)
                .foregroundStyle(CodexPalette.secondaryText)

            Text("No available resets")
                .font(CodexStyle.Typography.menuRowTitle)
                .foregroundStyle(CodexPalette.secondaryText)

            Spacer()
        }
        .codexRow(minHeight: 44)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: CodexStyle.Size.menuIconColumn)
                .foregroundStyle(CodexPalette.warningOrange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(CodexPalette.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .codexRow(background: CodexPalette.warningOrange.opacity(0.10), border: CodexPalette.warningOrange.opacity(0.24), minHeight: 44)
    }

    private func remainingText(_ value: Int?) -> String {
        guard let value else {
            return "Unknown"
        }
        return "\(value)% left"
    }

    private func resetText(_ window: UsageLimitDisplay) -> String {
        if let resetDate = window.window.resetDate {
            return "Resets: \(DateFormatting.weekdayDate(resetDate)) at \(DateFormatting.timeOnly(resetDate))"
        }
        return "Resets in \(DateFormatting.duration(seconds: window.window.resetAfterSeconds))"
    }
}
