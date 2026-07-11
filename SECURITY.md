# Security Policy

## Supported Versions

This is a small unofficial utility. Only the latest commit on `main` is supported.

## Reporting A Vulnerability

Please open a private GitHub security advisory if available, or contact the repository owner.

Do not paste Codex auth tokens, `~/.codex/auth.json`, screenshots containing secrets, or bearer tokens into public issues.

## Security Notes

Codex Reset Watcher:

- reads the local Codex Desktop auth file at `~/.codex/auth.json`
- may read account name or email claims from the local Codex ID token only to
  label the active account in the UI
- sends the saved Codex bearer token only to:
  - `https://chatgpt.com/backend-api/wham/usage`
  - `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- rejects non-exact endpoint URLs before a request is sent, including URLs with
  another host, another path, userinfo, query string, fragment, or custom port
- rejects redirects when the final response URL is not one of those exact
  trusted endpoints
- rejects empty auth tokens before a request is sent
- rejects semantically empty or unrecognized successful JSON responses instead
  of treating them as valid zero-data responses
- sends the active account id in the `ChatGPT-Account-Id` header to those same endpoints when Codex auth exposes it
- does not redeem resets
- does not write to the auth file
- does not store tokens elsewhere
- stores only minimized derived multi-account snapshots under Application
  Support
- stores account snapshot keys as salted hashes, not full account IDs
- does not store bearer tokens, refresh tokens, ID tokens, raw auth JSON, raw
  endpoint JSON, full account IDs, user IDs, cookies, API keys, or reset credit
  IDs in snapshots
- does not include analytics or telemetry
- uses a dedicated stateless URL session without shared cookies, URL cache, or
  credential persistence for refresh calls

Each refresh loads one auth context and uses it for both usage and reset-credit
requests so the app does not mix account identities if Codex Desktop changes
login mid-refresh.

The endpoint is internal and may change without notice.
