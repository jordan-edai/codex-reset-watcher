import Foundation

struct CodexUsageResponse: Decodable, Sendable {
    let planType: String?
    let rateLimit: CodexRateLimit?
    let rateLimitResetCredits: ResetCreditCount?
}

struct CodexRateLimit: Decodable, Sendable {
    let allowed: Bool?
    let limitReached: Bool?
    let primaryWindow: UsageLimitWindow?
    let secondaryWindow: UsageLimitWindow?
}

struct UsageLimitWindow: Decodable, Sendable {
    let usedPercent: Int?
    let limitWindowSeconds: Int?
    let resetAfterSeconds: Int?
    let resetAt: TimeInterval?

    var remainingPercent: Int? {
        guard let usedPercent else {
            return nil
        }
        return max(0, min(100, 100 - usedPercent))
    }

    var resetDate: Date? {
        guard let resetAt else {
            return nil
        }
        let seconds = resetAt > 10_000_000_000 ? resetAt / 1_000 : resetAt
        return Date(timeIntervalSince1970: seconds)
    }
}

struct ResetCreditCount: Decodable, Sendable {
    let availableCount: Int?
}

struct UsageLimitDisplay: Identifiable, Sendable {
    enum Kind: Sendable {
        case fiveHour
        case weekly
        case generic
    }

    let id: String
    let kind: Kind
    let title: String
    let window: UsageLimitWindow
    let limitReached: Bool

    var usedPercent: Int? {
        window.usedPercent.map { max(0, min(100, $0)) }
    }

    var remainingPercent: Int? {
        window.remainingPercent
    }
}
