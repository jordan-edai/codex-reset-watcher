import XCTest
@testable import CodexResetWatcher

final class DecodeTests: XCTestCase {
    func testResetCreditsDecodeDropsOnlyMalformedElementsAndDerivesCount() throws {
        let json = """
        {
          "credits": [
            {
              "id": 123,
              "status": "AVAILABLE",
              "expires_at": "2026-07-11T21:13:00Z",
              "title": "One free rate limit reset"
            },
            {
              "status": "available",
              "expires_at": "2026-07-12T21:13:00Z"
            },
            {
              "id": "credit-2",
              "reset_type": "rate_limit",
              "status": "redeemed"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ResetCreditsResponse.self, from: json)

        XCTAssertEqual(response.credits.map(\.id), ["123", "credit-2"])
        XCTAssertEqual(response.credits.first?.resetType, "unknown")
        XCTAssertEqual(response.availableCount, 1)
        XCTAssertTrue(response.credits.first?.isAvailable == true)
    }

    func testNumericFieldsDecodeFromStringsAndDoubles() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let usageJSON = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": "71",
              "limit_window_seconds": 18000.0,
              "reset_after_seconds": "3600",
              "reset_at": "1800000000000"
            }
          },
          "rate_limit_reset_credits": {
            "available_count": 2.0
          }
        }
        """.data(using: .utf8)!

        let usage = try decoder.decode(CodexUsageResponse.self, from: usageJSON)
        let window = try XCTUnwrap(usage.rateLimit?.primaryWindow)
        XCTAssertEqual(window.usedPercent, 71)
        XCTAssertEqual(window.limitWindowSeconds, 18_000)
        XCTAssertEqual(window.resetAfterSeconds, 3_600)
        XCTAssertEqual(window.resetAt, 1_800_000_000_000)
        XCTAssertEqual(usage.rateLimitResetCredits?.availableCount, 2)

        let snakeCaseCredits = #"{"available_count":"3","credits":[]}"#.data(using: .utf8)!
        let camelCaseCredits = #"{"availableCount":4.0,"credits":[]}"#.data(using: .utf8)!

        XCTAssertEqual(try decoder.decode(ResetCreditsResponse.self, from: snakeCaseCredits).availableCount, 3)
        XCTAssertEqual(try decoder.decode(ResetCreditsResponse.self, from: camelCaseCredits).availableCount, 4)
    }

