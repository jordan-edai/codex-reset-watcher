using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace CodexResetWatcher.Windows
{
    internal static class Diagnostics
    {
        public static int RunSelfTest(string outputPath)
        {
            List<string> tests = new List<string>();
            try
            {
                TestResetCreditDecoding();
                tests.Add("reset-credit tolerant decoding");
                TestUsageWindowParsing();
                tests.Add("usage window parsing");
                TestNudgeRules();
                tests.Add("usage nudge rules");
                TestSnapshotPersistence();
                tests.Add("snapshot persistence redaction");

                WriteJson(outputPath, new Dictionary<string, object>
                {
                    { "ok", true },
                    { "tests", tests.ToArray() },
                    { "checkedAt", DateFormatting.ToIso(DateTimeOffset.Now) }
                });
                return 0;
            }
            catch (Exception ex)
            {
                WriteFailure(outputPath, ex.Message);
                return 1;
            }
        }

        public static async Task<int> RunLiveCheckAsync(string outputPath)
        {
            CodexClient client = new CodexClient();
            CodexAuthContext context = client.LoadAuthContext();
            ResetCreditsResponse credits = await client.FetchResetCreditsAsync(context);
            CodexUsageResponse usage = await client.FetchUsageAsync(context);

            List<object> windows = new List<object>();
            foreach (UsageLimitDisplay window in usage.Windows)
            {
                windows.Add(new Dictionary<string, object>
                {
                    { "id", window.Id },
                    { "title", window.Title },
                    { "kind", CodexAccountSnapshot.KindToString(window.Kind) },
                    { "remainingPercent", window.RemainingPercent },
                    { "reset", UiUtil.ResetText(window) }
                });
            }

            WriteJson(outputPath, new Dictionary<string, object>
            {
                { "ok", true },
                { "checkedAt", DateFormatting.ToIso(DateTimeOffset.Now) },
                { "accountLabel", new CodexAccountIdentity { AccountId = context.AccountId, Email = usage.Email ?? context.Identity.Email, Name = context.Identity.Name }.DisplayLabel },
                { "planLabel", PlanLabel(usage.PlanType) },
                { "availableResetCount", credits.AvailableCount },
                { "availableCreditRowsDecoded", AvailableRows(credits) },
                { "usageWindows", windows }
            });
            return 0;
        }

        public static void WriteFailure(string outputPath, string message)
        {
            WriteJson(outputPath, new Dictionary<string, object>
            {
                { "ok", false },
                { "checkedAt", DateFormatting.ToIso(DateTimeOffset.Now) },
                { "error", message }
            });
        }

        private static void TestResetCreditDecoding()
        {
            Dictionary<string, object> root = JsonUtil.ParseObject(
                "{\"credits\":[{\"id\":123,\"status\":\"AVAILABLE\",\"expires_at\":\"2026-07-11T21:13:00Z\",\"title\":\"One free rate limit reset\"},{\"status\":\"available\",\"expires_at\":\"2026-07-12T21:13:00Z\"},{\"id\":\"credit-2\",\"reset_type\":\"rate_limit\",\"status\":\"redeemed\"}]}");
            ResetCreditsResponse response = ResponseParsers.ParseResetCredits(root);
            Assert(response.Credits.Count == 2, "Malformed reset-credit rows should be dropped individually.");
            Assert(response.Credits[0].Id == "123", "Numeric reset-credit IDs should decode as strings.");
            Assert(response.Credits[0].ResetType == "unknown", "Missing reset_type should become unknown.");
            Assert(response.AvailableCount == 1, "Available count should derive from valid available rows.");
        }

        private static void TestUsageWindowParsing()
        {
            Dictionary<string, object> root = JsonUtil.ParseObject(
                "{\"plan_type\":\"pro\",\"rate_limit\":{\"primary_window\":{\"used_percent\":71,\"limit_window_seconds\":18000,\"reset_after_seconds\":3600,\"reset_at\":1800000000000},\"secondary_window\":{\"used_percent\":37,\"limit_window_seconds\":604800,\"reset_after_seconds\":259200,\"reset_at\":1800259200}}}");
            CodexUsageResponse response = ResponseParsers.ParseUsage(root);
            Assert(response.Windows.Count == 2, "Usage should decode two windows.");
            Assert(response.Windows[0].Kind == UsageWindowKind.FiveHour, "Primary 18,000s window should be 5h.");
            Assert(response.Windows[0].RemainingPercent == 29, "Remaining percent should be 100 - used.");
            Assert(response.Windows[1].Kind == UsageWindowKind.Weekly, "Secondary 604,800s window should be weekly.");
            Assert(response.Windows[0].Window.ResetDate.Value.ToUnixTimeSecondsCompat() == 1800000000, "reset_at milliseconds should normalize to seconds.");
        }

        private static void TestNudgeRules()
        {
            List<UsageLimitDisplay> windows = new List<UsageLimitDisplay>();
            windows.Add(TestWindow(UsageWindowKind.FiveHour, 8, 45 * 60));
            windows.Add(TestWindow(UsageWindowKind.Weekly, 45, 3 * 86400));
            UsageNudge wait = UsageNudge.Make(windows, 1, new List<ResetExpiryUrgency>());
            Assert(wait.Tier == "waitFiveHour", "Low 5h and healthy weekly room should wait for short refill.");

            List<ResetExpiryUrgency> urgent = new List<ResetExpiryUrgency>();
            urgent.Add(new ResetExpiryUrgency { Level = "urgent", Badge = "Ends today" });
            UsageNudge expiring = UsageNudge.Make(windows, 1, urgent);
            Assert(expiring.Tier == "expiringReset", "Expiring reset should override hold advice.");
        }

        private static void TestSnapshotPersistence()
        {
            string directory = Path.Combine(Path.GetTempPath(), "codex-reset-watcher-test-" + Guid.NewGuid().ToString("N"));
            AccountSnapshotPersistence persistence = new AccountSnapshotPersistence(directory);
            string snapshotId = persistence.SnapshotIdFor("acct_full_sensitive_123456");
            CodexAccountSnapshot snapshot = new CodexAccountSnapshot
            {
                Id = snapshotId,
                DisplayLabel = "builder@example.com",
                PlanLabel = "Pro",
                LastChecked = new DateTimeOffset(2027, 1, 15, 12, 0, 0, TimeSpan.Zero),
                ResetCount = 1,
                Status = "ok"
            };
            snapshot.UsageWindows.Add(AccountUsageWindowSnapshot.FromDisplay(TestWindow(UsageWindowKind.Weekly, 58, 86400), snapshot.LastChecked));
            snapshot.ResetExpiries.Add(new DateTimeOffset(2027, 1, 17, 19, 38, 0, TimeSpan.Zero));
            persistence.Save(new List<CodexAccountSnapshot> { snapshot });

            string json = File.ReadAllText(persistence.FilePath, Encoding.UTF8);
            Assert(!json.Contains("acct_full_sensitive_123456"), "Snapshot file must not store full account IDs.");
            Assert(!json.Contains("access_token"), "Snapshot file must not store token field names.");
            Assert(!json.Contains("auth.json"), "Snapshot file must not store auth source paths.");
            Assert(json.Contains("builder@example.com"), "Snapshot file should keep display labels.");
            Directory.Delete(directory, true);
        }

        private static UsageLimitDisplay TestWindow(UsageWindowKind kind, int remaining, int? resetAfterSeconds)
        {
            int seconds = kind == UsageWindowKind.Weekly ? 604800 : 18000;
            return new UsageLimitDisplay
            {
                Id = kind == UsageWindowKind.Weekly ? "weekly" : "five-hour",
                Kind = kind,
                Title = kind == UsageWindowKind.Weekly ? "Weekly limit" : "5h limit",
                Window = new UsageLimitWindow
                {
                    UsedPercent = 100 - remaining,
                    LimitWindowSeconds = seconds,
                    ResetAfterSeconds = resetAfterSeconds
                }
            };
        }

        private static int AvailableRows(ResetCreditsResponse credits)
        {
            int count = 0;
            foreach (ResetCredit credit in credits.Credits)
            {
                if (credit.IsAvailable)
                {
                    count++;
                }
            }
            return count;
        }

        private static string PlanLabel(string planType)
        {
            if (String.IsNullOrWhiteSpace(planType))
            {
                return "Codex";
            }
            string[] parts = planType.Split('_');
            for (int i = 0; i < parts.Length; i++)
            {
                if (parts[i].Length > 0)
                {
                    parts[i] = Char.ToUpperInvariant(parts[i][0]) + parts[i].Substring(1).ToLowerInvariant();
                }
            }
            return String.Join(" ", parts);
        }

        private static void Assert(bool condition, string message)
        {
            if (!condition)
            {
                throw new InvalidOperationException(message);
            }
        }

        private static void WriteJson(string outputPath, Dictionary<string, object> payload)
        {
            string directory = Path.GetDirectoryName(outputPath);
            if (!String.IsNullOrWhiteSpace(directory))
            {
                Directory.CreateDirectory(directory);
            }
            File.WriteAllText(outputPath, JsonUtil.Serialize(payload), Encoding.UTF8);
        }
    }
}
