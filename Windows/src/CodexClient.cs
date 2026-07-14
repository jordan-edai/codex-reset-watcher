using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace CodexResetWatcher.Windows
{
    internal sealed class CodexApiException : Exception
    {
        public string Code;
        public int? StatusCode;

        public CodexApiException(string code, string message) : base(message)
        {
            Code = code;
        }

        public CodexApiException(string code, string message, int statusCode) : base(message)
        {
            Code = code;
            StatusCode = statusCode;
        }
    }

    internal sealed class CodexClient
    {
        private const string UsageEndpoint = "https://chatgpt.com/backend-api/wham/usage";
        private const string ResetCreditsEndpoint = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits";

        private readonly string codexHome;

        public CodexClient() : this(null)
        {
        }

        public CodexClient(string codexHome)
        {
            this.codexHome = codexHome;
        }

        public CodexAuthContext LoadAuthContext()
        {
            string authPath = Path.Combine(ResolvedCodexHome(), "auth.json");
            if (!File.Exists(authPath))
            {
                throw new CodexApiException("missingAuth", "Could not find Codex login at " + authPath + ". Open Codex Desktop and sign in first.");
            }

            Dictionary<string, object> root;
            try
            {
                root = JsonUtil.ParseObject(File.ReadAllText(authPath, Encoding.UTF8));
            }
            catch
            {
                throw new CodexApiException("invalidAuth", "Could not read Codex login at " + authPath + ". Open Codex Desktop and sign in again.");
            }

            Dictionary<string, object> tokens = JsonUtil.GetDictionary(root, "tokens");
            string accessToken = JsonUtil.GetString(tokens, "access_token");
            if (String.IsNullOrWhiteSpace(accessToken))
            {
                throw new CodexApiException("invalidAuth", "Could not read Codex login at " + authPath + ". Open Codex Desktop and sign in again.");
            }

            string idToken = JsonUtil.GetString(tokens, "id_token");
            string fallbackAccountId = JsonUtil.GetString(tokens, "account_id");
            Dictionary<string, object> idPayload = JwtPayload(idToken);
            Dictionary<string, object> idAuth = JsonUtil.GetDictionary(idPayload, "https://api.openai.com/auth");
            string idTokenAccountId = JsonUtil.GetString(idAuth, "chatgpt_account_id");
            string accessTokenAccountId = AccountIdFromToken(accessToken, fallbackAccountId);
            string resolvedAccountId = !String.IsNullOrWhiteSpace(idTokenAccountId) ? idTokenAccountId : accessTokenAccountId;

            return new CodexAuthContext
            {
                AccessToken = accessToken,
                AccountId = resolvedAccountId,
                Identity = new CodexAccountIdentity
                {
                    AccountId = resolvedAccountId,
                    Email = JsonUtil.GetString(idPayload, "email"),
                    Name = JsonUtil.GetString(idPayload, "name")
                }
            };
        }

        public async Task<CodexUsageResponse> FetchUsageAsync(CodexAuthContext context)
        {
            return ResponseParsers.ParseUsage(await FetchJsonAsync(UsageEndpoint, context));
        }

        public async Task<ResetCreditsResponse> FetchResetCreditsAsync(CodexAuthContext context)
        {
            return ResponseParsers.ParseResetCredits(await FetchJsonAsync(ResetCreditsEndpoint, context));
        }

        private async Task<Dictionary<string, object>> FetchJsonAsync(string endpoint, CodexAuthContext context)
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(endpoint);
            request.Method = "GET";
            request.Accept = "application/json";
            request.Timeout = 20000;
            request.ReadWriteTimeout = 20000;
            request.Headers[HttpRequestHeader.Authorization] = "Bearer " + context.AccessToken;
            request.Headers["originator"] = "Codex Desktop";
            request.Headers["OAI-Product-Sku"] = "CODEX";
            if (!String.IsNullOrWhiteSpace(context.AccountId))
            {
                request.Headers["ChatGPT-Account-Id"] = context.AccountId;
            }

            HttpWebResponse response = null;
            try
            {
                WebResponse webResponse = await Task.Factory.FromAsync<WebResponse>(request.BeginGetResponse, request.EndGetResponse, null);
                response = (HttpWebResponse)webResponse;
                string body = ReadBody(response);
                if (String.IsNullOrWhiteSpace(body))
                {
                    throw new CodexApiException("emptyResponse", "The Codex endpoint returned an empty response.");
                }
                string contentType = response.ContentType ?? "";
                if (contentType.Length > 0 && contentType.IndexOf("json", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    throw new CodexApiException("unexpectedContentType", "The Codex endpoint returned " + contentType + " instead of JSON. Open Codex Desktop and sign in again.");
                }
                return JsonUtil.ParseObject(body);
            }
            catch (WebException ex)
            {
                HttpWebResponse errorResponse = ex.Response as HttpWebResponse;
                if (errorResponse != null)
                {
                    int status = (int)errorResponse.StatusCode;
                    if (status == 429)
                    {
                        string retryAfter = errorResponse.Headers["Retry-After"];
                        string suffix = String.IsNullOrWhiteSpace(retryAfter) ? "Try again later." : "Try again after " + retryAfter + " seconds.";
                        throw new CodexApiException("rateLimited", "Codex rate-limited this check. " + suffix, status);
                    }
                    if (status == 401 || status == 403)
                    {
                        throw new CodexApiException(status == 401 ? "unauthorized" : "forbidden", "Codex rejected the saved login. Open Codex Desktop and sign in again.", status);
                    }
                    throw new CodexApiException("httpStatus", "The Codex endpoint returned HTTP " + status + ".", status);
                }
                throw new CodexApiException("invalidResponse", "The Codex endpoint returned an invalid response.");
            }
            catch (CodexApiException)
            {
                throw;
            }
            catch
            {
                throw new CodexApiException("decoding", "Codex data could not be decoded.");
            }
            finally
            {
                if (response != null)
                {
                    response.Dispose();
                }
            }
        }

        private string ResolvedCodexHome()
        {
            if (!String.IsNullOrWhiteSpace(codexHome))
            {
                return codexHome;
            }
            string env = Environment.GetEnvironmentVariable("CODEX_HOME");
            if (!String.IsNullOrWhiteSpace(env))
            {
                return ExpandHome(env);
            }
            string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return Path.Combine(userProfile, ".codex");
        }

        private static string ExpandHome(string path)
        {
            if (path == "~")
            {
                return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            }
            if (path.StartsWith("~" + Path.DirectorySeparatorChar) || path.StartsWith("~" + Path.AltDirectorySeparatorChar))
            {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), path.Substring(2));
            }
            return path;
        }

        private static string ReadBody(HttpWebResponse response)
        {
            using (Stream stream = response.GetResponseStream())
            using (StreamReader reader = new StreamReader(stream, Encoding.UTF8))
            {
                return reader.ReadToEnd();
            }
        }

        private static string AccountIdFromToken(string token, string fallback)
        {
            Dictionary<string, object> payload = JwtPayload(token);
            Dictionary<string, object> auth = JsonUtil.GetDictionary(payload, "https://api.openai.com/auth");
            string account = JsonUtil.GetString(auth, "chatgpt_account_id");
            return !String.IsNullOrWhiteSpace(account) ? account : fallback;
        }

        private static Dictionary<string, object> JwtPayload(string token)
        {
            if (String.IsNullOrWhiteSpace(token))
            {
                return null;
            }
            string[] parts = token.Split('.');
            if (parts.Length < 2)
            {
                return null;
            }
            try
            {
                byte[] data = DecodeBase64Url(parts[1]);
                return JsonUtil.ParseObject(Encoding.UTF8.GetString(data));
            }
            catch
            {
                return null;
            }
        }

        private static byte[] DecodeBase64Url(string value)
        {
            string padded = value.Replace('-', '+').Replace('_', '/');
            switch (padded.Length % 4)
            {
                case 2:
                    padded += "==";
                    break;
                case 3:
                    padded += "=";
                    break;
            }
            return Convert.FromBase64String(padded);
        }
    }
}
