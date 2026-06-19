import Foundation

struct CodexAPIClient: Sendable {
    var codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    var resetCreditsEndpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    var usageEndpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    var timeoutSeconds: TimeInterval = 20
    var perform: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }

    func fetchResetCredits() async throws -> ResetCreditsResponse {
        try await fetch(ResetCreditsResponse.self, from: resetCreditsEndpoint)
    }

    func fetchUsage() async throws -> CodexUsageResponse {
        try await fetch(CodexUsageResponse.self, from: usageEndpoint)
    }

    private func fetch<Response: Decodable>(_ responseType: Response.Type, from endpoint: URL) async throws -> Response {
        let auth = try loadAuth()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountId = accountId(from: auth.tokens.accessToken, fallback: auth.tokens.accountId) {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw CodexAPIError.rateLimited(httpResponse.value(forHTTPHeaderField: "Retry-After"))
            }
            throw CodexAPIError.httpStatus(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw CodexAPIError.emptyResponse
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.localizedCaseInsensitiveContains("json") {
            throw CodexAPIError.unexpectedContentType(contentType)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private func loadAuth() throws -> CodexAuth {
        let authURL = resolvedCodexHome().appending(path: "auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexAPIError.missingAuth(authURL.path)
        }

        let data = try Data(contentsOf: authURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CodexAuth.self, from: data)
        } catch {
            throw CodexAPIError.invalidAuth(authURL.path)
        }
    }

    private func resolvedCodexHome() -> URL {
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }
        return codexHome
    }

    private func accountId(from token: String, fallback: String?) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64URLString: String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any]
        else {
            return fallback
        }

        return auth["chatgpt_account_id"] as? String ?? fallback
    }
}

enum CodexAPIError: LocalizedError {
    case missingAuth(String)
    case invalidAuth(String)
    case invalidResponse
    case emptyResponse
    case unexpectedContentType(String)
    case rateLimited(String?)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case let .missingAuth(path):
            return "Could not find Codex login at \(path). Open Codex Desktop and sign in first."
        case let .invalidAuth(path):
            return "Could not read Codex login at \(path). Open Codex Desktop and sign in again."
        case .invalidResponse:
            return "The Codex endpoint returned an invalid response."
        case .emptyResponse:
            return "The Codex endpoint returned an empty response."
        case let .unexpectedContentType(contentType):
            return "The Codex endpoint returned \(contentType) instead of JSON. Open Codex Desktop and sign in again."
        case let .rateLimited(retryAfter):
            if let retryAfter, !retryAfter.isEmpty {
                return "Codex rate-limited this check. Try again after \(retryAfter) seconds."
            }
            return "Codex rate-limited this check. Try again later."
        case let .httpStatus(status):
            if status == 401 || status == 403 {
                return "Codex rejected the saved login. Open Codex Desktop and sign in again."
            }
            return "The Codex endpoint returned HTTP \(status)."
        }
    }
}
