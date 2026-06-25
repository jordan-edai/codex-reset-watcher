import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ResetCreditsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerCard

            ForEach(store.errorMessages, id: \.self) { message in
                errorBanner(message)
            }

            if store.usageWindows.isEmpty, store.credits.isEmpty, store.isRefreshing {
                loadingState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        resetSection

                        NudgeCardView(nudge: store.nudge)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(store.usageWindows) { window in
                                UsageLimitCardView(window: window)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            footer
        }
        .padding(16)
        .background(CodexPalette.appBackground)
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            HeaderArtworkView()
                .frame(width: 104, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Label(store.planLabel, systemImage: "terminal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.mutedText)

                Text("Codex Reset Watcher")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(DateFormatting.checked(store.lastChecked))
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)

                Text("Active: \(store.accountDisplayLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(store.availableCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(store.availableCount == 1 ? "reset banked" : "resets banked")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.secondaryText)
            }
        }
        .padding(12)
        .background(CodexPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CodexPalette.border)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reset Expiry")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Text("\(store.availableCount) available")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CodexPalette.secondaryText)
            }

            if store.credits.isEmpty, store.creditsErrorMessage == nil {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(store.credits.enumerated()), id: \.element.id) { index, credit in
                        CreditRowView(credit: credit, ordinal: index + 1)
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text("Checking the Codex fuel gauge...")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Fetching 5h, weekly, and reset-stash windows.")
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Label("Updates every 5 min", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(CodexPalette.secondaryText)

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label(store.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30))
                .foregroundStyle(CodexPalette.secondaryText)
            Text("No banked resets right now.")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Codex answered, but the reset stash is empty.")
                .font(.body)
                .foregroundStyle(CodexPalette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(CodexPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CodexPalette.border)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.24))
        }
    }
}

private struct HeaderArtworkView: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "UsageHeader", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [.cyan, .blue, .purple, .green.opacity(0.75), .orange.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct UsageLimitCardView: View {
    let window: UsageLimitDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(window.title, systemImage: iconName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            ProgressView(value: Double(window.remainingPercent ?? 0), total: 100)
                .tint(tint)
                .controlSize(.large)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Used")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(percentText(window.usedPercent))
                        .monospacedDigit()
                }
                GridRow {
                    Text("Resets")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.duration(seconds: window.window.resetAfterSeconds))
                }
                GridRow {
                    Text("At")
                        .foregroundStyle(CodexPalette.secondaryText)
                    Text(DateFormatting.weekdayCompact(window.window.resetDate))
                }
            }
            .font(.subheadline)
        }
        .padding(13)
        .background(CodexPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CodexPalette.border)
        }
        .shadow(color: .black.opacity(0.035), radius: 8, y: 1)
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
        guard let remaining = window.remainingPercent else {
            return .secondary
        }
        if remaining <= 15 {
            return .red
        }
        if remaining <= 30 {
            return .orange
        }
        return .green
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
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(nudge.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Text(nudge.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CodexPalette.secondaryText)
                        .lineLimit(1)
                }

                Text(nudge.message)
                    .font(.subheadline)
                    .foregroundStyle(CodexPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(CodexPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.32))
        }
        .shadow(color: .black.opacity(0.035), radius: 8, y: 1)
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

    private var tint: Color {
        switch nudge.tier {
        case .spend:
            return .green
        case .expiringReset:
            return CodexPalette.urgentRed
        case .deadline:
            return CodexPalette.warningOrange
        case .useIfBlocked:
            return .orange
        case .waitFiveHour, .hold:
            return .blue
        case .steady:
            return .teal
        case .noResets, .unavailable:
            return .secondary
        }
    }
}
