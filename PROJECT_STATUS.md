# Project Status

Last updated: 2026-06-24

## Summary

Codex Reset Watcher is a public, open-source macOS SwiftUI menu bar app for
showing Codex usage limits and banked reset credits. It is intentionally small,
read-only, and local-first.

Repository:

```text
https://github.com/jordan-edai/codex-reset-watcher
```

Current release:

```text
v0.2.2
```

Latest tracked release state:

```text
v0.2.2 menu bar visibility patch
```

## What Is Shipped

- `v0.1.0`: initial public app with reset-credit count, expiry dates, menu bar
  status, manual refresh, and app bundle packaging.
- `v0.2.0`: added current 5-hour and weekly usage limits, reset-use nudges,
  expiry urgency states, generated Codex-adjacent visuals, tests, CI packaging,
  and public privacy/security docs.
- `v0.2.1`: changed the menu bar title to show weekly remaining usage such as
  `63% | week`, kept the status icon, added a regression test, and published a
  versioned release zip.
- `v0.2.2`: fixed the actual macOS menu bar rendering so the status icon and
  weekly text are visible together instead of collapsing to icon-only.

## Current GitHub State

- Repo is public.
- Repo description: `Local-first macOS menu bar app for Codex usage limits and reset credits.`
- Latest release is `v0.2.2`.
- `v0.2.0` release asset cleanup was completed; the duplicate generic
  `Codex.Reset.Watcher.zip` was removed and the versioned zip was kept.
- PR #1 shipped usage limits and reset nudges.
- PR #2 shipped the weekly menu bar title.
- PR #4 fixed the visible menu bar label and versioned release upload path.

## Key Decisions

- Keep the app read-only.
- Keep the app open source.
- Do not add telemetry or analytics.
- Do not redeem resets or mutate Codex account state.
- Do not store Codex bearer tokens outside the running app process.
- Keep the UI focused on the reset/usage question instead of growing into a
  broader Codex Cockpit.
- Use generated visual assets only when they are checked in and documented as
  non-logo, project-specific artwork.
- Use tolerant decoding and partial-data rendering because Codex internal
  endpoints may change.

## Data Sources

The app currently reads:

```text
~/.codex/auth.json
```

The app currently calls:

```text
GET https://chatgpt.com/backend-api/wham/usage
GET https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

Headers are built from the saved Codex Desktop auth token and, when available,
the active account id.

## Known Boundaries

- This is unofficial and not affiliated with OpenAI.
- The endpoints are internal and may change without notice.
- The distributed app is ad-hoc signed unless a future maintainer publishes a
  Developer ID signed and notarized build.
- Usage fields may vary by plan, account type, region, or Codex app version.

## Local Workspace Notes

The canonical local project path is:

```text
/Users/everydayai/Documents/!Codex Projects/Rate Refresher Project
```

The user may also refer to:

```text
/Users/everydayai/Documents/Rate Refresher Project
```

That path resolves to the same project location in the current setup.

Old `0.1.0` app bundle copies under the June 18 Codex work/output folders were
deleted on 2026-06-24 so Spotlight only finds the current app bundle under this
project.

There are unrelated untracked local thread-repair and recovery files in this
workspace. They are not part of Codex Reset Watcher and should not be committed
unless the user explicitly asks.

## Next Sensible Improvements

- Consider moving from direct internal `/wham` calls toward Codex app-server
  account usage/rate-limit APIs if those become stable enough for this use.
- Add notarized release packaging if public adoption grows.
- Add a small in-app version/about view.
- Add a clearer error state when Codex auth exists but the internal endpoint
  shape changes.
