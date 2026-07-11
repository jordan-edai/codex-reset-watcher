import Foundation
import XCTest
@testable import CodexResetWatcher

final class AccountSnapshotPersistenceTests: XCTestCase {
    func testSnapshotEncodingRedactsSensitiveSourceFields() throws {
        let directory = try makeTemporaryDirectory()
        let persistence = AccountSnapshotPersistence(
            fileURL: directory.appendingPathComponent("account-snapshots.json"),
            salt: "unit-test-salt"
        )
        let snapshot = CodexAccountSnapshot(
            id: try persistence.snapshotID(for: "acct_full_sensitive_123456"),
            displayLabel: "builder@example.com",
            planLabel: "Pro",
            lastChecked: Date(timeIntervalSince1970: 1_800_000_000),
            usageWindows: [
                AccountUsageWindowSnapshot(
                    display: UsageLimitDisplay(
                        id: "weekly",
                        kind: .weekly,
                        title: "Weekly limit",
                        window: UsageLimitWindow(
                            usedPercent: 42,
                            limitWindowSeconds: 604_800,
                            resetAfterSeconds: 86_400,
                            resetAt: 1_800_086_400
                        ),
                        limitReached: false
                    ),
                    capturedAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ],
            resetCount: 1,
            resetExpiries: [Date(timeIntervalSince1970: 1_800_172_800)],
            status: .ok,
            errors: []
        )

        try persistence.save([snapshot])

        let json = try String(contentsOf: persistence.fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("acct_full_sensitive_123456"))
        XCTAssertFalse(json.contains("user_full_sensitive"))
        XCTAssertFalse(json.contains("credit-full-sensitive"))
        XCTAssertFalse(json.contains("eyJ"))
        XCTAssertFalse(json.contains("access_token"))
        XCTAssertFalse(json.contains("refresh_token"))
        XCTAssertFalse(json.contains("auth.json"))
        XCTAssertFalse(json.contains("rate_limit"))
        XCTAssertTrue(json.contains("builder@example.com"))
    }

    func testDistinctAccountsWithSameLabelGetSeparateSnapshotKeys() throws {
        let directory = try makeTemporaryDirectory()
        let persistence = AccountSnapshotPersistence(
            fileURL: directory.appendingPathComponent("account-snapshots.json"),
            salt: "unit-test-salt"
        )

        let first = try persistence.snapshotID(for: "acct_a")
        let second = try persistence.snapshotID(for: "acct_b")

        XCTAssertNotEqual(first, second)
    }

    func testCorruptAndOldSchemaSnapshotFilesLoadAsEmpty() throws {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("account-snapshots.json")
        try Data("not json".utf8).write(to: fileURL)
        var persistence = AccountSnapshotPersistence(fileURL: fileURL, salt: "unit-test-salt")
        XCTAssertEqual(persistence.load(), [])

        let oldSchema = #"{"schemaVersion":0,"snapshots":[]}"#
        try Data(oldSchema.utf8).write(to: fileURL)
        persistence = AccountSnapshotPersistence(fileURL: fileURL, salt: "unit-test-salt")
        XCTAssertEqual(persistence.load(), [])
    }

    func testCachedSnapshotIsStaleAfterDisplayedResetPasses() throws {
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "abc"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: Date(timeIntervalSince1970: 1_800_000_000),
            usageWindows: [
                AccountUsageWindowSnapshot(
                    display: UsageLimitDisplay(
                        id: "five-hour",
                        kind: .fiveHour,
                        title: "5h limit",
                        window: UsageLimitWindow(
                            usedPercent: 50,
                            limitWindowSeconds: 18_000,
                            resetAfterSeconds: 60,
                            resetAt: 1_800_000_100
                        ),
                        limitReached: false
                    ),
                    capturedAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ],
            resetCount: 1,
            resetExpiries: [],
            status: .ok,
            errors: []
        )

        XCTAssertFalse(snapshot.isStale(now: Date(timeIntervalSince1970: 1_800_000_050)))
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1_800_000_101)))
    }

    func testCachedSnapshotWithoutUsageOrResetSignalsIsStale() throws {
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "empty"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: Date(timeIntervalSince1970: 1_800_000_000),
            usageWindows: [],
            resetCount: 0,
            resetExpiries: [],
            status: .ok,
            errors: []
        )

        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1_800_000_010)))
    }

    func testHostileSnapshotResetCountBecomesUnknownInsteadOfConfirmedZero() {
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "hostile-count"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: Date(timeIntervalSince1970: 1_800_000_000),
            usageWindows: [],
            resetCount: Int.min,
            resetCountKnown: true,
            resetExpiries: [],
            status: .ok,
            errors: []
        )

        XCTAssertEqual(snapshot.resetCount, 0)
        XCTAssertFalse(snapshot.resetCountKnown)
    }

    func testHostileCachedWindowValuesAreSanitizedBeforeCountdownMath() throws {
        let data = """
        {
          "id": "hostile-window",
          "kind": "fiveHour",
          "title": "5h limit",
          "usedPercent": -9223372036854775808,
          "limitWindowSeconds": 18000,
          "resetAfterSeconds": 9223372036854775807
        }
        """.data(using: .utf8)!

        let window = try JSONDecoder().decode(AccountUsageWindowSnapshot.self, from: data)
        let display = window.display(
            cachedAt: Date(timeIntervalSince1970: 1_800_000_000),
            now: Date(timeIntervalSince1970: 1_800_000_001)
        )

        XCTAssertEqual(display.usedPercent, 0)
        XCTAssertEqual(display.remainingPercent, 100)
        XCTAssertNil(display.window.resetAfterSeconds)
        XCTAssertFalse(display.limitReached)
    }

    func testSnapshotSkipsImplausibleResetDateWithoutCrashing() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let window = AccountUsageWindowSnapshot(
            display: UsageLimitDisplay(
                id: "five-hour",
                kind: .fiveHour,
                title: "5h limit",
                window: UsageLimitWindow(
                    usedPercent: 50,
                    limitWindowSeconds: 18_000,
                    resetAfterSeconds: nil,
                    resetAt: 1e100
                ),
                limitReached: false
            ),
            capturedAt: capturedAt
        )

        XCTAssertNil(window.resetDate)
        XCTAssertNil(window.resetAfterSeconds)
        XCTAssertFalse(window.hasResetPassed(cachedAt: capturedAt, now: capturedAt.addingTimeInterval(1)))
    }

    func testDurationOnlyCachedSnapshotAgesFromCaptureTime() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let window = AccountUsageWindowSnapshot(
            display: UsageLimitDisplay(
                id: "five-hour",
                kind: .fiveHour,
                title: "5h limit",
                window: UsageLimitWindow(
                    usedPercent: 50,
                    limitWindowSeconds: 18_000,
                    resetAfterSeconds: 60,
                    resetAt: nil
                ),
                limitReached: false
            ),
            capturedAt: capturedAt
        )
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "duration-only"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: capturedAt.addingTimeInterval(30),
            usageCapturedAt: capturedAt,
            usageWindows: [window],
            resetCount: 0,
            resetExpiries: [],
            status: .ok,
            errors: []
        )

        let halfway = capturedAt.addingTimeInterval(30)
        let expired = capturedAt.addingTimeInterval(61)

        XCTAssertFalse(snapshot.isStale(now: halfway))
        XCTAssertTrue(snapshot.isStale(now: expired))
        XCTAssertEqual(window.display(cachedAt: capturedAt, now: halfway).window.resetAfterSeconds, 30)
        XCTAssertEqual(window.display(cachedAt: capturedAt, now: expired).window.resetAfterSeconds, 0)
    }

    func testBlockedStateSurvivesSnapshotRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        let persistence = AccountSnapshotPersistence(
            fileURL: directory.appendingPathComponent("account-snapshots.json"),
            salt: "unit-test-salt"
        )
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "blocked"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: capturedAt,
            usageWindows: [
                AccountUsageWindowSnapshot(
                    display: UsageLimitDisplay(
                        id: "five-hour",
                        kind: .fiveHour,
                        title: "5h limit",
                        window: UsageLimitWindow(
                            usedPercent: 20,
                            limitWindowSeconds: 18_000,
                            resetAfterSeconds: 3_600,
                            resetAt: nil
                        ),
                        limitReached: true
                    ),
                    capturedAt: capturedAt
                )
            ],
            resetCount: 1,
            resetExpiries: [],
            status: .ok,
            errors: []
        )

        try persistence.save([snapshot])
        let loaded = try XCTUnwrap(persistence.load().first)

        XCTAssertTrue(try XCTUnwrap(loaded.usageWindows.first).limitReached)
    }

    func testLegacySnapshotDefaultsNewStateFieldsWithoutLosingBlockedZero() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = CodexAccountSnapshot(
            id: AccountSnapshotID(rawValue: "legacy"),
            displayLabel: "Cached",
            planLabel: "Pro",
            lastChecked: capturedAt,
            usageWindows: [
                AccountUsageWindowSnapshot(
                    display: UsageLimitDisplay(
                        id: "weekly",
                        kind: .weekly,
                        title: "Weekly limit",
                        window: UsageLimitWindow(
                            usedPercent: 100,
                            limitWindowSeconds: 604_800,
                            resetAfterSeconds: 86_400,
                            resetAt: nil
                        ),
                        limitReached: true
                    ),
                    capturedAt: capturedAt
                )
            ],
            resetCount: 1,
            resetExpiries: [],
            status: .ok,
            errors: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "usageCapturedAt")
        object.removeValue(forKey: "resetCountKnown")
        var windows = try XCTUnwrap(object["usageWindows"] as? [[String: Any]])
        windows[0].removeValue(forKey: "limitReached")
        object["usageWindows"] = windows

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            CodexAccountSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.usageCapturedAt, capturedAt)
        XCTAssertTrue(decoded.resetCountKnown)
        XCTAssertTrue(try XCTUnwrap(decoded.usageWindows.first).limitReached)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
