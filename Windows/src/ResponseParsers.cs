using System;
using System.Collections;
using System.Collections.Generic;

namespace CodexResetWatcher.Windows
{
    internal static class ResponseParsers
    {
        public static CodexUsageResponse ParseUsage(Dictionary<string, object> root)
        {
            if (root == null)
            {
                throw new CodexApiException("decoding", "Codex usage data could not be decoded.");
            }

            CodexUsageResponse response = new CodexUsageResponse();
            response.Email = JsonUtil.GetString(root, "email");
            response.AccountId = JsonUtil.GetString(root, "account_id");
            response.UserId = JsonUtil.GetString(root, "user_id");
            response.PlanType = JsonUtil.GetString(root, "plan_type");

            Dictionary<string, object> resetCount = JsonUtil.GetDictionary(root, "rate_limit_reset_credits");
            response.ResetCreditFallbackCount = JsonUtil.GetInt(resetCount, "available_count");

            Dictionary<string, object> rateLimit = JsonUtil.GetDictionary(root, "rate_limit");
            if (rateLimit == null)
            {
                return response;
            }

            bool limitReached = JsonUtil.GetBool(rateLimit, "limit_reached") == true;
            Dictionary<string, object> primary = JsonUtil.GetDictionary(rateLimit, "primary_window");
            Dictionary<string, object> secondary = JsonUtil.GetDictionary(rateLimit, "secondary_window");

            if (primary != null)
            {
                response.Windows.Add(DisplayFor(ParseWindow(primary), "primary", limitReached));
            }
            if (secondary != null)
            {
                response.Windows.Add(DisplayFor(ParseWindow(secondary), "secondary", limitReached));
            }
            return response;
        }

        public static ResetCreditsResponse ParseResetCredits(Dictionary<string, object> root)
        {
            if (root == null)
            {
                throw new CodexApiException("decoding", "Codex reset-credit data could not be decoded.");
            }

            ResetCreditsResponse response = new ResetCreditsResponse();
            IList list = JsonUtil.GetList(root, "credits");
            if (list != null)
            {
                foreach (object item in list)
                {
                    Dictionary<string, object> dict = JsonUtil.AsDictionary(item);
                    ResetCredit credit = ParseCredit(dict);
                    if (credit != null)
                    {
                        response.Credits.Add(credit);
                    }
                }
            }

            int? serverCount = JsonUtil.GetInt(root, "available_count");
            if (serverCount.HasValue)
            {
                response.AvailableCount = serverCount.Value;
            }
            else
            {
                int count = 0;
                foreach (ResetCredit credit in response.Credits)
                {
                    if (credit.IsAvailable)
                    {
                        count++;
                    }
                }
                response.AvailableCount = count;
            }
            return response;
        }

        private static UsageLimitWindow ParseWindow(Dictionary<string, object> dict)
        {
            return new UsageLimitWindow
            {
                UsedPercent = JsonUtil.GetInt(dict, "used_percent"),
                LimitWindowSeconds = JsonUtil.GetInt(dict, "limit_window_seconds"),
                ResetAfterSeconds = JsonUtil.GetInt(dict, "reset_after_seconds"),
                ResetAt = JsonUtil.GetDouble(dict, "reset_at")
            };
        }

        private static UsageLimitDisplay DisplayFor(UsageLimitWindow window, string fallbackId, bool limitReached)
        {
            int seconds = window.LimitWindowSeconds.HasValue ? window.LimitWindowSeconds.Value : 0;
            if (fallbackId == "primary" || (seconds >= 14400 && seconds <= 21600))
            {
                return new UsageLimitDisplay { Id = "five-hour", Kind = UsageWindowKind.FiveHour, Title = "5h limit", Window = window, LimitReached = limitReached };
            }
            if (fallbackId == "secondary" || (seconds >= 518400 && seconds <= 864000))
            {
                return new UsageLimitDisplay { Id = "weekly", Kind = UsageWindowKind.Weekly, Title = "Weekly limit", Window = window, LimitReached = limitReached };
            }
            return new UsageLimitDisplay { Id = fallbackId, Kind = UsageWindowKind.Generic, Title = DateFormatting.WindowTitle(seconds), Window = window, LimitReached = limitReached };
        }

        private static ResetCredit ParseCredit(Dictionary<string, object> dict)
        {
            if (dict == null)
            {
                return null;
            }
            string id = JsonUtil.GetString(dict, "id");
            if (String.IsNullOrEmpty(id))
            {
                return null;
            }
            return new ResetCredit
            {
                Id = id,
                ResetType = JsonUtil.GetString(dict, "reset_type") ?? "unknown",
                Status = JsonUtil.GetString(dict, "status") ?? "unknown",
                GrantedAt = JsonUtil.GetString(dict, "granted_at"),
                ExpiresAt = JsonUtil.GetString(dict, "expires_at"),
                RedeemStartedAt = JsonUtil.GetString(dict, "redeem_started_at"),
                RedeemedAt = JsonUtil.GetString(dict, "redeemed_at"),
                Title = JsonUtil.GetString(dict, "title"),
                Description = JsonUtil.GetString(dict, "description")
            };
        }
    }
}
