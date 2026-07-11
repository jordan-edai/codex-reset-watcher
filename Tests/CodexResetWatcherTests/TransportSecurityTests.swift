import Foundation
import XCTest
@testable import CodexResetWatcher

final class TransportSecurityTests: XCTestCase {
    func testRejectsSuccessfulResponseFromUntrustedFinalURL() async throws {
        let client = try makeClient { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com/backend-api/wham/usage")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Self.usageResponse, response)
        }

        do {
            _ = try await client.fetchUsage()
            XCTFail("Expected the final response URL to be rejected")
        } catch CodexAPIError.untrustedEndpoint {
        } catch {
            XCTFail("Expected untrustedEndpoint, got \(error)")
        }
    }

    func testAcceptsSuccessfulResponseFromTrustedFinalURL() async throws {
        let client = try makeClient { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Self.usageResponse, response)
        }

        let response = try await client.fetchUsage()

        XCTAssertEqual(response.planType, "pro")
    }

    private func makeClient(
        perform: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) throws -> CodexAPIClient {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let auth = #"{"tokens":{"access_token":"test-token","account_id":"acct_test"}}"#
        try auth.write(
            to: directory.appendingPathComponent("auth.json"),
            atomically: true,
            encoding: .utf8
        )

        var client = CodexAPIClient()
        client.codexHome = directory
        client.perform = perform
        return client
    }

    private static let usageResponse = #"{"plan_type":"pro","rate_limit":{}}"#.data(using: .utf8)!
}
