import Foundation

enum AccountSnapshotErrorCode: String, Codable, Sendable, Equatable {
    case missingAuth
    case invalidAuth
    case invalidResponse
    case emptyResponse
    case unexpectedContentType
    case rateLimited
    case unauthorized
    case forbidden
    case httpStatus
    case decoding
    case accountChanged
    case usageFailed
    case resetCreditsFailed
    case persistenceFailed
}

enum AccountSnapshotStatus: String, Codable, Sendable, Equatable {
    case ok
    case partial
    case error
}

enum AccountUsageWindowKind: String, Codable, Sendable, Equatable {
    case fiveHour
    case weekly
    case generic

    init(_ kind: UsageLimitDisplay.Kind) {
        switch kind {
        case .fiveHour:
            self = .fiveHour
        case .weekly:
            self = .weekly
        case .generic:
            self = .generic
        }
    }

    var displayKind: UsageLimitDisplay.Kind {
        switch self {
        case .fiveHour:
            return .fiveHour
        case .weekly:
            return .weekly
        case .generic:
            return .generic
        }
    }
}

struct AccountUsageWindowSnapshot: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let kind: AccountUsageWindowKind
    let title: String
    let usedPercent: Int?
    let remainingPercent: Int?
    let limitWindowSeconds: Int?
    let resetAfterSeconds: Int?
    let resetDate: Date?
    let limitReached: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case usedPercent
        case remainingPercent
        case limitWindowSeconds
        case resetAfterSeconds
        case resetDate
        case limitReached
    }

    init(display: UsageLimitDisplay, capturedAt: Date) {
        id = display.id
        kind = AccountUsageWindowKind(display.kind)
        title = display.title
        usedPercent = display.usedPercent
        remainingPercent = display.remainingPercent
        limitWindowSeconds = display.window.limitWindowSeconds
        resetDate = display.window.resetDate
        if let resetDate = display.window.resetDate {
            resetAfterSeconds = safeNonnegativeSeconds(resetDate.timeIntervalSince(capturedAt))
        } else {
            resetAfterSeconds = display.window.resetAfterSeconds
        }
        limitReached = display.limitReached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(AccountUsageWindowKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        usedPercent = clampPercent(try container.decodeIfPresent(Int.self, forKey: .usedPercent))
        let decodedRemaining = clampPercent(try container.decodeIfPresent(Int.self, forKey: .remainingPercent))
        remainingPercent = decodedRemaining ?? usedPercent.map { 100 - $0 }
        limitWindowSeconds = positiveDuration(try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds))
        resetAfterSeconds = nonnegativeDuration(try container.decodeIfPresent(Int.self, forKey: .resetAfterSeconds))
        resetDate = try container.decodeIfPresent(Date.self, forKey: .resetDate)
        limitReached = try container.decodeIfPresent(Bool.self, forKey: .limitReached)
            ?? (remainingPercent == 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(usedPercent, forKey: .usedPercent)
        try container.encodeIfPresent(remainingPercent, forKey: .remainingPercent)
        try container.encodeIfPresent(limitWindowSeconds, forKey: .limitWindowSeconds)
        try container.encodeIfPresent(resetAfterSeconds, forKey: .resetAfterSeconds)
        try container.encodeIfPresent(resetDate, forKey: .resetDate)
        try container.encode(limitReached, forKey: .limitReached)
    }

    func display(cachedAt: Date, now: Date = Date()) -> UsageLimitDisplay {
        let dynamicResetAfter: Int?
        if let resetDate {
            dynamicResetAfter = safeNonnegativeSeconds(resetDate.timeIntervalSince(now))
        } else if let resetAfterSeconds {
            let elapsed = safeNonnegativeSeconds(now.timeIntervalSince(cachedAt)) ?? 0
            dynamicResetAfter = safeSubtractToZero(resetAfterSeconds, elapsed)
        } else {
            dynamicResetAfter = nil
        }

        let used: Int?
        if let usedPercent {
            used = usedPercent
        } else if let remainingPercent {
            used = max(0, min(100, 100 - remainingPercent))
        } else {
            used = nil
        }

        return UsageLimitDisplay(
            id: id,
            kind: kind.displayKind,
            title: title,
            window: UsageLimitWindow(
                usedPercent: used,
                limitWindowSeconds: limitWindowSeconds,
                resetAfterSeconds: dynamicResetAfter,
                resetAt: resetDate?.timeIntervalSince1970
            ),
            limitReached: limitReached
        )
    }

    func hasResetPassed(cachedAt: Date, now: Date) -> Bool {
        if let resetDate {
            return resetDate <= now
        }
        guard let resetAfterSeconds else {
            return false
        }
        return cachedAt.addingTimeInterval(TimeInterval(resetAfterSeconds)) <= now
    }
}

struct ResetCreditDisplay: Identifiable, Sendable, Equatable {
    let id: String
    let title: String?
    let expiresAt: Date?
    let isAvailable: Bool

    init(id: String, title: String?, expiresAt: Date?, isAvailable: Bool) {
        self.id = id
        self.title = title
        self.expiresAt = expiresAt
        self.isAvailable = isAvailable
    }
}

