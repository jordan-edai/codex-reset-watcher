# Privacy

Codex Reset Watcher is read-only.

The app reads your existing Codex Desktop login from:

```text
~/.codex/auth.json
```

It uses that login to call:

```text
https://chatgpt.com/backend-api/wham/usage
https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

The app only trusts those exact HTTPS endpoints. Requests with another host,
path, query string, fragment, userinfo, or custom port are rejected before the
network request is sent.

The app does not:

- ask for an OpenAI API key
- redeem or modify reset credits
- reset usage
- send data to third-party services
- include analytics
- copy or store your token outside the running app process

The app displays the active account label when Codex exposes one, plus plan
type, rate-limit window percentages, reset timing, and reset-credit expiry data
returned by Codex.

## Local Account Snapshots

Codex Reset Watcher saves minimized local snapshots so previously seen Codex
accounts can appear as cached records after you sign into another account.

Snapshots are written to:

```text
~/Library/Application Support/Codex Reset Watcher/account-snapshots.json
```

The app also stores a local install salt next to that file so account keys can
be salted and hashed.

Snapshot fields are derived display data only:

- salted hashed account key
- optional nickname field
- display label
- plan label
- last checked timestamp
- 5-hour and weekly remaining percentages and reset dates
- reset count and reset expiry dates
- coarse cached/error status

Snapshots do not include bearer tokens, refresh tokens, ID tokens, raw
`~/.codex/auth.json` contents, raw API responses, full account IDs, user IDs,
cookies, API keys, or reset credit IDs.

Cached accounts are not refreshed in the background. A cached account updates
only when that account is again the active Codex Desktop login.

If an endpoint or Codex auth format changes, the app may stop working or show partial data.
