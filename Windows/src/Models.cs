using System;
using System.Collections.Generic;
using System.Globalization;

namespace CodexResetWatcher.Windows
{
    internal enum UsageWindowKind
    {
        FiveHour,
        Weekly,
        Generic
    }

    internal enum MenuBarMetric
    {
        Weekly,
        FiveHour
    }

    internal sealed class CodexAuthContext
    {
        public string AccessToken;
        public string AccountId;
        public CodexAccountIdentity Identity;
    }

    internal sealed class CodexAccountIdentity
    {
        public string AccountId;
        public string Email;
        public string Name;

        public string DisplayLabel
        {
            get
            {
                if (!String.IsNullOrWhiteSpace(Email))
                {
                    return Email.Trim();
                }
                if (!String.IsNullOrWhiteSpace(Name))
                {
                    return Name.Trim();
                }
                if (!String.IsNullOrWhiteSpace(AccountId))
                {
                    string clean = AccountId.Trim();
                    string suffix = clean.Length > 6 ? clean.Substring(clean.Length - 6) : clean;
                    return "Codex account " + suffix;
                }
                return "Codex account";
            }
        }
    }

    internal sealed class CodexUsageResponse
    {
        public string Email;
        public string AccountId;
        public string UserId;
        public string PlanType;
        public int? ResetCreditFallbackCount;
        public List<UsageLimitDisplay> Windows = new List<UsageLimitDisplay>();
    }

    internal sealed class UsageLimitWindow
    {
        public int? UsedPercent;
        public int? LimitWindowSeconds;
        public int? ResetAfterSeconds;
        public double? ResetAt;

        public int? RemainingPercent
        {
            get
            {
                if (!UsedPercent.HasValue)
                {
                    return null;
                }
                return Clamp(100 - UsedPercent.Value, 0, 100);
            }
        }

        public DateTimeOffset? ResetDate
        {
            get
            {
                if (!ResetAt.HasValue)
                {
                    return null;
                }
                double seconds = ResetAt.Value > 10000000000d ? ResetAt.Value / 1000d : ResetAt.Value;
                return DateFormatting.UnixEpoch.AddSeconds(seconds);
            }
        }

        private static int Clamp(int value, int min, int max)
        {
            return Math.Max(min, Math.Min(max, value));
        }
    }

    internal sealed class UsageLimitDisplay
    {
        public string Id;
        public UsageWindowKind Kind;
        public string Title;
        public UsageLimitWindow Window;
        public bool LimitReached;

        public int? UsedPercent
        {
            get
            {
                if (Window == null || !Window.UsedPercent.HasValue)
                {
                    return null;
                }
                return Math.Max(0, Math.Min(100, Window.UsedPercent.Value));
            }
        }

        public int? RemainingPercent
        {
            get { return Window == null ? null : Window.RemainingPercent; }
        }
    }

    internal sealed class ResetCreditsResponse
    {
        public List<ResetCredit> Credits = new List<ResetCredit>();
        public int AvailableCount;
    }

    internal sealed class ResetCredit
    {
        public string Id;
        public string ResetType;
        public string Status;
        public string GrantedAt;
        public string ExpiresAt;
        public string RedeemStartedAt;
        public string RedeemedAt;
        public string Title;
        public string Description;

        public bool IsAvailable
        {
            get { return String.Equals(Status, "available", StringComparison.OrdinalIgnoreCase); }
        }

        public ResetCreditDisplay ToDisplay(string fallbackId)
        {
            return new ResetCreditDisplay
            {
                Id = String.IsNullOrEmpty(Id) ? fallbackId : Id,
                Title = Title,
                ExpiresAt = DateFormatting.ParseIso(ExpiresAt),
                IsAvailable = IsAvailable
            };
        }
    }

    internal sealed class ResetCreditDisplay
    {
        public string Id;
        public string Title;
        public DateTimeOffset? ExpiresAt;
        public bool IsAvailable;
    }

    internal sealed class ResetExpiryUrgency
    {
        public string Level;
        public string Badge;
        public string Hint;

        public static ResetExpiryUrgency Make(DateTimeOffset? expiresAt, DateTimeOffset now, bool isAvailable)
        {
            if (!isAvailable)
            {
                return new ResetExpiryUrgency { Level = "inactive", Badge = "Used" };
            }
            if (!expiresAt.HasValue)
            {
                return new ResetExpiryUrgency { Level = "unknown", Badge = "Available", Hint = "Expiry unknown" };
            }

            double seconds = (expiresAt.Value - now).TotalSeconds;
            if (seconds <= 0)
            {
                return new ResetExpiryUrgency { Level = "expired", Badge = "Expired", Hint = "This reset is past its expiry time" };
            }
            if (seconds <= 86400)
            {
                return new ResetExpiryUrgency { Level = "urgent", Badge = "Ends today", Hint = "Use it soon or let it go" };
            }
            if (seconds <= 3 * 86400)
            {
                return new ResetExpiryUrgency { Level = "soon", Badge = "Expires soon", Hint = "Worth keeping top of mind" };
            }
            if (seconds <= 7 * 86400)
            {
                return new ResetExpiryUrgency { Level = "approaching", Badge = "This week", Hint = "Expiry is getting closer" };
            }
            return new ResetExpiryUrgency { Level = "normal", Badge = "Available" };
        }
    }