struct CodexAccountSnapshot: Codable, Identifiable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: AccountSnapshotID
    var nickname: String?
    var displayLabel: String
    var planLabel: String
    var lastChecked: Date
    var usageCapturedAt: Date
    var usageWindows: [AccountUsageWindowSnapshot]
    var resetCount: Int
    var resetCountKnown: Bool
    var resetExpiries: [Date]
    var status: AccountSnapshotStatus
    var errors: [AccountSnapshotErrorCode]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case nickname
        case displayLabel
        case planLabel
        case lastChecked
        case usageCapturedAt
        case usageWindows
        case resetCount
        case resetCountKnown
        case resetExpiries
        case status
        case errors
    }

    init(
        id: AccountSnapshotID,
        nickname: String? = nil,
        displayLabel: String,
        planLabel: String,
        lastChecked: Date,
        usageCapturedAt: Date? = nil,
        usageWindows: [AccountUsageWindowSnapshot],
        resetCount: Int,
        resetCountKnown: Bool = true,
        resetExpiries: [Date],
        status: AccountSnapshotStatus,
        errors: [AccountSnapshotErrorCode]
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.nickname = nickname
        self.displayLabel = displayLabel
        self.planLabel = planLabel
        self.lastChecked = lastChecked
        self.usageCapturedAt = usageCapturedAt ?? lastChecked
        self.usageWindows = usageWindows
        let normalizedCount = normalizedResetCreditCount(resetCount)
        self.resetCount = normalizedCount ?? 0
        self.resetCountKnown = resetCountKnown && normalizedCount != nil
        self.resetExpiries = resetExpiries
        self.status = status
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(AccountSnapshotID.self, forKey: .id)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        displayLabel = try container.decode(String.self, forKey: .displayLabel)
        planLabel = try container.decode(String.self, forKey: .planLabel)
        lastChecked = try container.decode(Date.self, forKey: .lastChecked)
        usageCapturedAt = try container.decodeIfPresent(Date.self, forKey: .usageCapturedAt) ?? lastChecked
        usageWindows = try container.decodeIfPresent([AccountUsageWindowSnapshot].self, forKey: .usageWindows) ?? []
        let decodedCount = try container.decodeIfPresent(Int.self, forKey: .resetCount)
        let normalizedCount = normalizedResetCreditCount(decodedCount)
        resetCount = normalizedCount ?? 0
        resetCountKnown = (try container.decodeIfPresent(Bool.self, forKey: .resetCountKnown) ?? (decodedCount != nil))
            && normalizedCount != nil
        resetExpiries = try container.decodeIfPresent([Date].self, forKey: .resetExpiries) ?? []
        status = try container.decodeIfPresent(AccountSnapshotStatus.self, forKey: .status) ?? .ok
        errors = try container.decodeIfPresent([AccountSnapshotErrorCode].self, forKey: .errors) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encode(displayLabel, forKey: .displayLabel)
        try container.encode(planLabel, forKey: .planLabel)
        try container.encode(lastChecked, forKey: .lastChecked)
        try container.encode(usageCapturedAt, forKey: .usageCapturedAt)
        try container.encode(usageWindows, forKey: .usageWindows)
        try container.encode(resetCount, forKey: .resetCount)
        try container.encode(resetCountKnown, forKey: .resetCountKnown)
        try container.encode(resetExpiries, forKey: .resetExpiries)
        try container.encode(status, forKey: .status)
        try container.encode(errors, forKey: .errors)
    }

    var effectiveLabel: String {
        let cleanNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cleanNickname, !cleanNickname.isEmpty {
            return cleanNickname
        }
        return displayLabel
    }

    func isStale(now: Date = Date()) -> Bool {
        if usageWindows.isEmpty, resetExpiries.isEmpty {
            return true
        }
        return usageWindows.contains { $0.hasResetPassed(cachedAt: usageCapturedAt, now: now) }
            || resetExpiries.contains { $0 <= now }
    }

    @MainActor
    func displays(now: Date = Date()) -> [UsageLimitDisplay] {
        usageWindows.map { $0.display(cachedAt: usageCapturedAt, now: now) }
    }

    func creditDisplays(now: Date = Date()) -> [ResetCreditDisplay] {
        resetExpiries.enumerated().map { index, expiry in
            ResetCreditDisplay(
                id: "\(id.rawValue)-reset-\(index)",
                title: "Cached reset credit",
                expiresAt: expiry,
                isAvailable: expiry > now
            )
        }
    }

    static func status(errors: [AccountSnapshotErrorCode], hasAnySuccess: Bool) -> AccountSnapshotStatus {
        if errors.isEmpty {
            return .ok
        }
        return hasAnySuccess ? .partial : .error
    }
}

private func safeNonnegativeSeconds(_ interval: TimeInterval) -> Int? {
    let seconds = floor(interval)
    guard seconds.isFinite else {
        return nil
    }
    if seconds <= 0 {
        return 0
    }
    guard let value = Int(exactly: seconds) else {
        return nil
    }
    return value
}

private func safeSubtractToZero(_ lhs: Int, _ rhs: Int) -> Int {
    let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
    return overflow ? 0 : max(0, result)
}

private func clampPercent(_ value: Int?) -> Int? {
    value.map { min(100, max(0, $0)) }
}

private func positiveDuration(_ value: Int?) -> Int? {
    guard let value, value > 0, value <= 10 * 365 * 86_400 else {
        return nil
    }
    return value
}

private func nonnegativeDuration(_ value: Int?) -> Int? {
    guard let value, value >= 0, value <= 10 * 365 * 86_400 else {
        return nil
    }
    return value
}

extension ResetCredit {
    @MainActor
    func displayModel(fallbackID: String) -> ResetCreditDisplay {
        ResetCreditDisplay(
            id: id.isEmpty ? fallbackID : id,
            title: title,
            expiresAt: DateFormatting.parse(expiresAt),
            isAvailable: isAvailable
        )
    }
}
