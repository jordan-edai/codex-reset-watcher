import Foundation

protocol CodexSemanticallyValidResponse {
    var hasRecognizedPayload: Bool { get }
}

struct CodexUsageResponse: Decodable, Sendable, CodexSemanticallyValidResponse {
    let email: String?
    let accountId: String?
    let userId: String?
    let planType: String?
    let rateLimit: CodexRateLimit?
    let rateLimitResetCredits: ResetCreditCount?
    let hasRecognizedPayload: Bool

    private enum CodingKeys: String, CodingKey {
        case email
        case accountId
        case userId
        case planType
        case rateLimit
        case rateLimitResetCredits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try? container.decode(String.self, forKey: .email)
        accountId = try? container.decode(String.self, forKey: .accountId)
        userId = try? container.decode(String.self, forKey: .userId)
        planType = try? container.decode(String.self, forKey: .planType)
        rateLimit = try? container.decode(CodexRateLimit.self, forKey: .rateLimit)
        rateLimitResetCredits = try? container.decode(ResetCreditCount.self, forKey: .rateLimitResetCredits)
        hasRecognizedPayload = rateLimit != nil || rateLimitResetCredits?.availableCount != nil
    }
}

struct CodexRateLimit: Decodable, Sendable {
    let allowed: Bool?
    let limitReached: Bool?
    let primaryWindow: UsageLimitWindow?
    let secondaryWindow: UsageLimitWindow?

    private enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached
        case primaryWindow
        case secondaryWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowed = container.decodeFlexibleBoolIfPresent(forKey: .allowed)
        limitReached = container.decodeFlexibleBoolIfPresent(forKey: .limitReached)
        primaryWindow = try? container.decode(UsageLimitWindow.self, forKey: .primaryWindow)
        secondaryWindow = try? container.decode(UsageLimitWindow.self, forKey: .secondaryWindow)
    }
}

struct UsageLimitWindow: Decodable, Sendable {
    private static let earliestPlausibleResetEpoch: TimeInterval = 1_577_836_800 // 2020-01-01
    private static let latestPlausibleResetEpoch: TimeInterval = 4_102_444_800 // 2100-01-01
    private static let maximumPlausibleDurationSeconds = 10 * 365 * 86_400

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
        self.usedPercent = Self.clampedPercent(usedPercent)
        self.limitWindowSeconds = Self.positiveDuration(limitWindowSeconds)
        self.resetAfterSeconds = Self.nonnegativeDuration(resetAfterSeconds)
        self.resetAt = resetAt?.isFinite == true ? resetAt : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = Self.clampedPercent(container.decodeFlexibleIntIfPresent(forKey: .usedPercent))
        limitWindowSeconds = Self.positiveDuration(container.decodeFlexibleIntIfPresent(forKey: .limitWindowSeconds))
        resetAfterSeconds = Self.nonnegativeDuration(container.decodeFlexibleIntIfPresent(forKey: .resetAfterSeconds))
        resetAt = container.decodeFlexibleDoubleIfPresent(forKey: .resetAt)
    }

    var remainingPercent: Int? {
        guard let usedPercent else {
            return nil
        }
        return 100 - usedPercent
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

    func resetSecondsRemaining(now: Date = Date()) -> Int? {
        if let resetDate {
            return safeNonnegativeDuration(resetDate.timeIntervalSince(now))
        }
        return resetAfterSeconds
    }

    func anchored(capturedAt: Date, now: Date = Date()) -> UsageLimitWindow {
        let remaining: Int?
        if let resetDate {
            remaining = safeNonnegativeDuration(resetDate.timeIntervalSince(now))
        } else if let resetAfterSeconds {
            let elapsed = safeNonnegativeDuration(now.timeIntervalSince(capturedAt)) ?? 0
            remaining = resetAfterSeconds.subtractingClampedToZero(elapsed)
        } else {
            remaining = nil
        }

        return UsageLimitWindow(
            usedPercent: usedPercent,
            limitWindowSeconds: limitWindowSeconds,
            resetAfterSeconds: remaining,
            resetAt: resetAt
        )
    }

    private static func clampedPercent(_ value: Int?) -> Int? {
        value.map { min(100, max(0, $0)) }
    }

    private static func positiveDuration(_ value: Int?) -> Int? {
        guard let value, value > 0, value <= maximumPlausibleDurationSeconds else {
            return nil
        }
        return value
    }

    private static func nonnegativeDuration(_ value: Int?) -> Int? {
        guard let value, value >= 0, value <= maximumPlausibleDurationSeconds else {
            return nil
        }
        return value
    }
}

struct ResetCreditCount: Decodable, Sendable {
    let availableCount: Int?

    private enum CodingKeys: String, CodingKey {
        case availableCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableCount = normalizedResetCreditCount(
            container.decodeFlexibleIntIfPresent(forKey: .availableCount)
        )
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
        window.usedPercent
    }

    var remainingPercent: Int? {
        window.remainingPercent
    }
}

private extension Int {
    func subtractingClampedToZero(_ other: Int) -> Int {
        let (result, overflow) = subtractingReportingOverflow(other)
        if overflow {
            return self >= 0 && other < 0 ? Int.max : 0
        }
        return Swift.max(0, result)
    }
}

private func safeNonnegativeDuration(_ interval: TimeInterval) -> Int? {
    let seconds = floor(interval)
    guard seconds.isFinite else {
        return nil
    }
    if seconds <= 0 {
        return 0
    }
    return Int(exactly: seconds)
}

extension KeyedDecodingContainer {
    func decodeFlexibleBoolIfPresent(forKey key: Key) -> Bool? {
        guard contains(key), (try? decodeNil(forKey: key)) != true else {
            return nil
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }
        return nil
    }

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
