using System;
using System.Collections;
using System.Collections.Generic;

namespace CodexResetWatcher.Windows
{
    internal sealed class AccountUsageWindowSnapshot
    {
        public string Id;
        public UsageWindowKind Kind;
        public string Title;
        public int? UsedPercent;
        public int? RemainingPercent;
        public int? LimitWindowSeconds;
        public int? ResetAfterSeconds;
        public DateTimeOffset? ResetDate;

        public static AccountUsageWindowSnapshot FromDisplay(UsageLimitDisplay display, DateTimeOffset capturedAt)
        {
            int? resetAfter = display.Window.ResetAfterSeconds;
            DateTimeOffset? resetDate = display.Window.ResetDate;
            if (resetDate.HasValue)
            {
                resetAfter = Math.Max(0, (int)(resetDate.Value - capturedAt).TotalSeconds);
            }

            return new AccountUsageWindowSnapshot
            {
                Id = display.Id,
                Kind = display.Kind,
                Title = display.Title,
                UsedPercent = display.UsedPercent,
                RemainingPercent = display.RemainingPercent,
                LimitWindowSeconds = display.Window.LimitWindowSeconds,
                ResetAfterSeconds = resetAfter,
                ResetDate = resetDate
            };
        }

        public UsageLimitDisplay ToDisplay(DateTimeOffset cachedAt, DateTimeOffset now)
        {
            int? dynamicResetAfter = null;
            if (ResetDate.HasValue)
            {
                dynamicResetAfter = Math.Max(0, (int)(ResetDate.Value - now).TotalSeconds);
            }
            else if (ResetAfterSeconds.HasValue)
            {
                int elapsed = Math.Max(0, (int)(now - cachedAt).TotalSeconds);
                dynamicResetAfter = Math.Max(0, ResetAfterSeconds.Value - elapsed);
            }

            int? used = UsedPercent;
            if (!used.HasValue && RemainingPercent.HasValue)
            {
                used = Math.Max(0, Math.Min(100, 100 - RemainingPercent.Value));
            }

            return new UsageLimitDisplay
            {
                Id = Id,
                Kind = Kind,
                Title = Title,
                Window = new UsageLimitWindow
                {
                    UsedPercent = used,
                    LimitWindowSeconds = LimitWindowSeconds,
                    ResetAfterSeconds = dynamicResetAfter,
                    ResetAt = ResetDate.HasValue ? (double?)ResetDate.Value.ToUnixTimeSecondsCompat() : null
                },
                LimitReached = RemainingPercent == 0
            };
        }

        public bool HasResetPassed(DateTimeOffset cachedAt, DateTimeOffset now)
        {
            if (ResetDate.HasValue)
            {
                return ResetDate.Value <= now;
            }
            if (!ResetAfterSeconds.HasValue)
            {
                return false;
            }
            return cachedAt.AddSeconds(ResetAfterSeconds.Value) <= now;
        }
    }

    internal sealed class CodexAccountSnapshot
    {
        public const int CurrentSchemaVersion = 1;

        public int SchemaVersion = CurrentSchemaVersion;
        public string Id;
        public string Nickname;
        public string DisplayLabel;
        public string PlanLabel;
        public DateTimeOffset LastChecked;
        public List<AccountUsageWindowSnapshot> UsageWindows = new List<AccountUsageWindowSnapshot>();
        public int ResetCount;
        public List<DateTimeOffset> ResetExpiries = new List<DateTimeOffset>();
        public string Status;
        public List<string> Errors = new List<string>();

        public string EffectiveLabel
        {
            get
            {
                if (!String.IsNullOrWhiteSpace(Nickname))
                {
                    return Nickname.Trim();
                }
                return DisplayLabel;
            }
        }

        public bool IsStale(DateTimeOffset now)
        {
            foreach (AccountUsageWindowSnapshot window in UsageWindows)
            {
                if (window.HasResetPassed(LastChecked, now))
                {
                    return true;
                }
            }
            return false;
        }

        public List<UsageLimitDisplay> Displays(DateTimeOffset now)
        {
            List<UsageLimitDisplay> displays = new List<UsageLimitDisplay>();
            foreach (AccountUsageWindowSnapshot window in UsageWindows)
            {
                displays.Add(window.ToDisplay(LastChecked, now));
            }
            return displays;
        }

        public List<ResetCreditDisplay> CreditDisplays(DateTimeOffset now)
        {
            List<ResetCreditDisplay> displays = new List<ResetCreditDisplay>();
            for (int i = 0; i < ResetExpiries.Count; i++)
            {
                displays.Add(new ResetCreditDisplay
                {
                    Id = Id + "-reset-" + i,
                    Title = "Cached reset credit",
                    ExpiresAt = ResetExpiries[i],
                    IsAvailable = ResetExpiries[i] > now
                });
            }
            return displays;
        }