final class AccountSnapshotStoreTests: XCTestCase {
    func testInitialStateDoesNotPresentUnknownResetCountAsZero() throws {
        let harness = try StoreHarness()
        let store = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)

        XCTAssertEqual(store.liveState, .loading)
        XCTAssertEqual(store.resetCountState, .loading)
        XCTAssertEqual(store.menuBarTitle, "Checking resets...")
        XCTAssertEqual(store.nudge.title, "Checking Codex")
        XCTAssertFalse(store.detail(for: .active).resetCountState.isKnown)
    }

    func testRefreshPersistsSafeSnapshotForActiveAccount() async throws {
        let harness = try StoreHarness()
        let store = ResetCreditsStore(client: harness.client(accountID: "acct_a"), snapshotPersistence: harness.persistence)

        await store.refresh()

        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 0)
        XCTAssertEqual(store.accountDisplayLabel, "builder@example.com")
        XCTAssertEqual(store.snapshots.first?.resetCount, 1)
        XCTAssertEqual(store.snapshots.first?.usageWindows.count, 2)
        XCTAssertEqual(store.liveState, .live)
        XCTAssertEqual(store.resetCountState, .known(1))
    }

    func testAccountSwitchRaceDoesNotPersistMixedSnapshot() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a")
        let state = RequestState()
        var client = harness.baseClient
        client.perform = { request in
            _ = await state.record()
            try harness.writeAuth(accountID: "acct_b")
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()

        XCTAssertEqual(store.snapshots.count, 0)
        XCTAssertTrue(store.errorMessages.joined(separator: " ").contains("account changed"))
    }

    func testTokenRotationWithSameStableAccountDoesNotLookLikeAccountSwitch() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a", accessToken: "token-before")
        let state = RequestState()
        var client = harness.baseClient
        client.perform = { request in
            _ = await state.record()
            try harness.writeAuth(accountID: "acct_a", accessToken: "token-after")
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()

        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 0)
        XCTAssertEqual(store.availableCount, 1)
        XCTAssertEqual(store.usageWindows.count, 2)
        XCTAssertEqual(store.errorMessages, [])
    }

    func testAccountSwitchRaceClearsPriorActiveData() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a")
        let state = RequestState()
        var client = harness.baseClient
        client.perform = { request in
            let count = await state.record()
            if count > 2 {
                try harness.writeAuth(accountID: "acct_b")
            }
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()
        XCTAssertEqual(store.availableCount, 1)
        XCTAssertEqual(store.usageWindows.count, 2)

        await store.refresh()

        XCTAssertEqual(store.usageWindows.count, 0)
        XCTAssertEqual(store.availableCount, 0)
        XCTAssertEqual(store.credits.count, 0)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 1)
        XCTAssertTrue(store.errorMessages.joined(separator: " ").contains("account changed"))
    }

    func testAccountSwitchWithFailedRefreshDoesNotShowPriorActiveData() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a")
        var client = harness.baseClient
        client.perform = { request in
            let auth = try String(contentsOf: harness.authURL, encoding: .utf8)
            if auth.contains("acct_b") {
                return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
            }
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()
        XCTAssertEqual(store.availableCount, 1)
        XCTAssertEqual(store.usageWindows.count, 2)

        try harness.writeAuth(accountID: "acct_b")
        await store.refresh()

        XCTAssertEqual(store.usageWindows.count, 0)
        XCTAssertEqual(store.availableCount, 0)
        XCTAssertEqual(store.credits.count, 0)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 1)
        XCTAssertTrue(store.errorMessages.joined(separator: " ").contains("Could not load"))
    }

    func testUsageAccountIDConflictUsesAuthContextSnapshotKey() async throws {
        let harness = try StoreHarness()
        let store = ResetCreditsStore(
            client: harness.client(accountID: "acct_header", usageAccountID: "acct_usage"),
            snapshotPersistence: harness.persistence
        )

        await store.refresh()

        let snapshot = try XCTUnwrap(store.snapshots.first)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(snapshot.id, try harness.persistence.snapshotID(for: "acct_header"))
        XCTAssertNotEqual(snapshot.id, try harness.persistence.snapshotID(for: "acct_usage"))
        XCTAssertEqual(store.usageWindows.count, 2)
        XCTAssertEqual(store.availableCount, 1)
        XCTAssertEqual(store.errorMessages, [])
    }

    func testSameEmailDifferentAccountIDsRemainSeparateSnapshots() async throws {
        let harness = try StoreHarness()
        var client = harness.client(accountID: "acct_a", email: "same@example.com")
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)
        await store.refresh()

        client = harness.client(accountID: "acct_b", email: "same@example.com")
        let secondStore = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)
        await secondStore.refresh()

        XCTAssertEqual(secondStore.snapshots.count, 2)
        XCTAssertEqual(Set(secondStore.snapshots.map(\.id)).count, 2)
    }

    func testUsageResponseAccountIDCanKeySnapshotWhenAuthFallbackIsMissing() async throws {
        let harness = try StoreHarness()
        try harness.writeAuthWithoutAccountID()
        var client = harness.baseClient
        client.perform = { request in
            try harness.successResponse(for: request, email: "builder@example.com", accountID: "acct_from_usage")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()

        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 0)
        XCTAssertEqual(store.accountDisplayLabel, "builder@example.com")
    }

    func testRepeatedIDLessAuthRefreshRetainsEstablishedSnapshotWhenUsageTemporarilyFails() async throws {
        let harness = try StoreHarness()
        try harness.writeAuthWithoutAccountID()
        let attempts = UsageAttemptState()
        var client = harness.baseClient
        client.perform = { request in
            if request.url?.path == "/backend-api/wham/usage" {
                let attempt = await attempts.next()
                if attempt > 1 {
                    return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
                }
                return try harness.successResponse(
                    for: request,
                    email: "builder@example.com",
                    accountID: "acct_from_usage"
                )
            }
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()
        let firstID = try XCTUnwrap(store.activeSnapshotID)
        let firstCapture = try XCTUnwrap(store.snapshots.first?.usageCapturedAt)

        await store.refresh()

        XCTAssertEqual(store.activeSnapshotID, firstID)
        XCTAssertEqual(store.cachedSnapshots.count, 0)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.snapshots.first?.usageCapturedAt, firstCapture)
        XCTAssertEqual(store.snapshots.first?.resetCountKnown, true)
        XCTAssertEqual(store.liveState, .partial)
        XCTAssertEqual(store.nudge.title, "Usage limits unavailable")
    }

    func testMissingAuthPreservesCachedSnapshotsWithoutShowingThemAsActive() async throws {
        let harness = try StoreHarness()
        let existing = try harness.sampleSnapshot(accountID: "acct_cached")
        try harness.persistence.save([existing])
        try? FileManager.default.removeItem(at: harness.authURL)
        let store = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)

        await store.refresh()

        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.cachedSnapshots.count, 1)
        XCTAssertEqual(store.usageWindows.count, 0)
        XCTAssertEqual(store.availableCount, 0)
        XCTAssertNil(store.lastChecked)
        XCTAssertEqual(store.selectedAccount, .active)
        XCTAssertEqual(store.nudge.title, "Sign in to Codex")
        XCTAssertEqual(store.liveState, .signedOut)
        XCTAssertEqual(store.resetCountState, .unavailable)
        let message = store.errorMessages.joined(separator: " ")
        XCTAssertTrue(message.contains("active account"))
        XCTAssertFalse(message.contains(harness.authURL.path))
        XCTAssertFalse(message.contains("auth.json"))
    }

    func testLiveRefreshErrorSanitizesUnexpectedContentType() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a")
        var client = harness.baseClient
        client.perform = { request in
            if request.url?.path == "/backend-api/wham/usage" {
                return (
                    Data("<html></html>".utf8),
                    testHTTPResponse(status: 200, contentType: "text/html; charset=utf-8")
                )
            }
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()

        let message = store.errorMessages.joined(separator: " ")
        XCTAssertTrue(message.contains("non-JSON"))
        XCTAssertFalse(message.contains("text/html"))
        XCTAssertFalse(message.contains("charset"))
    }

    func testValidAuthEndpointOutageIsNotCalledMissingLogin() async throws {
        let harness = try StoreHarness()
        let store = ResetCreditsStore(
            client: harness.client(accountID: "acct_a", failResetCredits: true, failUsage: true),
            snapshotPersistence: harness.persistence
        )

        await store.refresh()

        XCTAssertEqual(store.liveState, .failed)
        XCTAssertEqual(store.resetCountState, .unavailable)
        XCTAssertEqual(store.nudge.title, "Could not load live data")
        XCTAssertEqual(store.detail(for: .active).statusDetail, "Live check failed")
        XCTAssertFalse(store.nudge.message.localizedCaseInsensitiveContains("sign in"))
        XCTAssertFalse(store.detail(for: .active).statusDetail.localizedCaseInsensitiveContains("login"))
    }

    func testPartialEndpointFailurePersistsSuccessfulUsageWithCoarseError() async throws {
        let harness = try StoreHarness()
        let store = ResetCreditsStore(
            client: harness.client(accountID: "acct_a", failResetCredits: true),
            snapshotPersistence: harness.persistence
        )

        await store.refresh()

        let snapshot = try XCTUnwrap(store.snapshots.first)
        XCTAssertEqual(snapshot.status, .partial)
        XCTAssertTrue(snapshot.errors.contains(.resetCreditsFailed))
        XCTAssertEqual(snapshot.usageWindows.count, 2)
        XCTAssertEqual(snapshot.resetCount, 0)
        XCTAssertFalse(snapshot.resetCountKnown)
        XCTAssertEqual(store.resetCountState, .unavailable)
        XCTAssertEqual(store.nudge.title, "Reset credits unavailable")
    }

    func testResetCreditFailureDoesNotCarryPriorExpiryRowsForward() async throws {
        let harness = try StoreHarness()
        try harness.writeAuth(accountID: "acct_a")
        let state = RequestState()
        var client = harness.baseClient
        client.perform = { request in
            let count = await state.record()
            if count > 2, request.url?.path == "/backend-api/wham/rate-limit-reset-credits" {
                return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
            }
            if count > 2, request.url?.path == "/backend-api/wham/usage" {
                let body = """
                {
                  "email": "builder@example.com",
                  "plan_type": "pro",
                  "rate_limit_reset_credits": {
                    "available_count": 2
                  },
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 20,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 3600,
                      "reset_at": 1800003600
                    },
                    "secondary_window": {
                      "used_percent": 40,
                      "limit_window_seconds": 604800,
                      "reset_after_seconds": 259200,
                      "reset_at": 1800259200
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))
            }
            return try harness.successResponse(for: request, email: "builder@example.com")
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()
        XCTAssertEqual(store.availableCreditDisplays.count, 1)

        await store.refresh()

        let snapshot = try XCTUnwrap(store.snapshots.first)
        XCTAssertEqual(store.availableCreditDisplays.count, 0)
        XCTAssertEqual(store.availableCount, 2)
        XCTAssertEqual(snapshot.resetExpiries, [])
        XCTAssertEqual(snapshot.resetCount, 2)
        XCTAssertTrue(snapshot.errors.contains(.resetCreditsFailed))
        XCTAssertFalse(store.errorMessages.joined(separator: " ").contains("last known"))
    }

    func testBothEndpointFailuresPreserveExistingSnapshotWithoutRewriting() async throws {
        let harness = try StoreHarness()
        let existing = try harness.sampleSnapshot(accountID: "acct_a")
        try harness.persistence.save([existing])
        try harness.writeAuth(accountID: "acct_a")
        var client = harness.baseClient
        client.perform = { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits", "/backend-api/wham/usage":
                return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client, snapshotPersistence: harness.persistence)

        await store.refresh()

        let persisted = try XCTUnwrap(harness.persistence.load().first)
        XCTAssertEqual(persisted.lastChecked, existing.lastChecked)
        XCTAssertEqual(persisted.resetCount, existing.resetCount)
        XCTAssertEqual(persisted.resetExpiries, existing.resetExpiries)
        XCTAssertEqual(persisted.usageWindows, existing.usageWindows)
        XCTAssertEqual(store.availableCount, 0)
        XCTAssertTrue(store.usageWindows.isEmpty)
        XCTAssertEqual(store.liveState, .failed)
        XCTAssertEqual(store.resetCountState, .unavailable)
    }

    func testCachedDetailNeverProvidesLiveSpendOrHoldAdviceAndCanRefreshActiveAccount() throws {
        let harness = try StoreHarness()
        let existing = try harness.sampleSnapshot(accountID: "acct_cached")
        try harness.persistence.save([existing])
        let store = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)

        store.selectCachedAccount(existing.id)
        let detail = store.detail()

        XCTAssertTrue(detail.isCached)
        XCTAssertEqual(detail.liveState, .cached)
        XCTAssertEqual(detail.nudge.tier, .unavailable)
        XCTAssertEqual(detail.nudge.title, "Saved account data")
        XCTAssertTrue(detail.canRefresh)
        XCTAssertEqual(detail.refreshActionTitle, "Refresh active account")
        XCTAssertTrue(detail.nudge.message.contains("not live advice"))
    }

    func testForgetAndClearCachedAccountsPersistDeletion() async throws {
        let harness = try StoreHarness()
        let first = try harness.sampleSnapshot(accountID: "acct_a")
        let second = try harness.sampleSnapshot(accountID: "acct_b")
        try harness.persistence.save([first, second])
        let store = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)

        store.forgetSnapshot(id: first.id)
        XCTAssertEqual(store.snapshots.map(\.id), [second.id])

        let reloaded = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)
        XCTAssertEqual(reloaded.snapshots.map(\.id), [second.id])

        reloaded.clearCachedSnapshots()
        XCTAssertEqual(reloaded.snapshots.count, 0)
        XCTAssertEqual(harness.persistence.load().count, 0)
    }

    func testClearStaleSnapshotsPersistsDeletionWithoutClearingFreshCachedSnapshots() async throws {
        let harness = try StoreHarness()
        let fresh = try harness.sampleSnapshot(accountID: "acct_fresh")
        let stale = try harness.sampleStaleSnapshot(accountID: "acct_stale")
        try harness.persistence.save([fresh, stale])
        let store = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)

        store.selectCachedAccount(stale.id)
        XCTAssertEqual(store.staleCachedSnapshotCount, 1)

        store.clearStaleSnapshots()

        XCTAssertEqual(store.snapshots.map(\.id), [fresh.id])
        XCTAssertEqual(store.selectedAccount, .active)

        let reloaded = ResetCreditsStore(client: harness.baseClient, snapshotPersistence: harness.persistence)
        XCTAssertEqual(reloaded.snapshots.map(\.id), [fresh.id])
    }
}

private actor RequestState {
    private var count = 0

    func record() -> Int {
        count += 1
        return count
    }
}

private actor UsageAttemptState {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

private struct StoreHarness: @unchecked Sendable {
    let directory: URL
    let authURL: URL
    let persistence: AccountSnapshotPersistence
    var baseClient: CodexAPIClient

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        authURL = directory.appendingPathComponent("auth.json")
        persistence = AccountSnapshotPersistence(
            fileURL: directory.appendingPathComponent("account-snapshots.json"),
            salt: "unit-test-salt"
        )
        baseClient = CodexAPIClient()
        baseClient.codexHome = directory
    }

    func client(
        accountID: String,
        email: String = "builder@example.com",
        failResetCredits: Bool = false,
        failUsage: Bool = false,
        usageAccountID: String? = nil
    ) -> CodexAPIClient {
        try? writeAuth(accountID: accountID)
        var client = baseClient
        client.perform = { request in
            if failResetCredits, request.url?.path == "/backend-api/wham/rate-limit-reset-credits" {
                return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
            }
            if failUsage, request.url?.path == "/backend-api/wham/usage" {
                return (Data("{}".utf8), testHTTPResponse(status: 500, contentType: "application/json"))
            }
            return try successResponse(for: request, email: email, accountID: usageAccountID)
        }
        return client
    }

    func writeAuth(accountID: String, accessToken: String = "not-a-jwt") throws {
        let json = #"{"tokens":{"access_token":"\#(accessToken)","account_id":"\#(accountID)"}}"#
        try json.write(to: authURL, atomically: true, encoding: .utf8)
    }

    func writeAuthWithoutAccountID() throws {
        let json = #"{"tokens":{"access_token":"not-a-jwt"}}"#
        try json.write(to: authURL, atomically: true, encoding: .utf8)
    }

    func sampleSnapshot(accountID: String) throws -> CodexAccountSnapshot {
        CodexAccountSnapshot(
            id: try persistence.snapshotID(for: accountID),
            displayLabel: "\(accountID)@example.com",
            planLabel: "Pro",
            lastChecked: Date(timeIntervalSince1970: 1_800_000_000),
            usageWindows: [],
            resetCount: 1,
            resetExpiries: [Date(timeIntervalSince1970: 1_800_010_000)],
            status: .ok,
            errors: []
        )
    }

    func sampleStaleSnapshot(accountID: String) throws -> CodexAccountSnapshot {
        let capturedAt = Date(timeIntervalSince1970: 0)
        return CodexAccountSnapshot(
            id: try persistence.snapshotID(for: accountID),
            displayLabel: "\(accountID)@example.com",
            planLabel: "Pro",
            lastChecked: capturedAt,
            usageWindows: [
                AccountUsageWindowSnapshot(
                    display: UsageLimitDisplay(
                        id: "five-hour",
                        kind: .fiveHour,
                        title: "5h limit",
                        window: UsageLimitWindow(
                            usedPercent: 80,
                            limitWindowSeconds: 18_000,
                            resetAfterSeconds: 1,
                            resetAt: 1
                        ),
                        limitReached: false
                    ),
                    capturedAt: capturedAt
                )
            ],
            resetCount: 1,
            resetExpiries: [Date(timeIntervalSince1970: 1_800_010_000)],
            status: .ok,
            errors: []
        )
    }

    func successResponse(for request: URLRequest, email: String, accountID: String? = nil) throws -> (Data, URLResponse) {
        switch request.url?.path {
        case "/backend-api/wham/rate-limit-reset-credits":
            let body = """
            {
              "available_count": 1,
              "credits": [
                {
                  "id": "credit-full-sensitive",
                  "status": "available",
                  "expires_at": "2027-01-17T19:38:00Z",
                  "title": "One free rate limit reset"
                }
              ]
            }
            """.data(using: .utf8)!
            return (body, testHTTPResponse(status: 200, contentType: "application/json"))

        case "/backend-api/wham/usage":
            let accountLine = accountID.map { #""account_id": "\#($0)","# } ?? ""
            let body = """
            {
              "email": "\(email)",
              \(accountLine)
              "user_id": "user_full_sensitive",
              "plan_type": "pro",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 20,
                  "limit_window_seconds": 18000,
                  "reset_after_seconds": 3600,
                  "reset_at": 1800003600
                },
                "secondary_window": {
                  "used_percent": 40,
                  "limit_window_seconds": 604800,
                  "reset_after_seconds": 259200,
                  "reset_at": 1800259200
                }
              }
            }
            """.data(using: .utf8)!
            return (body, testHTTPResponse(status: 200, contentType: "application/json"))

        default:
            throw TestError.unexpectedEndpoint
        }
    }
}

private enum TestError: Error {
    case unexpectedEndpoint
}

private func testHTTPResponse(status: Int, contentType: String) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: ["Content-Type": contentType]
    )!
}