    internal sealed class UsageNudge
    {
        public string Tier;
        public string Title;
        public string Message;
        public string Detail;

        public static UsageNudge Make(List<UsageLimitDisplay> windows, int resetCount, List<ResetExpiryUrgency> resetUrgencies)
        {
            if (resetCount > 0 && ContainsUrgent(resetUrgencies))
            {
                return new UsageNudge
                {
                    Tier = "expiringReset",
                    Title = "Use it or lose it",
                    Message = "A banked reset expires today. If there is useful work queued, spend that reset before it disappears.",
                    Detail = "Reset ends today"
                };
            }

            UsageLimitDisplay weekly = FindWindow(windows, UsageWindowKind.Weekly);
            int? weeklyRemaining = weekly == null ? null : weekly.RemainingPercent;
            if (!weeklyRemaining.HasValue)
            {
                return new UsageNudge
                {
                    Tier = "unavailable",
                    Title = "Waiting on the meters",
                    Message = "Reset stash loaded. Codex usage windows are still warming up.",
                    Detail = "Try again soon"
                };
            }

            UsageLimitDisplay fiveHour = FindWindow(windows, UsageWindowKind.FiveHour);
            int? fiveHourRemaining = fiveHour == null ? null : fiveHour.RemainingPercent;
            int? fiveHourReset = fiveHour == null || fiveHour.Window == null ? null : fiveHour.Window.ResetAfterSeconds;
            int? weeklyResetSeconds = weekly.Window == null ? null : weekly.Window.ResetAfterSeconds;

            if (resetCount == 0)
            {
                return new UsageNudge
                {
                    Tier = "noResets",
                    Title = "No reset parachute",
                    Message = "Watch the meters. There is no banked reset for a big sprint.",
                    Detail = weeklyRemaining.Value + "% weekly left"
                };
            }

            if (fiveHourRemaining.HasValue && fiveHourReset.HasValue &&
                fiveHourRemaining.Value <= 12 && weeklyRemaining.Value >= 25 && fiveHourReset.Value <= 90 * 60)
            {
                return new UsageNudge
                {
                    Tier = "waitFiveHour",
                    Title = "Let the 5h tank refill",
                    Message = "Weekly room is still decent. Let the short window catch up before spending a reset.",
                    Detail = "5h resets in " + DateFormatting.Duration(fiveHourReset)
                };
            }

            if (fiveHourRemaining.HasValue && fiveHourReset.HasValue &&
                fiveHourRemaining.Value <= 12 && weeklyRemaining.Value >= 50 &&
                fiveHourReset.Value > 90 * 60 && fiveHourReset.Value <= 3 * 3600)
            {
                return new UsageNudge
                {
                    Tier = "deadline",
                    Title = "Deadline call",
                    Message = "Weekly runway looks great. If this is deadline work, spend a reset. Otherwise let the 5h clock do its thing.",
                    Detail = "5h resets in " + DateFormatting.Duration(fiveHourReset)
                };
            }

            if (fiveHourRemaining.HasValue && fiveHourReset.HasValue &&
                fiveHourRemaining.Value <= 12 && weeklyRemaining.Value >= 50 && fiveHourReset.Value > 3 * 3600)
            {
                return new UsageNudge
                {
                    Tier = "deadline",
                    Title = "Deadline override",
                    Message = "The short window is hours away. Big deadline? Use a reset. Otherwise coast until the 5h refill.",
                    Detail = "5h resets in " + DateFormatting.Duration(fiveHourReset)
                };
            }

            if (!weeklyResetSeconds.HasValue)
            {
                return new UsageNudge
                {
                    Tier = "steady",
                    Title = "Reset timing unclear",
                    Message = "Usage meters loaded, but Codex did not return a weekly reset timer. Spend a reset only if work is blocked.",
                    Detail = weeklyRemaining.Value + "% weekly left"
                };
            }

            double weeklyDays = weeklyResetSeconds.Value / 86400d;
            if (resetCount >= 2 && weeklyRemaining.Value <= 15 && weeklyDays >= 4)
            {
                return new UsageNudge
                {
                    Tier = "spend",
                    Title = "Go burn some tokens",
                    Message = "You have " + resetCount + " resets banked, weekly room is thin, and refresh is days away. Push the run, then spend a reset if Codex blocks real work.",
                    Detail = weeklyRemaining.Value + "% weekly left"
                };
            }

            if (resetCount >= 1 && weeklyRemaining.Value <= 20 && weeklyDays >= 2)
            {
                return new UsageNudge
                {
                    Tier = "useIfBlocked",
                    Title = "Green light, with brakes",
                    Message = "If real work hits the wall, spending a reset makes sense. Do not use it just to tidy up the meter.",
                    Detail = DateFormatting.Duration(weeklyResetSeconds) + " to weekly reset"
                };
            }

            if (weeklyRemaining.Value >= 35 && weeklyDays <= 3)
            {
                return new UsageNudge
                {
                    Tier = "hold",
                    Title = "Hold that reset",
                    Message = "Plenty of weekly runway and the next refresh is close. Let the reset stay banked.",
                    Detail = weeklyRemaining.Value + "% weekly left"
                };
            }

            if (weeklyRemaining.Value >= 25 && weeklyDays <= 2)
            {
                return new UsageNudge
                {
                    Tier = "hold",
                    Title = "Pocket the reset",
                    Message = "Capacity is not tight enough this close to weekly refresh. Keep the reset in your back pocket.",
                    Detail = DateFormatting.Duration(weeklyResetSeconds) + " away"
                };
            }

            return new UsageNudge
            {
                Tier = "steady",
                Title = "Cruise mode",
                Message = "Keep working. Re-check before a big run.",
                Detail = weeklyRemaining.Value + "% weekly left"
            };
        }

