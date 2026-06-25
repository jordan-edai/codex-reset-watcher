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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex limits")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(DateFormatting.checked(store.lastChecked))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text("Active: \(store.accountDisplayLabel)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ForEach(store.errorMessages, id: \.self) { message in
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label("Menu bar", systemImage: "menubar.rectangle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CodexPalette.primaryText)

                Spacer()

                Picker("Menu bar display", selection: menuBarMetricSelection) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.pickerTitle)
                            .tag(metric.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 132)
            }
            .menuRow(isSelected: false)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.usageWindows) { window in
                    limitRow(window)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: store.statusSymbolName)
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(store.nudge.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                }

                ForEach(Array(store.availableCredits.prefix(4).enumerated()), id: \.element.id) { index, credit in
                    resetExpiryRow(index: index, credit: credit)
                }

                if store.availableCredits.isEmpty, store.creditsErrorMessage == nil {
                    Text("No available resets")
                        .font(.body)
                        .foregroundStyle(CodexPalette.secondaryText)
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
        .padding(14)
        .frame(width: 360)
        .background(CodexPalette.menuPopoverBackground)
    }

    private func limitRow(_ window: UsageLimitDisplay) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: window.kind == .weekly ? "calendar" : "clock")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(CodexPalette.secondaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(resetText(window))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CodexPalette.secondaryText)
            }

            Spacer(minLength: 10)

            if menuBarMetric.matches(window.kind) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CodexPalette.secondaryText)
            }

            Text(remainingText(window.remainingPercent))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
        }
        .menuRow(isSelected: menuBarMetric.matches(window.kind))
    }

    private func resetExpiryRow(index: Int, credit: ResetCredit) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(CodexPalette.secondaryText)

            Text("Reset \(index + 1) expires:")
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: 10)

            Text(DateFormatting.weekdayCompact(credit.expiresAt))
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
        }
        .menuRow(isSelected: false)
    }

    private func remainingText(_ value: Int?) -> String {
        guard let value else {
            return "Unknown"
        }
        return "\(value)% left"
    }

    private func resetText(_ window: UsageLimitDisplay) -> String {
        if let resetDate = window.window.resetDate {
            return "Resets: \(DateFormatting.weekdayCompact(resetDate))"
        }
        return "Resets in \(DateFormatting.duration(seconds: window.window.resetAfterSeconds))"
    }
}

private extension View {
    func menuRow(isSelected: Bool) -> some View {
        self
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                isSelected ? CodexPalette.menuAccentBackground : CodexPalette.menuRowBackground,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(CodexPalette.softBorder)
            }
    }
}
