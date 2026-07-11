import XCTest
@testable import CodexResetWatcher

final class ResetExpiryUrgencyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFarAwayResetStaysNormallyAvailable() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(8 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .normal)
        XCTAssertEqual(urgency.badge, "Available")
        XCTAssertNil(urgency.hint)
    }

    func testResetWithinWeekGetsAttentionState() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(6 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .approaching)
        XCTAssertEqual(urgency.badge, "This week")
    }

    func testResetWithinThreeDaysGetsSoonWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(2 * 86_400),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .soon)
        XCTAssertEqual(urgency.badge, "Expires soon")
    }

    func testResetWithinOneDayGetsUrgentWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(23 * 3_600),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .urgent)
        XCTAssertEqual(urgency.badge, "Within 24 hours")
        XCTAssertEqual(urgency.hint, "Use it soon if useful work needs it")
    }

    func testSameCalendarDayUsesEndsToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let calendarNow = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 9))!
        let urgency = ResetExpiryUrgency.make(
            expiresAt: calendarNow.addingTimeInterval(8 * 3_600),
            now: calendarNow,
            isAvailable: true
        )

        XCTAssertEqual(urgency.badge, "Ends today")
    }

    func testExpiredResetIsRedFlagged() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(-60),
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .expired)
        XCTAssertEqual(urgency.badge, "Expired")
    }

    func testUnavailableResetDoesNotShowExpiryWarning() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(30 * 60),
            now: now,
            isAvailable: false
        )

        XCTAssertEqual(urgency.level, .inactive)
        XCTAssertEqual(urgency.badge, "Used")
    }

    func testMissingExpiryStaysAvailableButUnknown() {
        let urgency = ResetExpiryUrgency.make(
            expiresAt: nil,
            now: now,
            isAvailable: true
        )

        XCTAssertEqual(urgency.level, .unknown)
        XCTAssertEqual(urgency.badge, "Available")
        XCTAssertEqual(urgency.hint, "Expiry unknown")
    }

    func testExactUrgencyBoundaries() {
        XCTAssertEqual(urgency(after: 7 * 86_400 + 1).level, .normal)
        XCTAssertEqual(urgency(after: 7 * 86_400).level, .approaching)
        XCTAssertEqual(urgency(after: 3 * 86_400 + 1).level, .approaching)
        XCTAssertEqual(urgency(after: 3 * 86_400).level, .soon)
        XCTAssertEqual(urgency(after: 86_400 + 1).level, .soon)
        XCTAssertEqual(urgency(after: 86_400).level, .urgent)
        XCTAssertEqual(urgency(after: 1).level, .urgent)
        XCTAssertEqual(urgency(after: 0).level, .expired)
        XCTAssertEqual(urgency(after: -1).level, .expired)
    }

    private func urgency(after seconds: TimeInterval) -> ResetExpiryUrgency {
        ResetExpiryUrgency.make(
            expiresAt: now.addingTimeInterval(seconds),
            now: now,
            isAvailable: true
        )
    }
}