        private static bool ContainsUrgent(List<ResetExpiryUrgency> resetUrgencies)
        {
            if (resetUrgencies == null)
            {
                return false;
            }
            foreach (ResetExpiryUrgency urgency in resetUrgencies)
            {
                if (urgency != null && urgency.Level == "urgent")
                {
                    return true;
                }
            }
            return false;
        }

        private static UsageLimitDisplay FindWindow(List<UsageLimitDisplay> windows, UsageWindowKind kind)
        {
            if (windows == null)
            {
                return null;
            }
            foreach (UsageLimitDisplay window in windows)
            {
                if (window.Kind == kind)
                {
                    return window;
                }
            }
            return null;
        }
    }

    internal static class DateFormatting
    {
        public static readonly DateTimeOffset UnixEpoch = new DateTimeOffset(1970, 1, 1, 0, 0, 0, TimeSpan.Zero);

        public static DateTimeOffset? ParseIso(string value)
        {
            if (String.IsNullOrWhiteSpace(value))
            {
                return null;
            }
            DateTimeOffset parsed;
            if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out parsed))
            {
                return parsed;
            }
            return null;
        }

        public static string ToIso(DateTimeOffset value)
        {
            return value.UtcDateTime.ToString("o", CultureInfo.InvariantCulture);
        }

        public static string Checked(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "Not checked yet";
            }
            return "Last checked " + value.Value.ToLocalTime().ToString("h:mm tt", CultureInfo.InvariantCulture);
        }

        public static string WeekdayName(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "-";
            }
            return value.Value.ToLocalTime().ToString("dddd", CultureInfo.InvariantCulture);
        }

        public static string WeekdayCompact(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "-";
            }
            return value.Value.ToLocalTime().ToString("ddd, MMM d 'at' h:mm tt", CultureInfo.InvariantCulture);
        }

        public static string WeekdayDate(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "-";
            }
            return value.Value.ToLocalTime().ToString("ddd, MMM d", CultureInfo.InvariantCulture);
        }

        public static string TimeOnly(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "-";
            }
            return value.Value.ToLocalTime().ToString("h:mm tt", CultureInfo.InvariantCulture);
        }

        public static string ResetTime(DateTimeOffset? value)
        {
            if (!value.HasValue)
            {
                return "-";
            }
            return value.Value.ToLocalTime().ToString("MMM d, yyyy h:mm tt", CultureInfo.InvariantCulture);
        }

        public static string Duration(int? seconds)
        {
            if (!seconds.HasValue)
            {
                return "-";
            }
            int clamped = Math.Max(0, seconds.Value);
            int days = clamped / 86400;
            int hours = (clamped % 86400) / 3600;
            int minutes = (clamped % 3600) / 60;

            if (days > 0)
            {
                return hours > 0 ? days + "d " + hours + "h" : days + "d";
            }
            if (hours > 0)
            {
                return minutes > 0 ? hours + "h " + minutes + "m" : hours + "h";
            }
            return Math.Max(1, minutes) + "m";
        }

        public static string WindowTitle(int seconds)
        {
            if (seconds >= 86400)
            {
                return Math.Max(1, seconds / 86400) + "d limit";
            }
            return Math.Max(1, seconds / 3600) + "h limit";
        }
    }
}