        public Dictionary<string, object> ToJsonObject()
        {
            List<object> windows = new List<object>();
            foreach (AccountUsageWindowSnapshot window in UsageWindows)
            {
                windows.Add(new Dictionary<string, object>
                {
                    { "id", window.Id },
                    { "kind", KindToString(window.Kind) },
                    { "title", window.Title },
                    { "usedPercent", window.UsedPercent },
                    { "remainingPercent", window.RemainingPercent },
                    { "limitWindowSeconds", window.LimitWindowSeconds },
                    { "resetAfterSeconds", window.ResetAfterSeconds },
                    { "resetDate", window.ResetDate.HasValue ? DateFormatting.ToIso(window.ResetDate.Value) : null }
                });
            }

            List<object> expiries = new List<object>();
            foreach (DateTimeOffset expiry in ResetExpiries)
            {
                expiries.Add(DateFormatting.ToIso(expiry));
            }

            List<object> errors = new List<object>();
            foreach (string error in Errors)
            {
                errors.Add(error);
            }

            return new Dictionary<string, object>
            {
                { "schemaVersion", SchemaVersion },
                { "id", Id },
                { "nickname", Nickname },
                { "displayLabel", DisplayLabel },
                { "planLabel", PlanLabel },
                { "lastChecked", DateFormatting.ToIso(LastChecked) },
                { "usageWindows", windows },
                { "resetCount", ResetCount },
                { "resetExpiries", expiries },
                { "status", Status },
                { "errors", errors }
            };
        }

        public static CodexAccountSnapshot FromJsonObject(Dictionary<string, object> dict)
        {
            if (dict == null)
            {
                return null;
            }
            int schema = JsonUtil.GetInt(dict, "schemaVersion") ?? 0;
            if (schema != CurrentSchemaVersion)
            {
                return null;
            }

            DateTimeOffset? lastChecked = DateFormatting.ParseIso(JsonUtil.GetString(dict, "lastChecked"));
            string id = JsonUtil.GetString(dict, "id");
            if (String.IsNullOrWhiteSpace(id) || !lastChecked.HasValue)
            {
                return null;
            }

            CodexAccountSnapshot snapshot = new CodexAccountSnapshot
            {
                SchemaVersion = schema,
                Id = id,
                Nickname = JsonUtil.GetString(dict, "nickname"),
                DisplayLabel = JsonUtil.GetString(dict, "displayLabel") ?? "Codex account",
                PlanLabel = JsonUtil.GetString(dict, "planLabel") ?? "Codex",
                LastChecked = lastChecked.Value,
                ResetCount = JsonUtil.GetInt(dict, "resetCount") ?? 0,
                Status = JsonUtil.GetString(dict, "status") ?? "ok"
            };

            IList windows = JsonUtil.GetList(dict, "usageWindows");
            if (windows != null)
            {
                foreach (object item in windows)
                {
                    AccountUsageWindowSnapshot window = WindowFromJson(JsonUtil.AsDictionary(item));
                    if (window != null)
                    {
                        snapshot.UsageWindows.Add(window);
                    }
                }
            }

            IList expiries = JsonUtil.GetList(dict, "resetExpiries");
            if (expiries != null)
            {
                foreach (object item in expiries)
                {
                    DateTimeOffset? expiry = DateFormatting.ParseIso(item as string);
                    if (expiry.HasValue)
                    {
                        snapshot.ResetExpiries.Add(expiry.Value);
                    }
                }
            }

            IList errors = JsonUtil.GetList(dict, "errors");
            if (errors != null)
            {
                foreach (object item in errors)
                {
                    string error = item as string;
                    if (!String.IsNullOrWhiteSpace(error))
                    {
                        snapshot.Errors.Add(error);
                    }
                }
            }

            return snapshot;
        }

        private static AccountUsageWindowSnapshot WindowFromJson(Dictionary<string, object> dict)
        {
            if (dict == null)
            {
                return null;
            }
            string id = JsonUtil.GetString(dict, "id");
            string title = JsonUtil.GetString(dict, "title");
            if (String.IsNullOrWhiteSpace(id) || String.IsNullOrWhiteSpace(title))
            {
                return null;
            }
            return new AccountUsageWindowSnapshot
            {
                Id = id,
                Kind = KindFromString(JsonUtil.GetString(dict, "kind")),
                Title = title,
                UsedPercent = JsonUtil.GetInt(dict, "usedPercent"),
                RemainingPercent = JsonUtil.GetInt(dict, "remainingPercent"),
                LimitWindowSeconds = JsonUtil.GetInt(dict, "limitWindowSeconds"),
                ResetAfterSeconds = JsonUtil.GetInt(dict, "resetAfterSeconds"),
                ResetDate = DateFormatting.ParseIso(JsonUtil.GetString(dict, "resetDate"))
            };
        }

        public static string KindToString(UsageWindowKind kind)
        {
            switch (kind)
            {
                case UsageWindowKind.FiveHour:
                    return "fiveHour";
                case UsageWindowKind.Weekly:
                    return "weekly";
                default:
                    return "generic";
            }
        }

        public static UsageWindowKind KindFromString(string value)
        {
            if (String.Equals(value, "fiveHour", StringComparison.OrdinalIgnoreCase))
            {
                return UsageWindowKind.FiveHour;
            }
            if (String.Equals(value, "weekly", StringComparison.OrdinalIgnoreCase))
            {
                return UsageWindowKind.Weekly;
            }
            return UsageWindowKind.Generic;
        }
    }

    internal static class DateTimeOffsetCompat
    {
        public static long ToUnixTimeSecondsCompat(this DateTimeOffset value)
        {
            return (long)(value.ToUniversalTime() - DateFormatting.UnixEpoch).TotalSeconds;
        }
    }
}
