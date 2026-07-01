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
        XCTAssertEqual(nudge.title, "Hold that reset")
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
        XCTAssertEqual(nudge.title, "Let the 5h tank refill")
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
        XCTAssertEqual(nudge.title, "Deadline override")
        XCTAssertTrue(nudge.message.contains("Big deadline?"))
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
        XCTAssertEqual(nudge.title, "Deadline call")
        XCTAssertTrue(nudge.message.contains("If this is deadline work"))
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
        XCTAssertEqual(nudge.title, "Let the 5h tank refill")
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
        XCTAssertEqual(nudge.title, "No reset parachute")
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
        XCTAssertEqual(nudge.title, "Cruise mode")
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
                ResetExpiryUrgency(level: .urgent, badge: "Ends today", hint: "Use it soon or let it go")
            ]
        )

        XCTAssertEqual(nudge.tier, .expiringReset)
        XCTAssertEqual(nudge.title, "Use it or lose it")
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
                ResetExpiryUrgency(level: .urgent, badge: "Ends today", hint: "Use it soon or let it go")
            ]
        )

        XCTAssertEqual(nudge.tier, .blocked)
        XCTAssertEqual(nudge.title, "Blocked now")
        XCTAssertEqual(nudge.detail, "1 reset banked")
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
        XCTAssertEqual(nudge.title, "Blocked, wait it out")
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
        XCTAssertEqual(nudge.title, "Green light, with brakes")
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
        XCTAssertEqual(nudge.title, "Pocket the reset")
    }

    @MainActor
    func testUnavailableWhenWeeklyWindowIsMissing() {
        let nudge = UsageNudge.make(windows: [], resetCount: 1)

        XCTAssertEqual(nudge.tier, .unavailable)
        XCTAssertEqual(nudge.title, "Waiting on the meters")
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
        XCTAssertEqual(nudge.title, "No reset parachute")
    }

    private func window(
        kind: UsageLimitDisplay.Kind,
        remaining: Int,
        resetAfterSeconds: Int?,
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
                resetAt: nil
            ),
            limitReached: limitReached
        )
    }
}