    func testOutOfRangeAndFractionalFlexibleIntegersDecodeAsMissing() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let usageJSON = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": "1e100",
              "limit_window_seconds": 2.5,
              "reset_after_seconds": 9223372036854775808,
              "reset_at": "not-a-number"
            }
          },
          "rate_limit_reset_credits": {
            "available_count": 1e100
          }
        }
        """.data(using: .utf8)!

        let usage = try decoder.decode(CodexUsageResponse.self, from: usageJSON)
        let window = try XCTUnwrap(usage.rateLimit?.primaryWindow)
        XCTAssertNil(window.usedPercent)
        XCTAssertNil(window.limitWindowSeconds)
        XCTAssertNil(window.resetAfterSeconds)
        XCTAssertNil(window.resetAt)
        XCTAssertNil(usage.rateLimitResetCredits?.availableCount)

        let creditsJSON = #"{"available_count":2.5,"credits":[]}"#.data(using: .utf8)!
        XCTAssertEqual(try decoder.decode(ResetCreditsResponse.self, from: creditsJSON).availableCount, 0)
    }

    func testUsageResetAtAcceptsSecondsAndMilliseconds() {
        let seconds = UsageLimitWindow(
            usedPercent: 10,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: 3_600,
            resetAt: 1_800_000_000
        )
        let milliseconds = UsageLimitWindow(
            usedPercent: 10,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: 3_600,
            resetAt: 1_800_000_000_000
        )

        XCTAssertEqual(seconds.resetDate, milliseconds.resetDate)
    }

    func testUsageResetAtRejectsImplausibleEpochs() {
        let absurd = UsageLimitWindow(
            usedPercent: 10,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: nil,
            resetAt: 1e100
        )
        let microseconds = UsageLimitWindow(
            usedPercent: 10,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: nil,
            resetAt: 1_800_000_000_000_000
        )
        let tooOld = UsageLimitWindow(
            usedPercent: 10,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: nil,
            resetAt: 1
        )

        XCTAssertNil(absurd.resetDate)
        XCTAssertNil(microseconds.resetDate)
        XCTAssertNil(tooOld.resetDate)
    }

    func testAccountDisplayLabelDoesNotLeakRawAccountSuffix() {
        let identity = CodexAccountIdentity(accountId: "acct_sensitive_1234567890", email: nil, name: nil)

        XCTAssertEqual(identity.displayLabel, "Codex account")
    }

    @MainActor
    func testWeekdayCompactIncludesDayOfWeek() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = 7
        components.day = 17
        components.hour = 19
        components.minute = 38

        let value = DateFormatting.weekdayCompact(components.date)

        XCTAssertTrue(value.hasPrefix("Fri, Jul 17 at "))
    }

    @MainActor
    func testWeekdayDateAndTimeOnlySplitMenuDates() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = 7
        components.day = 17
        components.hour = 19
        components.minute = 38

        XCTAssertEqual(DateFormatting.weekdayDate(components.date), "Fri, Jul 17")
        XCTAssertEqual(DateFormatting.timeOnly(components.date), "7:38 PM")
    }

    @MainActor
    func testZeroDurationDisplaysAsNow() {
        XCTAssertEqual(DateFormatting.duration(seconds: 0), "now")
        XCTAssertEqual(DateFormatting.duration(seconds: -30), "now")
    }

    func testBase64URLDecodesUnpaddedPayload() {
        let decoded = Data(base64URLString: "eyJhY2NvdW50IjoiYWNjdF8xMjMifQ")

        XCTAssertEqual(String(data: decoded ?? Data(), encoding: .utf8), #"{"account":"acct_123"}"#)
    }

    func testBase64URLInvalidPayloadReturnsNil() {
        XCTAssertNil(Data(base64URLString: "***"))
    }
}

final class CodexAPIClientTests: XCTestCase {
    func testFetchUsageSetsAuthorizationAndAccountHeaders() async throws {
        let client = try makeClient(
            authJSON: makeAuthJSON(accessToken: "not-a-jwt", accountID: "acct_fallback")
        ) { request in
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer not-a-jwt",
                  request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "acct_fallback"
            else {
                throw TestError.unexpectedHeader
            }

            let body = #"{"plan_type":"pro","rate_limit":{}}"#.data(using: .utf8)!
            return (body, testHTTPResponse(status: 200, contentType: "application/json"))
        }

        let response = try await client.fetchUsage()

        XCTAssertEqual(response.planType, "pro")
    }

    func testUntrustedEndpointFailsBeforeSendingRequest() async throws {
        var client = try makeClient { _ in
            throw TestError.unexpectedEndpoint
        }
        client.usageEndpoint = URL(string: "https://example.com/backend-api/wham/usage")!

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected untrustedEndpoint")
        } catch CodexAPIError.untrustedEndpoint {
        } catch {
            XCTFail("Expected untrustedEndpoint, got \(error)")
        }
    }

    func testTrustedEndpointRequiresExactCodexWhamPath() async throws {
        var client = try makeClient { _ in
            throw TestError.unexpectedEndpoint
        }
        client.usageEndpoint = URL(string: "https://chatgpt.com/not-the-codex-endpoint")!

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected untrustedEndpoint")
        } catch CodexAPIError.untrustedEndpoint {
        } catch {
            XCTFail("Expected untrustedEndpoint, got \(error)")
        }
    }

    func testTrustedEndpointRejectsQueryUserInfoFragmentAndPort() {
        let urls = [
            "https://chatgpt.com/backend-api/wham/usage?debug=1",
            "https://user:pass@chatgpt.com/backend-api/wham/usage",
            "https://chatgpt.com:443/backend-api/wham/usage",
            "https://chatgpt.com/backend-api/wham/usage#fragment",
            "http://chatgpt.com/backend-api/wham/usage"
        ]

        for url in urls {
            XCTAssertFalse(CodexAPIClient.isTrustedEndpoint(URL(string: url)!), url)
        }

        XCTAssertTrue(CodexAPIClient.isTrustedEndpoint(URL(string: "https://chatgpt.com/backend-api/wham/usage")!))
        XCTAssertTrue(CodexAPIClient.isTrustedEndpoint(URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!))
    }

    func testEmptySuccessfulResponseHasClearError() async throws {
        let client = try makeClient { _ in
            (Data(), testHTTPResponse(status: 200, contentType: "application/json"))
        }

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected emptyResponse")
        } catch CodexAPIError.emptyResponse {
        }
    }

    func testHTMLSuccessfulResponseHasClearError() async throws {
        let client = try makeClient { _ in
            ("<html></html>".data(using: .utf8)!, testHTTPResponse(status: 200, contentType: "text/html"))
        }

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected unexpectedContentType")
        } catch CodexAPIError.unexpectedContentType(let contentType) {
            XCTAssertEqual(contentType, "text/html")
        }
    }

    func testRateLimitResponseHasClearError() async throws {
        let client = try makeClient { _ in
            (Data("{}".utf8), testHTTPResponse(status: 429, contentType: "application/json", retryAfter: "30"))
        }

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected rateLimited")
        } catch CodexAPIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, "30")
        }
    }

    @MainActor
    func testStoreUsesServerAvailableCountWhenCreditRowsArePartiallyMalformed() async throws {
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = """
                {
                  "available_count": 2,
                  "credits": [
                    {
                      "id": "credit-1",
                      "status": "available",
                      "expires_at": "2026-07-11T21:13:00Z"
                    },
                    {
                      "status": "available",
                      "expires_at": "2026-07-12T21:13:00Z"
                    }
                  ]
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = #"{"plan_type":"pro","rate_limit":{}}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertEqual(store.availableCredits.count, 1)
        XCTAssertEqual(store.availableCount, 2)
    }

    @MainActor
    func testMenuBarTitleShowsSelectedUsageWindowResetCueWhenUsageIsLoaded() async throws {
        let fiveHourResetAt = localTimestamp(year: 2026, month: 7, day: 17, hour: 21, minute: 50)
        let weeklyResetAt = localTimestamp(year: 2026, month: 7, day: 19, hour: 8, minute: 0)
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = #"{"available_count":1,"credits":[]}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = """
                {
                  "email": "builder@example.com",
                  "plan_type": "pro",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 71,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 3600,
                      "reset_at": \(fiveHourResetAt)
                    },
                    "secondary_window": {
                      "used_percent": 37,
                      "limit_window_seconds": 604800,
                      "reset_after_seconds": 259200,
                      "reset_at": \(weeklyResetAt)
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertEqual(store.menuBarTitle, "63% | Sunday")
        XCTAssertEqual(store.menuBarTitle(for: .weekly), "63% | Sunday")
        XCTAssertEqual(store.menuBarTitle(for: .fiveHour), "29% | 9:50 PM")
        XCTAssertEqual(store.accountDisplayLabel, "builder@example.com")
    }

    @MainActor
    func testUsageWindowClassificationPrefersDurationWhenEndpointOrderIsSwapped() async throws {
        let fiveHourResetAt = localTimestamp(year: 2026, month: 7, day: 17, hour: 21, minute: 50)
        let weeklyResetAt = localTimestamp(year: 2026, month: 7, day: 19, hour: 8, minute: 0)
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = #"{"available_count":0,"credits":[]}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = """
                {
                  "plan_type": "pro",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 37,
                      "limit_window_seconds": 604800,
                      "reset_after_seconds": 259200,
                      "reset_at": \(weeklyResetAt)
                    },
                    "secondary_window": {
                      "used_percent": 71,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 3600,
                      "reset_at": \(fiveHourResetAt)
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertEqual(store.usageWindow(for: .weekly)?.id, "weekly")
        XCTAssertEqual(store.usageWindow(for: .fiveHour)?.id, "five-hour")
        XCTAssertEqual(store.menuBarTitle(for: .weekly), "63% | Sunday")
        XCTAssertEqual(store.menuBarTitle(for: .fiveHour), "29% | 9:50 PM")
    }

    @MainActor
    func testUsageWindowClassificationDoesNotInventKnownWindowsWithoutDuration() async throws {
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = #"{"available_count":0,"credits":[]}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = """
                {
                  "plan_type": "pro",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 20,
                      "reset_after_seconds": 3600
                    },
                    "secondary_window": {
                      "used_percent": 40,
                      "reset_after_seconds": 7200
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertEqual(store.usageWindows.map(\.kind), [.generic, .generic])
        XCTAssertEqual(store.usageWindows.map(\.id), ["primary", "secondary"])
        XCTAssertNil(store.usageWindow(for: .weekly))
        XCTAssertNil(store.usageWindow(for: .fiveHour))
    }

    @MainActor
    func testDuplicateWindowDurationKeepsOneKnownWindow() async throws {
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = #"{"available_count":0,"credits":[]}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = """
                {
                  "plan_type": "pro",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 20,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 3600
                    },
                    "secondary_window": {
                      "used_percent": 40,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 7200
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertEqual(store.usageWindows.map(\.kind), [.fiveHour, .generic])
        XCTAssertEqual(store.usageWindows.map(\.id), ["five-hour", "secondary"])
        XCTAssertEqual(store.usageWindow(for: .fiveHour)?.remainingPercent, 80)
    }

    @MainActor
    func testLimitReachedResponseDrivesBlockedNudge() async throws {
        let client = try makeClient { request in
            switch request.url?.path {
            case "/backend-api/wham/rate-limit-reset-credits":
                let body = #"{"available_count":1,"credits":[]}"#.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            case "/backend-api/wham/usage":
                let body = """
                {
                  "plan_type": "pro",
                  "rate_limit": {
                    "allowed": false,
                    "primary_window": {
                      "used_percent": 20,
                      "limit_window_seconds": 18000,
                      "reset_after_seconds": 3600
                    },
                    "secondary_window": {
                      "used_percent": 40,
                      "limit_window_seconds": 604800,
                      "reset_after_seconds": 259200
                    }
                  }
                }
                """.data(using: .utf8)!
                return (body, testHTTPResponse(status: 200, contentType: "application/json"))

            default:
                throw TestError.unexpectedEndpoint
            }
        }
        let store = ResetCreditsStore(client: client)

        await store.refresh()

        XCTAssertTrue(store.usageWindows.allSatisfy(\.limitReached))
        XCTAssertEqual(store.nudge.tier, .blocked)
        XCTAssertEqual(store.nudge.title, "Blocked now")
        XCTAssertEqual(store.statusSymbolName, "exclamationmark.octagon")
    }

    private func makeClient(
        authJSON: String? = nil,
        perform: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) throws -> CodexAPIClient {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let authJSON = authJSON ?? makeAuthJSON(accessToken: "not-a-jwt", accountID: "acct_test")
        try authJSON.write(to: directory.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        var client = CodexAPIClient()
        client.codexHome = directory
        client.perform = perform
        return client
    }

}

private enum TestError: Error {
    case unexpectedHeader
    case unexpectedEndpoint
}

private func makeAuthJSON(accessToken: String, accountID: String?) -> String {
    if let accountID {
        return #"{"tokens":{"access_token":"\#(accessToken)","account_id":"\#(accountID)"}}"#
    }
    return #"{"tokens":{"access_token":"\#(accessToken)"}}"#
}

private func localTimestamp(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Int {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = .current
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return Int(components.date!.timeIntervalSince1970)
}

private func testHTTPResponse(
    status: Int,
    contentType: String,
    retryAfter: String? = nil
) -> HTTPURLResponse {
    var headers = ["Content-Type": contentType]
    if let retryAfter {
        headers["Retry-After"] = retryAfter
    }
    return HTTPURLResponse(
        url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
}
