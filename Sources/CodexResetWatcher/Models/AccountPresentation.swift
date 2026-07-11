import Foundation

enum LiveAccountState: Equatable, Sendable {
    case loading
    case live
    case partial
    case signedOut
    case failed
    case cached
}

enum ResetCountState: Equatable, Sendable {
    case loading
    case known(Int)
    case unavailable

    var count: Int? {
        guard case let .known(count) = self else {
            return nil
        }
        return count
    }

    var isKnown: Bool {
        count != nil
    }
}

struct AccountSidebarRow: Identifiable, Equatable {
    let selection: AccountSelection
    let label: String
    let detail: String
    let systemImage: String
    let isStale: Bool

    var id: String {
        selection.id
    }
}

struct AccountDetailState: Identifiable {
    let selection: AccountSelection
    let snapshotID: AccountSnapshotID?
    let accountLabel: String
    let planLabel: String
    let statusTitle: String
    let statusDetail: String
    let lastChecked: Date?
    let availableCount: Int
    let resetCountState: ResetCountState
    let liveState: LiveAccountState
    let staleSnapshotCount: Int
    let credits: [ResetCreditDisplay]
    let usageWindows: [UsageLimitDisplay]
    let nudge: UsageNudge
    let errorMessages: [String]
    let isActive: Bool
    let isCached: Bool
    let isStale: Bool
    let isRefreshing: Bool
    let canRefresh: Bool
    let canForget: Bool
    let refreshActionTitle: String

    var id: String {
        selection.id
    }
}
