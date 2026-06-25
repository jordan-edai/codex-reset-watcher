import Foundation

@MainActor
final class ResetCreditsStore: ObservableObject {
    @Published private(set) var credits: [ResetCredit] = []
    @Published private(set) var availableCount = 0
    @Published private(set) var usage: CodexUsageResponse?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var creditsErrorMessage: String?
    @Published private(set) var usageErrorMessage: String?
    @Published private(set) var accountIdentity = CodexAccountIdentity(accountId: nil, email: nil, name: nil)

    private let client: CodexAPIClient
    private var refreshTask: Task<Void, Never>?

    init(client: CodexAPIClient = CodexAPIClient()) {
        self.client = client
    }

    var availableCredits: [ResetCredit] {
        credits.filter(\.isAvailable)
    }

    var menuBarTitle: String {
        menuBarTitle(for: .weekly)
    }

    func menuBarTitle(for metric: MenuBarMetric) -> String {
        if let window = usageWindow(for: metric),
           let remaining = window.remainingPercent {
            return "\(remaining)% | \(menuBarResetCue(for: metric, window: window.window))"
        }
        return resetFallbackTitle
    }

    func usageWindow(for metric: MenuBarMetric) -> UsageLimitDisplay? {
        usageWindows.first { metric.matches($0.kind) }
    }

    private var resetFallbackTitle: String {
        "\(availableCount) reset\(availableCount == 1 ? "" : "s")"
    }

    private func menuBarResetCue(for metric: MenuBarMetric, window: UsageLimitWindow) -> String {
        guard let resetDate = resetDate(for: window) else {
            return metric.fallbackCue
        }

        switch metric {
        case .weekly:
            return DateFormatting.weekdayName(resetDate)
        case .fiveHour:
            return DateFormatting.timeOnly(resetDate)
        }
    }

    private func resetDate(for window: UsageLimitWindow) -> Date? {
        if let resetDate = window.resetDate {
            return resetDate
        }
        guard let seconds = window.resetAfterSeconds else {
            return nil
        }
        return Date().addingTimeInterval(TimeInterval(max(0, seconds)))
    }

    var statusSymbolName: String {
        if !errorMessages.isEmpty, usage == nil, credits.isEmpty {
            return "exclamationmark.triangle"
        }

        switch nudge.tier {
        case .spend, .expiringReset, .deadline, .useIfBlocked:
            return "bolt.circle"
        case .waitFiveHour:
            return "hourglass.circle"
        case .hold:
            return "shield"
        case .steady, .noResets, .unavailable:
            return "arrow.clockwise.circle"
        }
    }

    var usageWindows: [UsageLimitDisplay] {
        guard let rateLimit = usage?.rateLimit else {
            return []
        }

        var windows: [UsageLimitDisplay] = []
        if let primary = rateLimit.primaryWindow {
            windows.append(display(for: primary, fallbackID: "primary", limitReached: rateLimit.limitReached == true))
        }
        if let secondary = rateLimit.secondaryWindow {
            windows.append(display(for: secondary, fallbackID: "secondary", limitReached: rateLimit.limitReached == true))
        }
        return windows
    }

    var nudge: UsageNudge {
        UsageNudge.make(
            windows: usageWindows,
            resetCount: availableCount,
            resetUrgencies: resetUrgencies
        )
    }

    var errorMessages: [String] {
        [usageErrorMessage, creditsErrorMessage].compactMap { $0 }
    }

    var planLabel: String {
        guard let planType = usage?.planType, !planType.isEmpty else {
            return "Codex"
        }
        return planType
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    var accountDisplayLabel: String {
        accountIdentity.displayLabel
    }

    private var resetUrgencies: [ResetExpiryUrgency] {
        availableCredits.map { credit in
            ResetExpiryUrgency.make(
                expiresAt: DateFormatting.parse(credit.expiresAt),
                isAvailable: credit.isAvailable
            )
        }
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 300 * 1_000_000_000)
                } catch {
                    return
                }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        if let identity = try? client.loadAccountIdentity() {
            accountIdentity = identity
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        do {
            let response = try await fetchResetCreditsResult().get()
            credits = response.credits.sorted(by: sortByExpiry)
            availableCount = response.availableCount
            creditsErrorMessage = nil
        } catch {
            creditsErrorMessage = refreshErrorMessage(
                area: "reset stash",
                error: error,
                hasPriorData: !credits.isEmpty
            )
        }

        do {
            let response = try await fetchUsageResult().get()
            usage = response
            accountIdentity = mergedIdentity(with: response)
            if creditsErrorMessage != nil,
               credits.isEmpty,
               let fallbackCount = usage?.rateLimitResetCredits?.availableCount {
                availableCount = fallbackCount
            }
            usageErrorMessage = nil
        } catch {
            usageErrorMessage = refreshErrorMessage(
                area: "usage meters",
                error: error,
                hasPriorData: usage != nil
            )
        }

        lastChecked = Date()
    }

    private func sortByExpiry(_ lhs: ResetCredit, _ rhs: ResetCredit) -> Bool {
        let leftDate = DateFormatting.parse(lhs.expiresAt)
        let rightDate = DateFormatting.parse(rhs.expiresAt)

        switch (leftDate, rightDate) {
        case let (left?, right?):
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.id < rhs.id
        }
    }

    private func fetchResetCreditsResult() async -> Result<ResetCreditsResponse, Error> {
        do {
            return .success(try await client.fetchResetCredits())
        } catch {
            return .failure(error)
        }
    }

    private func fetchUsageResult() async -> Result<CodexUsageResponse, Error> {
        do {
            return .success(try await client.fetchUsage())
        } catch {
            return .failure(error)
        }
    }

    private func refreshErrorMessage(area: String, error: Error, hasPriorData: Bool) -> String {
        let prefix = hasPriorData ? "Could not refresh \(area); showing the last known numbers." : "Could not load \(area)."
        return "\(prefix) \(error.localizedDescription)"
    }

    private func mergedIdentity(with response: CodexUsageResponse) -> CodexAccountIdentity {
        CodexAccountIdentity(
            accountId: response.accountId ?? accountIdentity.accountId,
            email: response.email ?? accountIdentity.email,
            name: accountIdentity.name
        )
    }

    private func display(for window: UsageLimitWindow, fallbackID: String, limitReached: Bool) -> UsageLimitDisplay {
        let seconds = window.limitWindowSeconds ?? 0
        if fallbackID == "primary" || (14_400...21_600).contains(seconds) {
            return UsageLimitDisplay(id: "five-hour", kind: .fiveHour, title: "5h limit", window: window, limitReached: limitReached)
        }
        if fallbackID == "secondary" || (518_400...864_000).contains(seconds) {
            return UsageLimitDisplay(id: "weekly", kind: .weekly, title: "Weekly limit", window: window, limitReached: limitReached)
        }
        return UsageLimitDisplay(id: fallbackID, kind: .generic, title: DateFormatting.windowTitle(seconds: seconds), window: window, limitReached: limitReached)
    }
}
