import XCTest
@testable import CodexResetWatcher

final class UsageNudgeTests: XCTestCase {
    @MainActor
    func testBurnTokensWhenWeeklyIsLowAndResetsAreBanked() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 10, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .spend)
        XCTAssertEqual(nudge.title, "Go burn some tokens")
    }

    @MainActor
    func testHoldResetWhenWeeklyRoomIsHealthyAndRefreshIsClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 40, resetAfterSeconds: 2 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .hold)
        XCTAssertEqual(nudge.title, "Keep your reset credit")
    }

    @MainActor
    func testWaitForFiveHourWindowWhenWeeklyRoomIsFine() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 8, resetAfterSeconds: 45 * 60),
                window(kind: .weekly, remaining: 45, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "Wait for the 5-hour reset")
    }

    @MainActor
    func testZeroFiveHourResetDoesNotSayInNow() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 8, resetAfterSeconds: 0),
                window(kind: .weekly, remaining: 45, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.detail, "5h resets now")
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithLongWaitBecomesDeadlineCall() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .deadline)
        XCTAssertEqual(nudge.title, "Use a reset only for a deadline")
        XCTAssertTrue(nudge.message.contains("real deadline"))
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithMediumWaitBecomesDeadlineCall() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 2 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .deadline)
        XCTAssertEqual(nudge.title, "Use a reset only for a deadline")
        XCTAssertTrue(nudge.message.contains("real deadline"))
    }

    @MainActor
    func testLowFiveHourAndHealthyWeeklyWithShortWaitSavesReset() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "Wait for the 5-hour reset")
    }

    @MainActor
    func testLowFiveHourDeadlineCallRequiresBankedReset() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .noResets)
        XCTAssertEqual(nudge.title, "5-hour capacity is low")
    }

    @MainActor
    func testLowFiveHourWithNoResetAndShortWaitSaysWaitForRefill() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "Wait for the 5-hour reset")
        XCTAssertTrue(nudge.message.contains("no reset credit"))
    }

    @MainActor
    func testGlobalBlockedStateDoesNotRequireAWindowToBeMarkedBlocked() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 80, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 24 * 60 * 60)
            ],
            resetCount: 1,
            globallyBlocked: true
        )

        XCTAssertEqual(nudge.tier, .blocked)
        XCTAssertEqual(nudge.title, "Blocked now")
    }

    @MainActor
    func testModerateFiveHourRemainingDoesNotTriggerDeadlineWarning() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 15, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
        XCTAssertEqual(nudge.title, "Keep working")
    }

    @MainActor
    func testMissingFiveHourDataStillUsesWeeklyAdvice() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 10, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 2
        )

        XCTAssertEqual(nudge.tier, .spend)
        XCTAssertEqual(nudge.title, "Go burn some tokens")
    }

    @MainActor
    func testExpiringResetOverridesHoldAdvice() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 80, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 24 * 60 * 60)
            ],
            resetCount: 1,
            resetUrgencies: [
                ResetExpiryUrgency(level: .urgent, badge: "Within 24 hours", hint: "Use it soon if useful work needs it")
            ]
        )

        XCTAssertEqual(nudge.tier, .expiringReset)
        XCTAssertEqual(nudge.title, "Reset credit expires soon")
    }

    @MainActor
    func testBlockedWindowWithBankedResetTakesPriority() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 80, resetAfterSeconds: 4 * 3_600, limitReached: true),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 24 * 60 * 60)
            ],
            resetCount: 1,
            resetUrgencies: [
                ResetExpiryUrgency(level: .urgent, badge: "Within 24 hours", hint: "Use it soon if useful work needs it")
            ]
        )

        XCTAssertEqual(nudge.tier, .blocked)
        XCTAssertEqual(nudge.title, "Blocked now")
        XCTAssertEqual(nudge.detail, "1 reset credit available")
    }

    @MainActor
    func testBlockedWindowWithoutBankedResetWaits() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 0, resetAfterSeconds: 45 * 60, limitReached: true),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 24 * 60 * 60)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .blocked)
        XCTAssertEqual(nudge.title, "Wait for the limit to reset")
        XCTAssertEqual(nudge.detail, "5h limit resets in 45m")
    }

    @MainActor
    func testUseIfBlockedWhenWeeklyIsLowButNotBurnMode() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 18, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .useIfBlocked)
        XCTAssertEqual(nudge.title, "Use a reset only if blocked")
    }

    @MainActor
    func testPocketResetHoldWhenWeeklyRefreshIsVeryClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 30, resetAfterSeconds: 36 * 3_600)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .hold)
        XCTAssertEqual(nudge.title, "Keep your reset credit")
    }

    @MainActor
    func testUnavailableWhenWeeklyWindowIsMissing() {
        let nudge = UsageNudge.make(windows: [], resetCount: 1)

        XCTAssertEqual(nudge.tier, .unavailable)
        XCTAssertEqual(nudge.title, "Usage unavailable")
    }

    @MainActor
    func testUnknownWeeklyResetTimingDoesNotPretendRefreshIsClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 40, resetAfterSeconds: nil)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
        XCTAssertEqual(nudge.title, "Reset timing unclear")
    }

    @MainActor
    func testFiveHourLowBoundaryIsInclusive() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 12, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
    }

    @MainActor
    func testFiveHourBoundaryAboveLowStaysCalm() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 13, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 80, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .steady)
    }

    @MainActor
    func testNoResetsShowsNoCushion() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 60, resetAfterSeconds: 3 * 86_400)
            ],
            resetCount: 0
        )

        XCTAssertEqual(nudge.tier, .noResets)
        XCTAssertEqual(nudge.title, "No reset credits available")
    }

    @MainActor
    func testUnknownResetCountDoesNotPretendThereAreZeroCredits() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .weekly, remaining: 10, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: nil
        )

        XCTAssertEqual(nudge.tier, .unavailable)
        XCTAssertEqual(nudge.title, "Reset credits unavailable")
        XCTAssertFalse(nudge.message.localizedCaseInsensitiveContains("no reset"))
    }

    @MainActor
    func testGenericLimitsAreDifferentFromMissingUsage() {
        let generic = UsageNudge.make(
            windows: [window(kind: .generic, remaining: 60, resetAfterSeconds: 3_600)],
            resetCount: 1
        )
        let missing = UsageNudge.make(windows: [], resetCount: 1)

        XCTAssertEqual(generic.title, "Weekly limit not identified")
        XCTAssertEqual(missing.title, "Usage unavailable")
    }

    @MainActor
    func testResetAtDrivesWeeklyTimingWhenDurationIsMissing() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nudge = UsageNudge.make(
            windows: [
                window(
                    kind: .weekly,
                    remaining: 40,
                    resetAfterSeconds: nil,
                    resetAt: now.addingTimeInterval(2 * 86_400).timeIntervalSince1970
                )
            ],
            resetCount: 1,
            now: now
        )

        XCTAssertEqual(nudge.tier, .hold)
        XCTAssertEqual(nudge.title, "Keep your reset credit")
    }

    @MainActor
    func testLowFiveHourAndModerateWeeklyCapacityIsADeadlineDecisionWhenResetIsFar() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 4 * 3_600),
                window(kind: .weekly, remaining: 40, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .deadline)
        XCTAssertEqual(nudge.title, "Use a reset only for a deadline")
    }

    @MainActor
    func testLowFiveHourAndModerateWeeklyCapacityWaitsWhenResetIsClose() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 5, resetAfterSeconds: 60 * 60),
                window(kind: .weekly, remaining: 40, resetAfterSeconds: 5 * 86_400)
            ],
            resetCount: 1
        )

        XCTAssertEqual(nudge.tier, .waitFiveHour)
        XCTAssertEqual(nudge.title, "Wait for the 5-hour reset")
    }

    @MainActor
    func testBlockedLimitWithUnknownResetCountAvoidsSpendOrWaitClaim() {
        let nudge = UsageNudge.make(
            windows: [
                window(kind: .fiveHour, remaining: 20, resetAfterSeconds: 3_600, limitReached: true)
            ],
            resetCount: nil
        )

        XCTAssertEqual(nudge.tier, .blocked)
        XCTAssertEqual(nudge.title, "Blocked now")
        XCTAssertEqual(nudge.detail, "5h limit resets in 1h")
        XCTAssertTrue(nudge.message.contains("could not be checked"))
    }

    private func window(
        kind: UsageLimitDisplay.Kind,
        remaining: Int,
        resetAfterSeconds: Int?,
        resetAt: TimeInterval? = nil,
        limitReached: Bool = false
    ) -> UsageLimitDisplay {
        let seconds: Int
        let id: String
        let title: String

        switch kind {
        case .fiveHour:
            seconds = 18_000
            id = "five-hour"
            title = "5h limit"
        case .weekly:
            seconds = 604_800
            id = "weekly"
            title = "Weekly limit"
        case .generic:
            seconds = resetAfterSeconds ?? 0
            id = "generic"
            title = "Limit"
        }

        return UsageLimitDisplay(
            id: id,
            kind: kind,
            title: title,
            window: UsageLimitWindow(
                usedPercent: 100 - remaining,
                limitWindowSeconds: seconds,
                resetAfterSeconds: resetAfterSeconds,
                resetAt: resetAt
            ),
            limitReached: limitReached
        )
    }
}
