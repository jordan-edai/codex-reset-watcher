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

    init(display: UsageLimitDisplay, capturedAt: Date) {
        id = display.id
        kind = AccountUsageWindowKind(display.kind)
        title = display.title
        usedPercent = display.usedPercent
        remainingPercent = display.remainingPercent
        limitWindowSeconds = display.window.limitWindowSeconds
        resetDate = display.window.resetDate
        if let resetDate = display.window.resetDate {
            resetAfterSeconds = max(0, Int(resetDate.timeIntervalSince(capturedAt)))
        } else {
            resetAfterSeconds = display.window.resetAfterSeconds
        }
    }

    func display(cachedAt: Date, now: Date = Date()) -> UsageLimitDisplay {
        let dynamicResetAfter: Int?
        if let resetDate {
            dynamicResetAfter = max(0, Int(resetDate.timeIntervalSince(now)))
        } else if let resetAfterSeconds {
            let elapsed = max(0, Int(now.timeIntervalSince(cachedAt)))
            dynamicResetAfter = max(0, resetAfterSeconds - elapsed)
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
            limitReached: remainingPercent == 0
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
    var usageWindows: [AccountUsageWindowSnapshot]
    var resetCount: Int
    var resetExpiries: [Date]
    var status: AccountSnapshotStatus
    var errors: [AccountSnapshotErrorCode]

    init(
        id: AccountSnapshotID,
        nickname: String? = nil,
        displayLabel: String,
        planLabel: String,
        lastChecked: Date,
        usageWindows: [AccountUsageWindowSnapshot],
        resetCount: Int,
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
        self.usageWindows = usageWindows
        self.resetCount = resetCount
        self.resetExpiries = resetExpiries
        self.status = status
        self.errors = errors
    }

    var effectiveLabel: String {
        let cleanNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cleanNickname, !cleanNickname.isEmpty {
            return cleanNickname
        }
        return displayLabel
    }

    func isStale(now: Date = Date()) -> Bool {
        usageWindows.contains { $0.hasResetPassed(cachedAt: lastChecked, now: now) }
    }

    @MainActor
    func displays(now: Date = Date()) -> [UsageLimitDisplay] {
        usageWindows.map { $0.display(cachedAt: lastChecked, now: now) }
    }

    func creditDisplays() -> [ResetCreditDisplay] {
        resetExpiries.enumerated().map { index, expiry in
            ResetCreditDisplay(
                id: "\(id.rawValue)-reset-\(index)",
                title: "Cached reset credit",
                expiresAt: expiry,
                isAvailable: expiry > Date()
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
