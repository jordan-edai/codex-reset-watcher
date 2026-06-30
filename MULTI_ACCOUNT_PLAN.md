# Multi-Account Snapshot Design

Shipped in `v0.3.0`.

## Direction

Codex Reset Watcher uses a conservative snapshot model:

- The active Codex account refreshes live from the current local Codex Desktop
  login.
- Non-active saved records are cached last-seen snapshots only.
- The app never switches Codex accounts.
- The app does not present multiple accounts as simultaneous live dashboards.
- Refreshing another account requires signing into that account in Codex
  Desktop.
- Cached snapshots must be labeled as cached or stale, with the last refreshed
  time visible.

## Account Labels

Use the safest available label, in this order:

1. Email from the live usage response.
2. Email from the local Codex `id_token`.
3. Name from the local Codex `id_token`.
4. A short account-id fallback, such as `Codex account 123abc`.

Do not show full account email in the menu bar title. It is too easy to leak in
screenshots. Full labels can appear inside the dropdown or main window with
middle truncation.

## Storage

Snapshots are stored under Application Support:

```text
~/Library/Application Support/Codex Reset Watcher/account-snapshots.json
```

A local install salt is stored next to that file. Account snapshot keys are
salted hashes.

Allowed snapshot fields:

- schema version
- salted hashed account key
- optional user nickname field
- display label
- plan label
- last checked timestamp
- 5-hour and weekly remaining percentages
- 5-hour and weekly reset times
- reset count and reset expiry dates
- coarse cached or error state

Do not store:

- bearer tokens
- refresh tokens
- ID tokens
- raw auth JSON
- raw API responses
- cookies
- API keys
- full account IDs
- user IDs
- reset credit IDs

## UX

Menu bar dropdown:

- Keep the active account at the top.
- Keep the menu bar title focused on the active account only.
- Show cached snapshots in a compact `Cached snapshots` section.
- Cached snapshot rows open the main window detail; they do not change the menu
  bar title.
- Cached snapshot rows must reuse/focus the existing main window. Do not open a
  fresh main window for each row click.

Main window:

- Use a left sidebar account list, not tabs.
- Pin the active account first.
- Group cached snapshots under `Cached snapshots`.
- Show the current detail layout for the selected account.
- Provide `Forget` for cached accounts and `Clear cached` for all cached
  snapshots.
- Keep stale cleanup discoverable with `Forget stale` for the selected stale
  snapshot and `Clear stale` for stale-only bulk cleanup.

## Privacy And Release Requirements

Multi-account support changes the privacy surface because the app writes
derived usage snapshots to disk. Any future changes to snapshot contents must
update `README.md`, `PRIVACY.md`, `SECURITY.md`, `AGENTS.md`, and
`PROJECT_STATUS.md`.

Required tests:

- account-bleed prevention
- stale labels
- invalid auth behavior
- snapshot deletion
- stale-only cleanup that preserves fresh cached snapshots
- persistence redaction
- corrupt or old schema files
- endpoint failures that preserve cached snapshots without rewriting them as
  fresh empty active data

Manual QA boundary:

- Before claiming a specific two-real-account workflow works on a new machine,
  sign out of Codex Desktop, sign into another real Codex account, refresh, and
  confirm the previous account appears only as a cached snapshot while the new
  login is the only active live account.
