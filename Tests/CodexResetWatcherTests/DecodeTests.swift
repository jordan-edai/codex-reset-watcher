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
    func testMenuBarTitleShowsSelectedUsageWindowWhenUsageIsLoaded() async throws {
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
                      "reset_after_seconds": 3600
                    },
                    "secondary_window": {
                      "used_percent": 37,
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

        XCTAssertEqual(store.menuBarTitle, "63% | week")
        XCTAssertEqual(store.menuBarTitle(for: .weekly), "63% | week")
        XCTAssertEqual(store.menuBarTitle(for: .fiveHour), "29% | 5h")
        XCTAssertEqual(store.accountDisplayLabel, "builder@example.com")
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
