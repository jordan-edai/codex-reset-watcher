import Foundation

struct UsageNudge: Sendable {
    enum Tier: Sendable {
        case spend
        case blocked
        case expiringReset
        case deadline
        case useIfBlocked
        case waitFiveHour
        case hold
        case steady
        case noResets
        case unavailable
    }

    let tier: Tier
    let title: String
    let message: String
    let detail: String

    @MainActor
    static func make(
        windows: [UsageLimitDisplay],
        resetCount: Int?,
        resetUrgencies: [ResetExpiryUrgency] = [],
        globallyBlocked: Bool = false,
        now: Date = Date()
    ) -> UsageNudge {
        if globallyBlocked || windows.contains(where: \.limitReached) {
            let blockedWindow = windows.first(where: \.limitReached)
            if let resetCount, resetCount > 0 {
                return UsageNudge(
                    tier: .blocked,
                    title: "Blocked now",
                    message: blockedWindow.map { "Codex says \($0.title.lowercased()) is reached. Use a reset credit in Codex if you need to continue now." } ?? "Codex says new work is blocked. Use a reset credit in Codex if you need to continue now.",
                    detail: resetCountDetail(resetCount)
                )
            }

            if resetCount == nil {
                return UsageNudge(
                    tier: .blocked,
                    title: "Blocked now",
                    message: "Codex says this limit is reached, but the reset credit count could not be checked. Open Codex before deciding what to do.",
                    detail: blockedWindow.flatMap { resetDetail(for: $0, now: now) } ?? "Reset count unavailable"
                )
            }

            return UsageNudge(
                tier: .blocked,
                title: "Wait for the limit to reset",
                message: "Codex says new work is blocked and no reset credits are available.",
                detail: blockedWindow.flatMap { resetDetail(for: $0, now: now) } ?? "No reset credits available"
            )
        }

        if let resetCount, resetCount > 0, resetUrgencies.contains(where: { $0.level == .urgent }) {
            return UsageNudge(
                tier: .expiringReset,
                title: "Reset credit expires soon",
                message: "A reset credit expires within 24 hours. Use it in Codex only if useful work needs the extra capacity.",
                detail: "Expires within 24 hours"
            )
        }

        guard let weekly = windows.first(where: { $0.kind == .weekly }),
              let weeklyRemaining = weekly.remainingPercent
        else {
            if windows.isEmpty {
                return UsageNudge(
                    tier: .unavailable,
                    title: "Usage unavailable",
                    message: "Codex has not returned any usage limits yet. Refresh to try again.",
                    detail: "No live limits"
                )
            }
            return UsageNudge(
                tier: .unavailable,
                title: "Weekly limit not identified",
                message: "Usage loaded, but Codex did not identify which limit is weekly. Advice is unavailable until that is clear.",
                detail: "Limits shown without a guess"
            )
        }

        let fiveHour = windows.first(where: { $0.kind == .fiveHour })
        let fiveHourRemaining = fiveHour?.remainingPercent
        let fiveHourResetSeconds = fiveHour.flatMap { resetSeconds(for: $0, now: now) }
        let weeklyResetSeconds = resetSeconds(for: weekly, now: now)

        guard let resetCount else {
            return UsageNudge(
                tier: .unavailable,
                title: "Reset credits unavailable",
                message: "Usage limits loaded, but Codex did not return the reset credit count. Check Codex before deciding whether to use one.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if resetCount == 0,
           let fiveHourRemaining,
           fiveHourRemaining <= 12 {
            if let fiveHourReset = fiveHourResetSeconds {
                if fiveHourReset <= 90 * 60 {
                    return UsageNudge(
                        tier: .waitFiveHour,
                        title: "Wait for the 5-hour reset",
                        message: "The 5-hour limit resets soon, and there is no reset credit available to spend. Let the window refill.",
                        detail: resetDetail(prefix: "5h", seconds: fiveHourReset)
                    )
                }

                return UsageNudge(
                    tier: .noResets,
                    title: "5-hour capacity is low",
                    message: "There is no reset credit available. Pace the work until the 5-hour limit refills.",
                    detail: resetDetail(prefix: "5h", seconds: fiveHourReset)
                )
            }

            return UsageNudge(
                tier: .noResets,
                title: "5-hour timing is unclear",
                message: "Capacity is low and there is no reset credit available. Refresh before a deadline run.",
                detail: "5h reset unavailable"
            )
        }

        if resetCount == 0 {
            return UsageNudge(
                tier: .noResets,
                title: "No reset credits available",
                message: "Keep an eye on the limits. There is no reset credit available if Codex blocks the work.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHourResetSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 25,
           fiveHourReset <= 90 * 60 {
            return UsageNudge(
                tier: .waitFiveHour,
                title: "Wait for the 5-hour reset",
                message: "The 5-hour limit resets soon and weekly capacity is still available. Keep the reset credit.",
                detail: resetDetail(prefix: "5h", seconds: fiveHourReset)
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHourResetSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 25,
           fiveHourReset > 90 * 60 {
            let weeklyContext = weeklyRemaining >= 50
                ? "Weekly capacity is still healthy."
                : "Weekly capacity is getting lower."
            return UsageNudge(
                tier: .deadline,
                title: "Use a reset only for a deadline",
                message: "\(weeklyContext) If this work has a real deadline, use a reset credit in Codex. Otherwise wait for the 5-hour reset.",
                detail: resetDetail(prefix: "5h", seconds: fiveHourReset)
            )
        }

        guard let weeklyResetSeconds else {
            return UsageNudge(
                tier: .steady,
                title: "Reset timing unclear",
                message: "Usage limits loaded, but Codex did not return the weekly reset time. Use a reset credit only if work is blocked.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        let weeklyDays = Double(weeklyResetSeconds) / 86_400

        if resetCount >= 2, weeklyRemaining <= 15, weeklyDays >= 4 {
            return UsageNudge(
                tier: .spend,
                title: "Go burn some tokens",
                message: "You have \(resetCount) reset credits, weekly capacity is low, and the weekly reset is days away. Keep working, then use a credit if Codex blocks useful work.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if resetCount >= 1, weeklyRemaining <= 20, weeklyDays >= 2 {
            return UsageNudge(
                tier: .useIfBlocked,
                title: "Use a reset only if blocked",
                message: "If useful work is blocked, using a reset credit makes sense. Otherwise keep it.",
                detail: resetDistanceDetail(seconds: weeklyResetSeconds, suffix: "to weekly reset")
            )
        }

        if weeklyRemaining >= 35, weeklyDays <= 3 {
            return UsageNudge(
                tier: .hold,
                title: "Keep your reset credit",
                message: "Weekly capacity is healthy and the next reset is close. Save the credit.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if weeklyRemaining >= 25, weeklyDays <= 2 {
            return UsageNudge(
                tier: .hold,
                title: "Keep your reset credit",
                message: "The weekly reset is close and capacity is not tight enough to use a credit now.",
                detail: resetDistanceDetail(seconds: weeklyResetSeconds, suffix: "away")
            )
        }

        return UsageNudge(
            tier: .steady,
            title: "Keep working",
            message: "Current capacity looks workable. Check again before a large run.",
            detail: "\(weeklyRemaining)% weekly left"
        )
    }

    @MainActor
    private static func resetDetail(prefix: String, seconds: Int) -> String {
        let duration = DateFormatting.duration(seconds: seconds)
        return duration == "now" ? "\(prefix) resets now" : "\(prefix) resets in \(duration)"
    }

    @MainActor
    private static func resetDistanceDetail(seconds: Int, suffix: String) -> String {
        let duration = DateFormatting.duration(seconds: seconds)
        return duration == "now" ? "Weekly reset now" : "\(duration) \(suffix)"
    }

    private static func resetSeconds(for window: UsageLimitDisplay, now: Date) -> Int? {
        window.window.resetSecondsRemaining(now: now)
    }

    @MainActor
    private static func resetDetail(for window: UsageLimitDisplay, now: Date) -> String? {
        resetSeconds(for: window, now: now).map { resetDetail(prefix: window.title, seconds: $0) }
    }

    private static func resetCountDetail(_ count: Int) -> String {
        "\(count) reset \(count == 1 ? "credit" : "credits") available"
    }
}
