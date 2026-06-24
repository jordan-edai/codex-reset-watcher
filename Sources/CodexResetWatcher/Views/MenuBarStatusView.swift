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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex limits")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(DateFormatting.checked(store.lastChecked))
                        .font(.subheadline)
                        .foregroundStyle(CodexPalette.secondaryText)
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
                    .font(.callout)
                    .foregroundStyle(CodexPalette.secondaryText)

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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.usageWindows) { window in
                    HStack {
                        Image(systemName: window.kind == .weekly ? "calendar" : "clock")
                            .foregroundStyle(CodexPalette.secondaryText)
                        Text(window.title)
                            .font(.callout)
                        Spacer()
                        if menuBarMetric.matches(window.kind) {
                            Image(systemName: "menubar.rectangle")
                                .font(.caption)
                                .foregroundStyle(CodexPalette.secondaryText)
                        }
                        Text(remainingText(window.remainingPercent))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
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

                ForEach(store.availableCredits.prefix(4)) { credit in
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(CodexPalette.secondaryText)
                        Text(DateFormatting.compact(credit.expiresAt))
                            .font(.body.weight(.medium))
                        Spacer()
                    }
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
        .frame(width: 330)
    }

    private func remainingText(_ value: Int?) -> String {
        guard let value else {
            return "Unknown"
        }
        return "\(value)% left"
    }
}
