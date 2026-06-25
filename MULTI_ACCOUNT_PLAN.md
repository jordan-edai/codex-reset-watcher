# Multi-Account Plan

Planned for a future `v0.3.0` release. Do not mix this into `v0.2.x` patch
work.

## Direction

Use a conservative snapshot model:

- The active Codex account refreshes live from the current local Codex Desktop
  login.
- Other accounts are cached last-seen snapshots only.
- The app never stores bearer tokens, refresh tokens, ID tokens, cookies, raw
  endpoint JSON, or `~/.codex/auth.json` contents.
- Inactive accounts must be labeled as cached or stale, with the last refreshed
  time visible.

## Account Labels

Use the safest available label, in this order:

1. Email from the live usage response.
2. Email from the local Codex `id_token`.
3. Name from the local Codex `id_token`.
4. Plan plus a short account-id fallback, such as `Pro account 123abc`.

Do not show full account email in the menu bar title. It is too easy to leak in
screenshots. Full labels can appear inside the dropdown or main window.

## Storage

If account snapshots are added, store minimized derived data under Application
Support, for example:

```text
~/Library/Application Support/Codex Reset Watcher/account-snapshots.json
```

Allowed snapshot fields:

- schema version
- hashed or shortened account identifier
- user-provided nickname
- display label
- plan label
- last checked timestamp
- 5-hour and weekly remaining percentages
- 5-hour and weekly reset times
- reset count and reset expiry dates
- stale or error state

Do not store:

- bearer tokens
- refresh tokens
- ID tokens
- raw auth JSON
- raw API responses
- cookies
- API keys
- full account IDs
- reset credit IDs unless absolutely needed

## UX

Menu bar dropdown:

- Keep the active account at the top.
- Add an account picker only when more than one snapshot exists.
- Cached accounts must show `Cached` and `Last refreshed ...`.
- Keep the menu bar title focused on the active account only.

Main window:

- Prefer a left sidebar account list over cramped tabs.
- Pin the active account first.
- Group cached accounts under `Other accounts`.
- Show the current detail layout for the selected account.
- Add `Forget this account` and `Clear cached accounts`.

## Privacy And Release Requirements

Multi-account changes the privacy surface because the app would start writing
derived usage snapshots to disk.

Before release:

- Update `README.md`, `PRIVACY.md`, `SECURITY.md`, `AGENTS.md`, and
  `PROJECT_STATUS.md`.
- Add a visible local-only explanation for cached account snapshots.
- Add tests for account bleed, stale labels, invalid auth, snapshot deletion,
  and persistence redaction.
- Grep release artifacts for real emails, account IDs, JWT-like strings, token
  prefixes, and local machine paths.
