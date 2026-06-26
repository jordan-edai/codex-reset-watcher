import Foundation

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

    var id: String {
        selection.id
    }
}
