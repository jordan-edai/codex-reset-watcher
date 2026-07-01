import Foundation

@MainActor
final class ResetCreditsStore: ObservableObject {
    private struct SnapshotIDResolution {
        let id: AccountSnapshotID?
    }

    private enum ActiveAccountChange {
        case unchanged
        case changed(CodexAuthContext?)
    }

    @Published private(set) var credits: [ResetCredit] = []
    @Published private(set) var availableCount = 0
    @Published private(set) var usage: CodexUsageResponse?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var creditsErrorMessage: String?
    @Published private(set) var usageErrorMessage: String?
    @Published private(set) var accountIdentity = CodexAccountIdentity(accountId: nil, email: nil, name: nil)
    @Published private(set) var activeSnapshotID: AccountSnapshotID?
    @Published private(set) var snapshots: [CodexAccountSnapshot]
    @Published var selectedAccount: AccountSelection = .active

    private let client: CodexAPIClient
    private let snapshotPersistence: AccountSnapshotPersistence
    private var refreshTask: Task<Void, Never>?

    init(
        client: CodexAPIClient = CodexAPIClient(),
        snapshotPersistence: AccountSnapshotPersistence = AccountSnapshotPersistence()
    ) {
        self.client = client
        self.snapshotPersistence = snapshotPersistence
        snapshots = snapshotPersistence.load()
    }

    var availableCredits: [ResetCredit] {
        credits.filter(\.isAvailable)
    }

    var creditDisplays: [ResetCreditDisplay] {
        credits.enumerated().map { index, credit in
            credit.displayModel(fallbackID: "active-reset-\(index)")
        }
    }

    var availableCreditDisplays: [ResetCreditDisplay] {
        availableCredits.enumerated().map { index, credit in
            credit.displayModel(fallbackID: "active-available-reset-\(index)")
        }
    }

    var cachedSnapshots: [CodexAccountSnapshot] {
        snapshots
            .filter { $0.id != activeSnapshotID }
            .sorted { $0.lastChecked > $1.lastChecked }
    }

    var staleCachedSnapshotCount: Int {
        cachedSnapshots.filter { $0.isStale() }.count
    }

    var menuBarTitle: String {
        menuBarTitle(for: .weekly)
    }

    func menuBarTitle(for metric: MenuBarMetric) -> String {
        if let window = usageWindow(for: metric),
           let remaining = window.remainingPercent {
            return "\(remaining)% | \(menuBarResetCue(for: metric, window: window.window))"
        }
        return resetFallbackTitle
    }

    func usageWindow(for metric: MenuBarMetric) -> UsageLimitDisplay? {
        usageWindows.first { metric.matches($0.kind) }
    }

    private var resetFallbackTitle: String {
        "\(availableCount) reset\(availableCount == 1 ? "" : "s")"
    }

    private func menuBarResetCue(for metric: MenuBarMetric, window: UsageLimitWindow) -> String {
        guard let resetDate = resetDate(for: window) else {
            return metric.fallbackCue
        }

        switch metric {
        case .weekly:
            return DateFormatting.weekdayName(resetDate)
        case .fiveHour:
            return DateFormatting.timeOnly(resetDate)
        }
    }

    private func resetDate(for window: UsageLimitWindow) -> Date? {
        if let resetDate = window.resetDate {
            return resetDate
        }
        guard let seconds = window.resetAfterSeconds else {
            return nil
        }
        return Date().addingTimeInterval(TimeInterval(max(0, seconds)))
    }

    var statusSymbolName: String {
        if !errorMessages.isEmpty, usage == nil, credits.isEmpty {
            return "exclamationmark.triangle"
        }
        if usageWindows.contains(where: \.limitReached) {
            return "exclamationmark.octagon"
        }

        switch nudge.tier {
        case .spend, .blocked, .expiringReset, .deadline, .useIfBlocked:
            return "bolt.circle"
        case .waitFiveHour:
            return "hourglass.circle"
        case .hold:
            return "shield"
        case .steady, .noResets, .unavailable:
            return "arrow.clockwise.circle"
        }
    }

    var usageWindows: [UsageLimitDisplay] {
        displays(for: usage)
    }

    var nudge: UsageNudge {
        if usage == nil, !errorMessages.isEmpty {
            return UsageNudge(
                tier: .unavailable,
                title: "Sign in to Codex",
                message: "Open Codex Desktop, sign in, then refresh to load live usage windows.",
                detail: "No live data"
            )
        }

        return UsageNudge.make(
            windows: usageWindows,
            resetCount: availableCount,
            resetUrgencies: resetUrgencies(for: availableCreditDisplays)
        )
    }

