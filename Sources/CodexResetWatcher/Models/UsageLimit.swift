import Foundation

struct CodexUsageResponse: Decodable, Sendable {
    let email: String?
    let accountId: String?
    let userId: String?
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
    private static let earliestPlausibleResetEpoch: TimeInterval = 1_577_836_800 // 2020-01-01
    private static let latestPlausibleResetEpoch: TimeInterval = 4_102_444_800 // 2100-01-01

    let usedPercent: Int?
    let limitWindowSeconds: Int?
    let resetAfterSeconds: Int?
    let resetAt: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case usedPercent
        case limitWindowSeconds
        case resetAfterSeconds
        case resetAt
    }

    init(
        usedPercent: Int?,
        limitWindowSeconds: Int?,
        resetAfterSeconds: Int?,
        resetAt: TimeInterval?
    ) {
        self.usedPercent = usedPercent
        self.limitWindowSeconds = limitWindowSeconds
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = container.decodeFlexibleIntIfPresent(forKey: .usedPercent)
        limitWindowSeconds = container.decodeFlexibleIntIfPresent(forKey: .limitWindowSeconds)
        resetAfterSeconds = container.decodeFlexibleIntIfPresent(forKey: .resetAfterSeconds)
        resetAt = container.decodeFlexibleDoubleIfPresent(forKey: .resetAt)
    }

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
        guard seconds.isFinite,
              (Self.earliestPlausibleResetEpoch...Self.latestPlausibleResetEpoch).contains(seconds)
        else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }
}

struct ResetCreditCount: Decodable, Sendable {
    let availableCount: Int?

    private enum CodingKeys: String, CodingKey {
        case availableCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableCount = container.decodeFlexibleIntIfPresent(forKey: .availableCount)
    }
}

struct UsageLimitDisplay: Identifiable, Sendable {
    enum Kind: Sendable, Hashable {
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

extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        guard contains(key),
              (try? decodeNil(forKey: key)) != true
        else {
            return nil
        }

        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(Double.self, forKey: key),
           let intValue = Int(exactlySafe: value) {
            return intValue
        }
        if let value = try? decode(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intValue = Int(trimmed) {
                return intValue
            }
            if let doubleValue = Double(trimmed),
               let intValue = Int(exactlySafe: doubleValue) {
                return intValue
            }
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        guard contains(key),
              (try? decodeNil(forKey: key)) != true
        else {
            return nil
        }

        if let value = try? decode(Double.self, forKey: key), value.isFinite {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decode(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let doubleValue = Double(trimmed), doubleValue.isFinite {
                return doubleValue
            }
        }
        return nil
    }
}

private extension Int {
    init?(exactlySafe value: Double) {
        guard value.isFinite,
              let exactValue = Self(exactly: value)
        else {
            return nil
        }
        self = exactValue
    }
}
