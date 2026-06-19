import Foundation

struct UsageNudge: Sendable {
    enum Tier: Sendable {
        case spend
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
        resetCount: Int,
        resetUrgencies: [ResetExpiryUrgency] = []
    ) -> UsageNudge {
        if resetCount > 0, resetUrgencies.contains(where: { $0.level == .urgent }) {
            return UsageNudge(
                tier: .expiringReset,
                title: "Use it or lose it",
                message: "A banked reset expires today. If there is useful work queued, spend that reset before it disappears.",
                detail: "Reset ends today"
            )
        }

        guard let weekly = windows.first(where: { $0.kind == .weekly }),
              let weeklyRemaining = weekly.remainingPercent
        else {
            return UsageNudge(
                tier: .unavailable,
                title: "Waiting on the meters",
                message: "Reset stash loaded. Codex usage windows are still warming up.",
                detail: "Try again soon"
            )
        }

        let fiveHour = windows.first(where: { $0.kind == .fiveHour })
        let fiveHourRemaining = fiveHour?.remainingPercent
        let weeklyResetSeconds = weekly.window.resetAfterSeconds

        if resetCount == 0 {
            return UsageNudge(
                tier: .noResets,
                title: "No reset parachute",
                message: "Watch the meters. There is no banked reset for a big sprint.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 25,
           fiveHourReset <= 90 * 60 {
            return UsageNudge(
                tier: .waitFiveHour,
                title: "Let the 5h tank refill",
                message: "Weekly room is still decent. Let the short window catch up before spending a reset.",
                detail: "5h resets in \(DateFormatting.duration(seconds: fiveHourReset))"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 50,
           fiveHourReset > 90 * 60,
           fiveHourReset <= 3 * 3_600 {
            return UsageNudge(
                tier: .deadline,
                title: "Deadline call",
                message: "Weekly runway looks great. If this is deadline work, spend a reset. Otherwise let the 5h clock do its thing.",
                detail: "5h resets in \(DateFormatting.duration(seconds: fiveHourReset))"
            )
        }

        if let fiveHourRemaining,
           let fiveHourReset = fiveHour?.window.resetAfterSeconds,
           fiveHourRemaining <= 12,
           weeklyRemaining >= 50,
           fiveHourReset > 3 * 3_600 {
            return UsageNudge(
                tier: .deadline,
                title: "Deadline override",
                message: "The short window is hours away. Big deadline? Use a reset. Otherwise coast until the 5h refill.",
                detail: "5h resets in \(DateFormatting.duration(seconds: fiveHourReset))"
            )
        }

        guard let weeklyResetSeconds else {
            return UsageNudge(
                tier: .steady,
                title: "Reset timing unclear",
                message: "Usage meters loaded, but Codex did not return a weekly reset timer. Spend a reset only if work is blocked.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        let weeklyDays = Double(weeklyResetSeconds) / 86_400

        if resetCount >= 2, weeklyRemaining <= 15, weeklyDays >= 4 {
            return UsageNudge(
                tier: .spend,
                title: "Go burn some tokens",
                message: "You have \(resetCount) resets banked, weekly room is thin, and refresh is days away. Push the run, then spend a reset if Codex blocks real work.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if resetCount >= 1, weeklyRemaining <= 20, weeklyDays >= 2 {
            return UsageNudge(
                tier: .useIfBlocked,
                title: "Green light, with brakes",
                message: "If real work hits the wall, spending a reset makes sense. Do not use it just to tidy up the meter.",
                detail: "\(DateFormatting.duration(seconds: weeklyResetSeconds)) to weekly reset"
            )
        }

        if weeklyRemaining >= 35, weeklyDays <= 3 {
            return UsageNudge(
                tier: .hold,
                title: "Hold that reset",
                message: "Plenty of weekly runway and the next refresh is close. Let the reset stay banked.",
                detail: "\(weeklyRemaining)% weekly left"
            )
        }

        if weeklyRemaining >= 25, weeklyDays <= 2 {
            return UsageNudge(
                tier: .hold,
                title: "Pocket the reset",
                message: "Capacity is not tight enough this close to weekly refresh. Keep the reset in your back pocket.",
                detail: "\(DateFormatting.duration(seconds: weeklyResetSeconds)) away"
            )
        }

        return UsageNudge(
            tier: .steady,
            title: "Cruise mode",
            message: "Keep working. Re-check before a big run.",
            detail: "\(weeklyRemaining)% weekly left"
        )
    }
}
