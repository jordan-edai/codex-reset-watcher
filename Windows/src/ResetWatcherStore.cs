using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal sealed class ResetWatcherStore : IDisposable
    {
        private readonly CodexClient client;
        private readonly AccountSnapshotPersistence snapshotPersistence;
        private readonly System.Windows.Forms.Timer timer;
        private readonly object gate = new object();
        private bool isRefreshing;

        public event EventHandler Changed;

        public List<ResetCredit> Credits = new List<ResetCredit>();
        public int AvailableCount;
        public CodexUsageResponse Usage;
        public DateTimeOffset? LastChecked;
        public string CreditsErrorMessage;
        public string UsageErrorMessage;
        public CodexAccountIdentity AccountIdentity = new CodexAccountIdentity();
        public string ActiveSnapshotId;
        public List<CodexAccountSnapshot> Snapshots;
        public string SelectedSnapshotId;

        public ResetWatcherStore() : this(new CodexClient(), new AccountSnapshotPersistence())
        {
        }

        public ResetWatcherStore(CodexClient client, AccountSnapshotPersistence snapshotPersistence)
        {
            this.client = client;
            this.snapshotPersistence = snapshotPersistence;
            Snapshots = snapshotPersistence.Load();
            timer = new System.Windows.Forms.Timer();
            timer.Interval = 300000;
            timer.Tick += delegate { BeginRefresh(); };
        }

        public bool IsRefreshing
        {
            get { lock (gate) { return isRefreshing; } }
        }

        public string AccountDisplayLabel
        {
            get { return AccountIdentity == null ? "Codex account" : AccountIdentity.DisplayLabel; }
        }

        public string PlanLabel
        {
            get { return PlanLabelFor(Usage); }
        }

        public List<UsageLimitDisplay> UsageWindows
        {
            get { return Usage == null ? new List<UsageLimitDisplay>() : Usage.Windows; }
        }

        public List<ResetCreditDisplay> CreditDisplays
        {
            get
            {
                List<ResetCreditDisplay> displays = new List<ResetCreditDisplay>();
                for (int i = 0; i < Credits.Count; i++)
                {
                    displays.Add(Credits[i].ToDisplay("active-reset-" + i));
                }
                return displays;
            }
        }

        public List<ResetCreditDisplay> AvailableCreditDisplays
        {
            get
            {
                List<ResetCreditDisplay> displays = new List<ResetCreditDisplay>();
                for (int i = 0; i < Credits.Count; i++)
                {
                    if (Credits[i].IsAvailable)
                    {
                        displays.Add(Credits[i].ToDisplay("active-available-reset-" + i));
                    }
                }
                return displays;
            }
        }

        public List<CodexAccountSnapshot> CachedSnapshots
        {
            get
            {
                List<CodexAccountSnapshot> cached = new List<CodexAccountSnapshot>();
                foreach (CodexAccountSnapshot snapshot in Snapshots)
                {
                    if (!String.Equals(snapshot.Id, ActiveSnapshotId, StringComparison.OrdinalIgnoreCase))
                    {
                        cached.Add(snapshot);
                    }
                }
                cached.Sort((a, b) => b.LastChecked.CompareTo(a.LastChecked));
                return cached;
            }
        }

        public int StaleCachedSnapshotCount
        {
            get
            {
                int count = 0;
                DateTimeOffset now = DateTimeOffset.Now;
                foreach (CodexAccountSnapshot snapshot in CachedSnapshots)
                {
                    if (snapshot.IsStale(now))
                    {
                        count++;
                    }
                }
                return count;
            }
        }

        public List<string> ErrorMessages
        {
            get
            {
                List<string> errors = new List<string>();
                if (!String.IsNullOrWhiteSpace(UsageErrorMessage))
                {
                    errors.Add(UsageErrorMessage);
                }
                if (!String.IsNullOrWhiteSpace(CreditsErrorMessage))
                {
                    errors.Add(CreditsErrorMessage);
                }
                return errors;
            }
        }

        public UsageNudge Nudge
        {
            get { return UsageNudge.Make(UsageWindows, AvailableCount, ResetUrgenciesFor(AvailableCreditDisplays)); }
        }

        public void Start()
        {
            BeginRefresh();
            timer.Start();
        }

        public void BeginRefresh()
        {
            Task.Factory.StartNew(
                async delegate { await RefreshAsync(); },
                CancellationToken.None,
                TaskCreationOptions.None,
                TaskScheduler.Default).Unwrap();
        }

        public async Task RefreshAsync()
        {
            lock (gate)
            {
                if (isRefreshing)
                {
                    return;
                }
                isRefreshing = true;
            }
            NotifyChanged();

            CodexAuthContext context;
            try
            {
                context = client.LoadAuthContext();
            }
            catch (Exception ex)
            {
                ApplyMissingAuth(ex);
                FinishRefresh();
                return;
            }

            PrepareForActiveContext(context);

            Result<ResetCreditsResponse> creditsResult = await FetchResetCreditsResult(context);
            Result<CodexUsageResponse> usageResult = await FetchUsageResult(context);
            DateTimeOffset refreshedAt = DateTimeOffset.Now;

            CodexAuthContext latestContext = null;
            bool accountChanged = false;
            try
            {
                latestContext = client.LoadAuthContext();
                accountChanged = latestContext.AccessToken != context.AccessToken || latestContext.AccountId != context.AccountId;
            }
            catch
            {
                accountChanged = true;
            }

            if (accountChanged)
            {
                ClearActiveLiveData(latestContext ?? new CodexAuthContext { Identity = new CodexAccountIdentity() }, latestContext == null ? null : SnapshotIdForAccountId(latestContext.AccountId));
                UsageErrorMessage = "Codex account changed during refresh. Refresh again to load the active account cleanly.";
                CreditsErrorMessage = null;
                LastChecked = refreshedAt;
                FinishRefresh();
                return;
            }

            ApplyRefreshResults(context, creditsResult, usageResult, refreshedAt);
            FinishRefresh();
        }

        public string MenuBarTitle(MenuBarMetric metric)
        {
            UsageLimitDisplay window = UsageWindowFor(metric);
            if (window != null && window.RemainingPercent.HasValue)
            {
                return window.RemainingPercent.Value + "% | " + MenuBarResetCue(metric, window.Window);
            }
            return AvailableCount + " reset" + (AvailableCount == 1 ? "" : "s");
        }

        public UsageLimitDisplay UsageWindowFor(MenuBarMetric metric)
        {
            UsageWindowKind kind = metric == MenuBarMetric.Weekly ? UsageWindowKind.Weekly : UsageWindowKind.FiveHour;
            foreach (UsageLimitDisplay window in UsageWindows)
            {
                if (window.Kind == kind)
                {
                    return window;
                }
            }
            return null;
        }

        public AccountDetailState Detail()
        {
            if (!String.IsNullOrWhiteSpace(SelectedSnapshotId))
            {
                foreach (CodexAccountSnapshot snapshot in CachedSnapshots)
                {
                    if (String.Equals(snapshot.Id, SelectedSnapshotId, StringComparison.OrdinalIgnoreCase))
                    {
                        return CachedDetail(snapshot);
                    }
                }
                SelectedSnapshotId = null;
            }
            return ActiveDetail();
        }

        public void SelectActive()
        {
            SelectedSnapshotId = null;
            NotifyChanged();
        }

        public void SelectCachedAccount(string id)
        {
            foreach (CodexAccountSnapshot snapshot in CachedSnapshots)
            {
                if (String.Equals(snapshot.Id, id, StringComparison.OrdinalIgnoreCase))
                {
                    SelectedSnapshotId = id;
                    NotifyChanged();
                    return;
                }
            }
            SelectedSnapshotId = null;
            NotifyChanged();
        }

        public void ForgetSnapshot(string id)
        {
            List<CodexAccountSnapshot> next = new List<CodexAccountSnapshot>();
            foreach (CodexAccountSnapshot snapshot in Snapshots)
            {
                if (!String.Equals(snapshot.Id, id, StringComparison.OrdinalIgnoreCase))
                {
                    next.Add(snapshot);
                }
            }
            try
            {
                snapshotPersistence.Save(next);
                Snapshots = next;
            }
            catch
            {
                UsageErrorMessage = Append("Could not forget cached snapshot.", UsageErrorMessage);
            }
            if (String.Equals(SelectedSnapshotId, id, StringComparison.OrdinalIgnoreCase))
            {
                SelectedSnapshotId = null;
            }
            NotifyChanged();
        }

        public void ClearCachedSnapshots()
        {
            List<CodexAccountSnapshot> activeOnly = new List<CodexAccountSnapshot>();
            foreach (CodexAccountSnapshot snapshot in Snapshots)
            {
                if (String.Equals(snapshot.Id, ActiveSnapshotId, StringComparison.OrdinalIgnoreCase))
                {
                    activeOnly.Add(snapshot);
                }
            }
            try
            {
                snapshotPersistence.Save(activeOnly);
                Snapshots = activeOnly;
            }
            catch
            {
                UsageErrorMessage = Append("Could not clear cached snapshots.", UsageErrorMessage);
            }
            SelectedSnapshotId = null;
            NotifyChanged();
        }

        public void ClearStaleSnapshots()
        {
            DateTimeOffset now = DateTimeOffset.Now;
            List<string> staleIds = new List<string>();
            foreach (CodexAccountSnapshot snapshot in CachedSnapshots)
            {
                if (snapshot.IsStale(now))
                {
                    staleIds.Add(snapshot.Id);
                }
            }
            if (staleIds.Count == 0)
            {
                return;
            }

            List<CodexAccountSnapshot> next = new List<CodexAccountSnapshot>();
            foreach (CodexAccountSnapshot snapshot in Snapshots)
            {
                if (!ContainsId(staleIds, snapshot.Id))
                {
                    next.Add(snapshot);
                }
            }
            try
            {
                snapshotPersistence.Save(next);
                Snapshots = next;
            }
            catch
            {
                UsageErrorMessage = Append("Could not clear stale snapshots.", UsageErrorMessage);
            }
            if (ContainsId(staleIds, SelectedSnapshotId))
            {
                SelectedSnapshotId = null;
            }
            NotifyChanged();
        }

        public void Dispose()
        {
            timer.Stop();
            timer.Dispose();
        }

        private void ApplyMissingAuth(Exception error)
        {
            Usage = null;
            Credits = new List<ResetCredit>();
            AvailableCount = 0;
            ActiveSnapshotId = null;
            AccountIdentity = new CodexAccountIdentity();
            UsageErrorMessage = RefreshErrorMessage("active account", error, false);
            CreditsErrorMessage = null;
            LastChecked = DateTimeOffset.Now;
        }

        private void PrepareForActiveContext(CodexAuthContext context)
        {
            string contextSnapshotId = SnapshotIdForAccountId(context.AccountId);
            bool shouldClear = false;
            if (!String.Equals(ActiveSnapshotId, contextSnapshotId, StringComparison.OrdinalIgnoreCase))
            {
                shouldClear = true;
            }
            else if (contextSnapshotId == null && (Usage != null || Credits.Count > 0))
            {
                shouldClear = true;
            }

            if (shouldClear)
            {
                ClearActiveLiveData(context, contextSnapshotId);
                UsageErrorMessage = null;
                CreditsErrorMessage = null;
            }
        }

        private void ClearActiveLiveData(CodexAuthContext context, string snapshotId)
        {
            Usage = null;
            Credits = new List<ResetCredit>();
            AvailableCount = 0;
            ActiveSnapshotId = snapshotId;
            AccountIdentity = context.Identity ?? new CodexAccountIdentity();
        }

        private void ApplyRefreshResults(CodexAuthContext context, Result<ResetCreditsResponse> creditsResult, Result<CodexUsageResponse> usageResult, DateTimeOffset refreshedAt)
        {
            CodexUsageResponse usageResponse = usageResult.Success ? usageResult.Value : null;
            string snapshotId = SnapshotIdResolution(context, usageResponse);
            ActiveSnapshotId = snapshotId;

            if (creditsResult.Success)
            {
                Credits = creditsResult.Value.Credits;
                Credits.Sort(SortByExpiry);
                AvailableCount = creditsResult.Value.AvailableCount;
                CreditsErrorMessage = null;
            }
            else
            {
                CreditsErrorMessage = RefreshErrorMessage("reset stash", creditsResult.Error, Credits.Count > 0);
            }

            if (usageResult.Success)
            {
                Usage = usageResult.Value;
                AccountIdentity = IdentityFrom(usageResult.Value, context);
                if (CreditsErrorMessage != null && Credits.Count == 0 && Usage.ResetCreditFallbackCount.HasValue)
                {
                    AvailableCount = Usage.ResetCreditFallbackCount.Value;
                }
                UsageErrorMessage = null;
            }
            else
            {
                UsageErrorMessage = RefreshErrorMessage("usage meters", usageResult.Error, Usage != null);
                AccountIdentity = context.Identity ?? new CodexAccountIdentity();
            }

            LastChecked = refreshedAt;
            PersistSnapshotIfPossible(snapshotId, context, creditsResult, usageResult, refreshedAt);
        }

        private void PersistSnapshotIfPossible(string id, CodexAuthContext context, Result<ResetCreditsResponse> creditsResult, Result<CodexUsageResponse> usageResult, DateTimeOffset refreshedAt)
        {
            if (String.IsNullOrWhiteSpace(id))
            {
                return;
            }
            CodexAccountSnapshot existing = FindSnapshot(id);
            bool hasAnySuccess = creditsResult.Success || usageResult.Success;
            if (!hasAnySuccess && existing == null)
            {
                return;
            }

            List<string> errors = new List<string>();
            if (!creditsResult.Success)
            {
                errors.Add("resetCreditsFailed");
                errors.Add(SnapshotErrorCode(creditsResult.Error));
            }
            if (!usageResult.Success)
            {
                errors.Add("usageFailed");
                errors.Add(SnapshotErrorCode(usageResult.Error));
            }
            errors = Unique(errors);

            CodexAccountSnapshot snapshot = MakeSnapshot(id, context, usageResult.Success ? usageResult.Value : null, creditsResult.Success ? creditsResult.Value : null, existing, errors, refreshedAt, hasAnySuccess);
            try
            {
                Snapshots = snapshotPersistence.Upsert(snapshot, Snapshots);
            }
            catch
            {
                UsageErrorMessage = Append("Could not save account snapshot.", UsageErrorMessage);
            }
        }

        private CodexAccountSnapshot MakeSnapshot(string id, CodexAuthContext context, CodexUsageResponse usageResponse, ResetCreditsResponse creditsResponse, CodexAccountSnapshot existing, List<string> errors, DateTimeOffset refreshedAt, bool hasAnySuccess)
        {
            CodexAccountIdentity identity = usageResponse == null ? context.Identity : IdentityFrom(usageResponse, context);
            List<AccountUsageWindowSnapshot> windows = new List<AccountUsageWindowSnapshot>();
            if (usageResponse != null)
            {
                foreach (UsageLimitDisplay display in usageResponse.Windows)
                {
                    windows.Add(AccountUsageWindowSnapshot.FromDisplay(display, refreshedAt));
                }
            }
            else if (existing != null)
            {
                windows = existing.UsageWindows;
            }

            List<DateTimeOffset> expiries = new List<DateTimeOffset>();
            if (creditsResponse != null)
            {
                foreach (ResetCredit credit in creditsResponse.Credits)
                {
                    DateTimeOffset? expiry = DateFormatting.ParseIso(credit.ExpiresAt);
                    if (credit.IsAvailable && expiry.HasValue)
                    {
                        expiries.Add(expiry.Value);
                    }
                }
                expiries.Sort();
            }
            else if (existing != null)
            {
                expiries = existing.ResetExpiries;
            }

            return new CodexAccountSnapshot
            {
                Id = id,
                Nickname = existing == null ? null : existing.Nickname,
                DisplayLabel = identity == null ? "Codex account" : identity.DisplayLabel,
                PlanLabel = usageResponse == null ? (existing == null ? "Codex" : existing.PlanLabel) : PlanLabelFor(usageResponse),
                LastChecked = hasAnySuccess ? refreshedAt : (existing == null ? refreshedAt : existing.LastChecked),
                UsageWindows = windows,
                ResetCount = creditsResponse == null ? (existing == null ? 0 : existing.ResetCount) : creditsResponse.AvailableCount,
                ResetExpiries = expiries,
                Status = errors.Count == 0 ? "ok" : (hasAnySuccess ? "partial" : "error"),
                Errors = errors
            };
        }

        private AccountDetailState ActiveDetail()
        {
            return new AccountDetailState
            {
                SnapshotId = ActiveSnapshotId,
                AccountLabel = AccountDisplayLabel,
                PlanLabel = PlanLabel,
                StatusTitle = "Active account",
                StatusDetail = ActiveSidebarDetail(),
                LastChecked = LastChecked,
                AvailableCount = AvailableCount,
                StaleSnapshotCount = StaleCachedSnapshotCount,
                Credits = CreditDisplays,
                UsageWindows = UsageWindows,
                Nudge = Nudge,
                ErrorMessages = ErrorMessages,
                IsActive = true,
                IsCached = false,
                IsStale = false,
                IsRefreshing = IsRefreshing,
                CanRefresh = true,
                CanForget = false
            };
        }

        private AccountDetailState CachedDetail(CodexAccountSnapshot snapshot)
        {
            DateTimeOffset now = DateTimeOffset.Now;
            bool stale = snapshot.IsStale(now);
            List<UsageLimitDisplay> windows = snapshot.Displays(now);
            List<ResetCreditDisplay> credits = snapshot.CreditDisplays(now);
            UsageNudge nudge = stale
                ? new UsageNudge { Tier = "unavailable", Title = "Stale snapshot", Message = "These numbers are from the last time this account was active. Sign into this Codex account to refresh it.", Detail = "Cached" }
                : UsageNudge.Make(windows, snapshot.ResetCount, ResetUrgenciesFor(credits));

            return new AccountDetailState
            {
                SnapshotId = snapshot.Id,
                AccountLabel = snapshot.EffectiveLabel,
                PlanLabel = snapshot.PlanLabel,
                StatusTitle = stale ? "Stale snapshot" : "Cached snapshot",
                StatusDetail = "Last refreshed " + DateFormatting.WeekdayCompact(snapshot.LastChecked),
                LastChecked = snapshot.LastChecked,
                AvailableCount = snapshot.ResetCount,
                StaleSnapshotCount = StaleCachedSnapshotCount,
                Credits = credits,
                UsageWindows = windows,
                Nudge = nudge,
                ErrorMessages = SnapshotErrorMessages(snapshot.Errors),
                IsActive = false,
                IsCached = true,
                IsStale = stale,
                IsRefreshing = false,
                CanRefresh = false,
                CanForget = true
            };
        }

        private string ActiveSidebarDetail()
        {
            if (IsRefreshing)
            {
                return "Refreshing active account...";
            }
            if (Usage == null && Credits.Count == 0 && ErrorMessages.Count > 0)
            {
                return "No active Codex login";
            }
            return "Active now";
        }

        private async Task<Result<ResetCreditsResponse>> FetchResetCreditsResult(CodexAuthContext context)
        {
            try
            {
                return Result<ResetCreditsResponse>.Ok(await client.FetchResetCreditsAsync(context));
            }
            catch (Exception ex)
            {
                return Result<ResetCreditsResponse>.Fail(ex);
            }
        }

        private async Task<Result<CodexUsageResponse>> FetchUsageResult(CodexAuthContext context)
        {
            try
            {
                return Result<CodexUsageResponse>.Ok(await client.FetchUsageAsync(context));
            }
            catch (Exception ex)
            {
                return Result<CodexUsageResponse>.Fail(ex);
            }
        }

        private void FinishRefresh()
        {
            lock (gate)
            {
                isRefreshing = false;
            }
            NotifyChanged();
        }

        private void NotifyChanged()
        {
            EventHandler handler = Changed;
            if (handler != null)
            {
                handler(this, EventArgs.Empty);
            }
        }

        private string MenuBarResetCue(MenuBarMetric metric, UsageLimitWindow window)
        {
            DateTimeOffset? resetDate = ResetDateFor(window);
            if (!resetDate.HasValue)
            {
                return metric == MenuBarMetric.Weekly ? "week" : "5h";
            }
            return metric == MenuBarMetric.Weekly ? DateFormatting.WeekdayName(resetDate) : DateFormatting.TimeOnly(resetDate);
        }

        private DateTimeOffset? ResetDateFor(UsageLimitWindow window)
        {
            if (window == null)
            {
                return null;
            }
            if (window.ResetDate.HasValue)
            {
                return window.ResetDate;
            }
            if (window.ResetAfterSeconds.HasValue)
            {
                return DateTimeOffset.Now.AddSeconds(Math.Max(0, window.ResetAfterSeconds.Value));
            }
            return null;
        }

        private string SnapshotIdResolution(CodexAuthContext context, CodexUsageResponse usageResponse)
        {
            string contextAccountId = NormalizedAccountId(context == null ? null : context.AccountId);
            if (contextAccountId != null)
            {
                return SnapshotIdForAccountId(contextAccountId);
            }
            string usageAccountId = NormalizedAccountId(usageResponse == null ? null : usageResponse.AccountId);
            return SnapshotIdForAccountId(usageAccountId);
        }

        private string SnapshotIdForAccountId(string accountId)
        {
            string normalized = NormalizedAccountId(accountId);
            return normalized == null ? null : snapshotPersistence.SnapshotIdFor(normalized);
        }

        private static string NormalizedAccountId(string accountId)
        {
            if (String.IsNullOrWhiteSpace(accountId))
            {
                return null;
            }
            return accountId.Trim();
        }

        private CodexAccountSnapshot FindSnapshot(string id)
        {
            foreach (CodexAccountSnapshot snapshot in Snapshots)
            {
                if (String.Equals(snapshot.Id, id, StringComparison.OrdinalIgnoreCase))
                {
                    return snapshot;
                }
            }
            return null;
        }

        private static CodexAccountIdentity IdentityFrom(CodexUsageResponse response, CodexAuthContext context)
        {
            return new CodexAccountIdentity
            {
                AccountId = !String.IsNullOrWhiteSpace(context.AccountId) ? context.AccountId : response.AccountId,
                Email = !String.IsNullOrWhiteSpace(response.Email) ? response.Email : context.Identity.Email,
                Name = context.Identity.Name
            };
        }

        private static string PlanLabelFor(CodexUsageResponse usage)
        {
            if (usage == null || String.IsNullOrWhiteSpace(usage.PlanType))
            {
                return "Codex";
            }
            string[] parts = usage.PlanType.Split('_');
            for (int i = 0; i < parts.Length; i++)
            {
                if (parts[i].Length > 0)
                {
                    parts[i] = Char.ToUpperInvariant(parts[i][0]) + parts[i].Substring(1).ToLowerInvariant();
                }
            }
            return String.Join(" ", parts);
        }

        private static List<ResetExpiryUrgency> ResetUrgenciesFor(List<ResetCreditDisplay> credits)
        {
            List<ResetExpiryUrgency> urgencies = new List<ResetExpiryUrgency>();
            DateTimeOffset now = DateTimeOffset.Now;
            foreach (ResetCreditDisplay credit in credits)
            {
                urgencies.Add(ResetExpiryUrgency.Make(credit.ExpiresAt, now, credit.IsAvailable));
            }
            return urgencies;
        }

        private static int SortByExpiry(ResetCredit left, ResetCredit right)
        {
            DateTimeOffset? leftDate = DateFormatting.ParseIso(left.ExpiresAt);
            DateTimeOffset? rightDate = DateFormatting.ParseIso(right.ExpiresAt);
            if (leftDate.HasValue && rightDate.HasValue)
            {
                return leftDate.Value.CompareTo(rightDate.Value);
            }
            if (leftDate.HasValue)
            {
                return -1;
            }
            if (rightDate.HasValue)
            {
                return 1;
            }
            return String.Compare(left.Id, right.Id, StringComparison.OrdinalIgnoreCase);
        }

        private static string RefreshErrorMessage(string area, Exception error, bool hasPriorData)
        {
            string prefix = hasPriorData ? "Could not refresh " + area + "; showing the last known numbers." : "Could not load " + area + ".";
            return prefix + " " + error.Message;
        }

        private static string SnapshotErrorCode(Exception error)
        {
            CodexApiException apiError = error as CodexApiException;
            if (apiError != null)
            {
                return apiError.Code;
            }
            return "decoding";
        }

        private static List<string> SnapshotErrorMessages(List<string> codes)
        {
            List<string> messages = new List<string>();
            foreach (string code in codes)
            {
                messages.Add(ErrorMessageFor(code));
            }
            return messages;
        }

        private static string ErrorMessageFor(string code)
        {
            switch (code)
            {
                case "missingAuth":
                    return "Codex login was missing during the last refresh.";
                case "invalidAuth":
                    return "Codex login could not be read during the last refresh.";
                case "invalidResponse":
                    return "Codex returned an invalid response during the last refresh.";
                case "emptyResponse":
                    return "Codex returned an empty response during the last refresh.";
                case "unexpectedContentType":
                    return "Codex returned a non-JSON response during the last refresh.";
                case "rateLimited":
                    return "Codex rate-limited the last refresh.";
                case "unauthorized":
                case "forbidden":
                    return "Codex rejected the saved login during the last refresh.";
                case "httpStatus":
                    return "Codex returned an HTTP error during the last refresh.";
                case "usageFailed":
                    return "Usage meters did not refresh.";
                case "resetCreditsFailed":
                    return "Reset stash did not refresh.";
                case "persistenceFailed":
                    return "Account snapshot could not be saved.";
                default:
                    return "Codex data could not be decoded during the last refresh.";
            }
        }

        private static string Append(string message, string existing)
        {
            if (String.IsNullOrWhiteSpace(existing))
            {
                return message;
            }
            return existing + " " + message;
        }

        private static bool ContainsId(List<string> ids, string id)
        {
            if (String.IsNullOrWhiteSpace(id))
            {
                return false;
            }
            foreach (string item in ids)
            {
                if (String.Equals(item, id, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        private static List<string> Unique(List<string> values)
        {
            List<string> unique = new List<string>();
            foreach (string value in values)
            {
                if (!ContainsId(unique, value))
                {
                    unique.Add(value);
                }
            }
            unique.Sort(StringComparer.OrdinalIgnoreCase);
            return unique;
        }
    }

    internal sealed class AccountDetailState
    {
        public string SnapshotId;
        public string AccountLabel;
        public string PlanLabel;
        public string StatusTitle;
        public string StatusDetail;
        public DateTimeOffset? LastChecked;
        public int AvailableCount;
        public int StaleSnapshotCount;
        public List<ResetCreditDisplay> Credits = new List<ResetCreditDisplay>();
        public List<UsageLimitDisplay> UsageWindows = new List<UsageLimitDisplay>();
        public UsageNudge Nudge;
        public List<string> ErrorMessages = new List<string>();
        public bool IsActive;
        public bool IsCached;
        public bool IsStale;
        public bool IsRefreshing;
        public bool CanRefresh;
        public bool CanForget;
    }

    internal sealed class Result<T>
    {
        public bool Success;
        public T Value;
        public Exception Error;

        public static Result<T> Ok(T value)
        {
            return new Result<T> { Success = true, Value = value };
        }

        public static Result<T> Fail(Exception error)
        {
            return new Result<T> { Success = false, Error = error };
        }
    }
}