    var errorMessages: [String] {
        [usageErrorMessage, creditsErrorMessage].compactMap { $0 }
    }

    var planLabel: String {
        planLabel(for: usage)
    }

    var accountDisplayLabel: String {
        accountIdentity.displayLabel
    }

    var sidebarRows: [AccountSidebarRow] {
        var rows = [
            AccountSidebarRow(
                selection: .active,
                label: accountDisplayLabel,
                detail: activeSidebarDetail,
                systemImage: "person.crop.circle",
                isStale: false
            )
        ]

        rows.append(contentsOf: cachedSnapshots.map { snapshot in
            let stale = snapshot.isStale()
            return AccountSidebarRow(
                selection: .cached(snapshot.id),
                label: snapshot.effectiveLabel,
                detail: stale ? "Stale snapshot" : "Cached \(DateFormatting.timeOnly(snapshot.lastChecked))",
                systemImage: stale ? "clock.badge.exclamationmark" : "clock.arrow.circlepath",
                isStale: stale
            )
        })

        return rows
    }

    private var activeSidebarDetail: String {
        if isRefreshing {
            return "Refreshing active account..."
        }
        if usage == nil, credits.isEmpty, !errorMessages.isEmpty {
            return "No active Codex login"
        }
        return "Active now"
    }

    func detail(for selection: AccountSelection? = nil) -> AccountDetailState {
        let selection = selection ?? selectedAccount
        switch selection {
        case .active:
            return activeDetail()
        case let .cached(id):
            guard let snapshot = cachedSnapshots.first(where: { $0.id == id }) else {
                return activeDetail()
            }
            return cachedDetail(snapshot)
        }
    }

    func select(_ selection: AccountSelection) {
        switch selection {
        case .active:
            selectedAccount = .active
        case let .cached(id):
            selectedAccount = cachedSnapshots.contains(where: { $0.id == id }) ? selection : .active
        }
    }

    func selectCachedAccount(_ id: AccountSnapshotID) {
        select(.cached(id))
    }

    func forgetSnapshot(id: AccountSnapshotID) {
        do {
            snapshots = try snapshotPersistence.delete(id: id, from: snapshots)
        } catch {
            usageErrorMessage = append(message: "Could not forget cached snapshot.", to: usageErrorMessage)
        }
        if selectedAccount == .cached(id) {
            selectedAccount = .active
        }
    }

    func clearCachedSnapshots() {
        let activeOnly = snapshots.filter { $0.id == activeSnapshotID }
        do {
            try snapshotPersistence.save(activeOnly)
            snapshots = activeOnly
        } catch {
            usageErrorMessage = append(message: "Could not clear cached snapshots.", to: usageErrorMessage)
        }
        selectedAccount = .active
    }

