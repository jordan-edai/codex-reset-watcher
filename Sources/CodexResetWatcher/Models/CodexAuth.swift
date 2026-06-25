import Foundation

struct CodexAuth: Decodable, Sendable {
    let tokens: Tokens

    struct Tokens: Decodable, Sendable {
        let idToken: String?
        let accessToken: String
        let accountId: String?
    }
}

struct CodexAccountIdentity: Sendable, Equatable {
    let accountId: String?
    let email: String?
    let name: String?

    var displayLabel: String {
        if let email = clean(email) {
            return email
        }
        if let name = clean(name) {
            return name
        }
        if let accountId = clean(accountId) {
            return "Codex account \(accountId.suffix(6))"
        }
        return "Codex account"
    }

    private func clean(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