    func clearStaleSnapshots() {
        let staleIDs = Set(cachedSnapshots.filter { $0.isStale() }.map(\.id))
        guard !staleIDs.isEmpty else {
            return
        }

        let next = snapshots.filter { !staleIDs.contains($0.id) }
        do {
            try snapshotPersistence.save(next)
            snapshots = next
        } catch {
            usageErrorMessage = append(message: "Could not clear stale snapshots.", to: usageErrorMessage)
        }

        if case let .cached(id) = selectedAccount,
           staleIDs.contains(id) {
            selectedAccount = .active
        }
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 300 * 1_000_000_000)
                } catch {
                    return
                }
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        let context: CodexAuthContext
        do {
            context = try client.loadAuthContext()
        } catch {
            applyMissingAuth(error)
            return
        }

        prepareForActiveContext(context)

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        async let creditsTask = fetchResetCreditsResult(context: context)
        async let usageTask = fetchUsageResult(context: context)
        let creditsResult = await creditsTask
        let usageResult = await usageTask
        let refreshedAt = Date()

        if case let .changed(latestContext) = activeAccountChange(from: context) {
            if let latestContext {
                clearActiveLiveData(context: latestContext, snapshotID: snapshotID(forAccountID: latestContext.accountId))
            } else {
                clearActiveLiveData(
                    context: CodexAuthContext(
                        accessToken: "",
                        accountId: nil,
                        identity: CodexAccountIdentity(accountId: nil, email: nil, name: nil)
                    ),
                    snapshotID: nil
                )
            }
            usageErrorMessage = "Codex account changed during refresh. Refresh again to load the active account cleanly."
            creditsErrorMessage = nil
            lastChecked = refreshedAt
            return
        }

        applyRefreshResults(
            context: context,
            creditsResult: creditsResult,
            usageResult: usageResult,
            refreshedAt: refreshedAt
        )
    }

    private func applyMissingAuth(_ error: Error) {
        usage = nil
        credits = []
        availableCount = 0
        activeSnapshotID = nil
        accountIdentity = CodexAccountIdentity(accountId: nil, email: nil, name: nil)
        usageErrorMessage = refreshErrorMessage(area: "active account", error: error, hasPriorData: false)
        creditsErrorMessage = nil
        lastChecked = nil
        selectedAccount = .active
    }

    private func prepareForActiveContext(_ context: CodexAuthContext) {
        let contextSnapshotID = snapshotID(forAccountID: context.accountId)
        let shouldClear: Bool
        if activeSnapshotID != contextSnapshotID {
            shouldClear = true
        } else if contextSnapshotID == nil, usage != nil || !credits.isEmpty {
            shouldClear = true
        } else {
            shouldClear = false
        }

        guard shouldClear else {
            return
        }

        clearActiveLiveData(context: context, snapshotID: contextSnapshotID)
        usageErrorMessage = nil
        creditsErrorMessage = nil
    }

    private func clearActiveLiveData(context: CodexAuthContext, snapshotID: AccountSnapshotID?) {
        usage = nil
        credits = []
        availableCount = 0
        activeSnapshotID = snapshotID
        accountIdentity = context.identity
    }

    private func applyRefreshResults(
        context: CodexAuthContext,
        creditsResult: Result<ResetCreditsResponse, Error>,
        usageResult: Result<CodexUsageResponse, Error>,
        refreshedAt: Date
    ) {
        let usageResponse = try? usageResult.get()
        let resolution = snapshotIDResolution(for: context, usageResponse: usageResponse)

        let snapshotID = resolution.id
        activeSnapshotID = snapshotID

        switch creditsResult {
        case let .success(response):
            credits = response.credits.sorted(by: sortByExpiry)
            availableCount = response.availableCount
            creditsErrorMessage = nil
        case let .failure(error):
            credits = []
            availableCount = usageResponse?.rateLimitResetCredits?.availableCount ?? 0
            creditsErrorMessage = refreshErrorMessage(
                area: "reset stash",
                error: error,
                hasPriorData: false
            )
        }

        switch usageResult {
        case let .success(response):
            usage = response
            accountIdentity = identity(from: response, context: context)
            if creditsErrorMessage != nil,
               credits.isEmpty,
               let fallbackCount = usage?.rateLimitResetCredits?.availableCount {
                availableCount = fallbackCount
            }
            usageErrorMessage = nil
        case let .failure(error):
            usageErrorMessage = refreshErrorMessage(
                area: "usage meters",
                error: error,
                hasPriorData: usage != nil
            )
            accountIdentity = context.identity
        }

        lastChecked = refreshedAt
        persistSnapshotIfPossible(
            id: snapshotID,
            context: context,
            creditsResult: creditsResult,
            usageResult: usageResult,
            refreshedAt: refreshedAt
        )
    }

    private func persistSnapshotIfPossible(
        id: AccountSnapshotID?,
        context: CodexAuthContext,
        creditsResult: Result<ResetCreditsResponse, Error>,
        usageResult: Result<CodexUsageResponse, Error>,
        refreshedAt: Date
    ) {
        guard let id else {
            return
        }

        let existing = snapshots.first(where: { $0.id == id })
        let creditsResponse = try? creditsResult.get()
        let usageResponse = try? usageResult.get()
        let hasAnySuccess = creditsResponse != nil || usageResponse != nil

        guard hasAnySuccess else {
            return
        }

        var errorCodes: [AccountSnapshotErrorCode] = []
        if case let .failure(error) = creditsResult {
            errorCodes.append(.resetCreditsFailed)
            errorCodes.append(snapshotErrorCode(for: error))
        }
        if case let .failure(error) = usageResult {
            errorCodes.append(.usageFailed)
            errorCodes.append(snapshotErrorCode(for: error))
        }

        let next = makeSnapshot(
            id: id,
            context: context,
            usageResponse: usageResponse,
            creditsResponse: creditsResponse,
            existing: existing,
            errors: Array(Set(errorCodes)).sorted { $0.rawValue < $1.rawValue },
            refreshedAt: refreshedAt,
            hasAnySuccess: hasAnySuccess
        )

        do {
            snapshots = try snapshotPersistence.upsert(next, into: snapshots)
        } catch {
            usageErrorMessage = append(message: "Could not save account snapshot.", to: usageErrorMessage)
        }
    }

    private func makeSnapshot(
        id: AccountSnapshotID,
        context: CodexAuthContext,
        usageResponse: CodexUsageResponse?,
        creditsResponse: ResetCreditsResponse?,
        existing: CodexAccountSnapshot?,
        errors: [AccountSnapshotErrorCode],
        refreshedAt: Date,
        hasAnySuccess: Bool
    ) -> CodexAccountSnapshot {
        let snapshotIdentity = usageResponse.map { identity(from: $0, context: context) } ?? context.identity
        let windows = usageResponse.map { displays(for: $0).map { AccountUsageWindowSnapshot(display: $0, capturedAt: refreshedAt) } }
            ?? existing?.usageWindows
            ?? []
        let resetExpiries = creditsResponse.map { response in
            response.credits
                .filter(\.isAvailable)
                .compactMap { DateFormatting.parse($0.expiresAt) }
                .sorted()
        } ?? []
        let resetCount = creditsResponse?.availableCount
            ?? usageResponse?.rateLimitResetCredits?.availableCount
            ?? 0

        return CodexAccountSnapshot(
            id: id,
            nickname: existing?.nickname,
            displayLabel: snapshotIdentity.displayLabel,
            planLabel: usageResponse.map { planLabel(for: $0) } ?? existing?.planLabel ?? "Codex",
            lastChecked: hasAnySuccess ? refreshedAt : existing?.lastChecked ?? refreshedAt,
            usageWindows: windows,
            resetCount: resetCount,
            resetExpiries: resetExpiries,
            status: CodexAccountSnapshot.status(errors: errors, hasAnySuccess: hasAnySuccess),
            errors: errors
        )
    }

    private func activeAccountChange(from context: CodexAuthContext) -> ActiveAccountChange {
        guard let latest = try? client.loadAuthContext() else {
            return .changed(nil)
        }

        let contextAccountID = normalizedAccountID(context.accountId)
        let latestAccountID = normalizedAccountID(latest.accountId)
        if contextAccountID != nil || latestAccountID != nil {
            return contextAccountID == latestAccountID ? .unchanged : .changed(latest)
        }

        if latest.accessToken != context.accessToken {
            return .changed(latest)
        }
        return .unchanged
    }

    private func snapshotIDResolution(for context: CodexAuthContext, usageResponse: CodexUsageResponse?) -> SnapshotIDResolution {
        let contextAccountID = normalizedAccountID(context.accountId)
        if let contextAccountID {
            return SnapshotIDResolution(id: snapshotID(forAccountID: contextAccountID))
        }

        let usageAccountID = normalizedAccountID(usageResponse?.accountId)
        return SnapshotIDResolution(id: snapshotID(forAccountID: usageAccountID))
    }

    private func snapshotID(forAccountID accountID: String?) -> AccountSnapshotID? {
        guard let accountID = normalizedAccountID(accountID) else {
            return nil
        }
        return try? snapshotPersistence.snapshotID(for: accountID)
    }

    private func normalizedAccountID(_ accountID: String?) -> String? {
        guard let accountID = accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accountID.isEmpty
        else {
            return nil
        }
        return accountID
    }

    private func activeDetail() -> AccountDetailState {
        AccountDetailState(
            selection: .active,
            snapshotID: activeSnapshotID,
            accountLabel: accountDisplayLabel,
            planLabel: planLabel,
            statusTitle: "Active account",
            statusDetail: activeSidebarDetail,
            lastChecked: lastChecked,
            availableCount: availableCount,
            staleSnapshotCount: staleCachedSnapshotCount,
            credits: creditDisplays,
            usageWindows: usageWindows,
            nudge: nudge,
            errorMessages: errorMessages,
            isActive: true,
            isCached: false,
            isStale: false,
            isRefreshing: isRefreshing,
            canRefresh: true,
            canForget: false
        )
    }

    private func cachedDetail(_ snapshot: CodexAccountSnapshot) -> AccountDetailState {
        let stale = snapshot.isStale()
        let windows = snapshot.displays()
        let credits = snapshot.creditDisplays()
        let nudge: UsageNudge
        if stale {
            nudge = UsageNudge(
                tier: .unavailable,
                title: "Stale snapshot",
                message: "These numbers are from the last time this account was active. Sign into this Codex account to refresh it.",
                detail: "Cached"
            )
        } else {
            nudge = UsageNudge.make(
                windows: windows,
                resetCount: snapshot.resetCount,
                resetUrgencies: resetUrgencies(for: credits)
            )
        }

        return AccountDetailState(
            selection: .cached(snapshot.id),
            snapshotID: snapshot.id,
            accountLabel: snapshot.effectiveLabel,
            planLabel: snapshot.planLabel,
            statusTitle: stale ? "Stale snapshot" : "Cached snapshot",
            statusDetail: "Last refreshed \(DateFormatting.weekdayCompact(snapshot.lastChecked))",
            lastChecked: snapshot.lastChecked,
            availableCount: snapshot.resetCount,
            staleSnapshotCount: staleCachedSnapshotCount,
            credits: credits,
            usageWindows: windows,
            nudge: nudge,
            errorMessages: snapshot.errors.map { errorMessage(for: $0) },
            isActive: false,
            isCached: true,
            isStale: stale,
            isRefreshing: false,
            canRefresh: false,
            canForget: true
        )
    }

    private func displays(for usage: CodexUsageResponse?) -> [UsageLimitDisplay] {
        guard let rateLimit = usage?.rateLimit else {
            return []
        }

        var windows: [UsageLimitDisplay] = []
        var seenKinds: Set<UsageLimitDisplay.Kind> = []
        if let primary = rateLimit.primaryWindow {
            appendDisplay(
                for: primary,
                fallbackID: "primary",
                limitReached: rateLimit.limitReached == true || rateLimit.allowed == false,
                to: &windows,
                seenKinds: &seenKinds
            )
        }
        if let secondary = rateLimit.secondaryWindow {
            appendDisplay(
                for: secondary,
                fallbackID: "secondary",
                limitReached: rateLimit.limitReached == true || rateLimit.allowed == false,
                to: &windows,
                seenKinds: &seenKinds
            )
        }
        return windows
    }

    private func planLabel(for usage: CodexUsageResponse?) -> String {
        guard let planType = usage?.planType, !planType.isEmpty else {
            return "Codex"
        }
        return planType
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func identity(from response: CodexUsageResponse, context: CodexAuthContext) -> CodexAccountIdentity {
        CodexAccountIdentity(
            accountId: context.accountId ?? response.accountId,
            email: response.email ?? context.identity.email,
            name: context.identity.name
        )
    }

    private func resetUrgencies(for credits: [ResetCreditDisplay]) -> [ResetExpiryUrgency] {
        credits.map { credit in
            ResetExpiryUrgency.make(
                expiresAt: credit.expiresAt,
                isAvailable: credit.isAvailable
            )
        }
    }

    private func sortByExpiry(_ lhs: ResetCredit, _ rhs: ResetCredit) -> Bool {
        let leftDate = DateFormatting.parse(lhs.expiresAt)
        let rightDate = DateFormatting.parse(rhs.expiresAt)

        switch (leftDate, rightDate) {
        case let (left?, right?):
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return lhs.id < rhs.id
        }
    }

    private func fetchResetCreditsResult(context: CodexAuthContext) async -> Result<ResetCreditsResponse, Error> {
        do {
            return .success(try await client.fetchResetCredits(context: context))
        } catch {
            return .failure(error)
        }
    }

    private func fetchUsageResult(context: CodexAuthContext) async -> Result<CodexUsageResponse, Error> {
        do {
            return .success(try await client.fetchUsage(context: context))
        } catch {
            return .failure(error)
        }
    }

    private func refreshErrorMessage(area: String, error: Error, hasPriorData: Bool) -> String {
        let prefix = hasPriorData ? "Could not refresh \(area); showing the last known numbers." : "Could not load \(area)."
        return "\(prefix) \(liveRefreshErrorDetail(for: error))"
    }

    private func liveRefreshErrorDetail(for error: Error) -> String {
        guard let error = error as? CodexAPIError else {
            return "The refresh failed."
        }

        switch error {
        case .missingAuth:
            return "Open Codex Desktop and sign in first."
        case .invalidAuth:
            return "Open Codex Desktop and sign in again."
        case .invalidResponse:
            return "Codex returned an invalid response."
        case .emptyResponse:
            return "Codex returned an empty response."
        case .unexpectedContentType:
            return "Codex returned a non-JSON response. Open Codex Desktop and sign in again."
        case .rateLimited:
            return "Codex rate-limited this check. Try again later."
        case let .httpStatus(status):
            if status == 401 || status == 403 {
                return "Codex rejected the saved login. Open Codex Desktop and sign in again."
            }
            return "Codex returned an HTTP error."
        case .untrustedEndpoint:
            return "Codex endpoint is not trusted."
        }
    }

    private func snapshotErrorCode(for error: Error) -> AccountSnapshotErrorCode {
        if let error = error as? CodexAPIError {
            switch error {
            case .missingAuth:
                return .missingAuth
            case .invalidAuth:
                return .invalidAuth
            case .invalidResponse:
                return .invalidResponse
            case .emptyResponse:
                return .emptyResponse
            case .unexpectedContentType:
                return .unexpectedContentType
            case .rateLimited:
                return .rateLimited
            case let .httpStatus(status):
                if status == 401 {
                    return .unauthorized
                }
                if status == 403 {
                    return .forbidden
                }
                return .httpStatus
            case .untrustedEndpoint:
                return .invalidResponse
            }
        }
        return .decoding
    }

    private func errorMessage(for code: AccountSnapshotErrorCode) -> String {
        switch code {
        case .missingAuth:
            return "Codex login was missing during the last refresh."
        case .invalidAuth:
            return "Codex login could not be read during the last refresh."
        case .invalidResponse:
            return "Codex returned an invalid response during the last refresh."
        case .emptyResponse:
            return "Codex returned an empty response during the last refresh."
        case .unexpectedContentType:
            return "Codex returned a non-JSON response during the last refresh."
        case .rateLimited:
            return "Codex rate-limited the last refresh."
        case .unauthorized, .forbidden:
            return "Codex rejected the saved login during the last refresh."
        case .httpStatus:
            return "Codex returned an HTTP error during the last refresh."
        case .decoding:
            return "Codex data could not be decoded during the last refresh."
        case .accountChanged:
            return "Codex account changed during refresh."
        case .usageFailed:
            return "Usage meters did not refresh."
        case .resetCreditsFailed:
            return "Reset stash did not refresh."
        case .persistenceFailed:
            return "Account snapshot could not be saved."
        }
    }

    private func append(message: String, to existing: String?) -> String {
        guard let existing, !existing.isEmpty else {
            return message
        }
        return "\(existing) \(message)"
    }

    private func appendDisplay(
        for window: UsageLimitWindow,
        fallbackID: String,
        limitReached: Bool,
        to windows: inout [UsageLimitDisplay],
        seenKinds: inout Set<UsageLimitDisplay.Kind>
    ) {
        var display = display(for: window, fallbackID: fallbackID, limitReached: limitReached)
        if display.kind != .generic, seenKinds.contains(display.kind) {
            display = genericDisplay(for: window, fallbackID: fallbackID, limitReached: limitReached)
        }
        seenKinds.insert(display.kind)
        windows.append(display)
    }

    private func display(for window: UsageLimitWindow, fallbackID: String, limitReached: Bool) -> UsageLimitDisplay {
        guard let seconds = window.limitWindowSeconds else {
            return genericDisplay(for: window, fallbackID: fallbackID, limitReached: limitReached)
        }
        if (14_400...21_600).contains(seconds) {
            return UsageLimitDisplay(id: "five-hour", kind: .fiveHour, title: "5h limit", window: window, limitReached: limitReached)
        }
        if (518_400...864_000).contains(seconds) {
            return UsageLimitDisplay(id: "weekly", kind: .weekly, title: "Weekly limit", window: window, limitReached: limitReached)
        }
        return genericDisplay(for: window, fallbackID: fallbackID, limitReached: limitReached)
    }

    private func genericDisplay(for window: UsageLimitWindow, fallbackID: String, limitReached: Bool) -> UsageLimitDisplay {
        guard let seconds = window.limitWindowSeconds else {
            let title = fallbackID == "primary" ? "Primary limit" : "Secondary limit"
            return UsageLimitDisplay(id: fallbackID, kind: .generic, title: title, window: window, limitReached: limitReached)
        }
        return UsageLimitDisplay(id: fallbackID, kind: .generic, title: DateFormatting.windowTitle(seconds: seconds), window: window, limitReached: limitReached)
    }
}
