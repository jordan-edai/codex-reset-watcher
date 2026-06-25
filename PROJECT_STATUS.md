# Project Status

Last updated: 2026-06-25

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
v0.3.2
```

Latest tracked release state:

```text
v0.3.2 menu window-focus hotfix
```

## What Is Shipped

- `v0.1.0`: initial public app with reset-credit count, expiry dates, menu bar
  status, manual refresh, and app bundle packaging.
- `v0.2.0`: added current 5-hour and weekly usage limits, reset-use nudges,
  expiry urgency states, generated Codex-adjacent visuals, tests, CI packaging,
  and public privacy/security docs.
- `v0.2.1`: changed the menu bar title to show weekly usage, kept the status
  icon, added a regression test, and published a versioned release zip.
- `v0.2.2`: fixed the actual macOS menu bar rendering so the status icon and
  weekly text are visible together instead of collapsing to icon-only.
- `v0.2.3`: added a dropdown toggle for choosing whether the menu bar follows
  the weekly or 5-hour usage window.
- `v0.2.4`: labeled reset-credit expiry dates and 5-hour/weekly reset timing in
  the dropdown, improved menu readability, and showed the active account label.
- `v0.2.5`: added shared design-system tokens/modifiers, stabilized menu
  columns and gutters, split dropdown expiry dates into date/time lines,
  changed the menu bar title to show reset cues such as `57% | Sunday` or
  `80% | 9:50 PM`, and aligned desktop panel styling with the menu.
- `v0.2.6`: unified the menu popover and desktop window around the same header
  artwork, green operational accent, rounded typography, and panel/card surface
  treatment.
- `v0.3.0`: added safe local multi-account snapshots, a desktop account
  sidebar, compact cached-account rows in the menu dropdown, stale snapshot
  labels, and one-auth-context refresh handling to avoid account bleed.
- `v0.3.1`: fixed the active-account regression where otherwise-valid usage
  data could be rejected when the usage endpoint's account identifier differed
  from the local Codex Desktop auth-context account ID.
- `v0.3.2`: fixed cached-snapshot menu rows creating duplicate main windows,
  replaced the fragile native split-view shell with a fixed two-pane layout, and
  stopped implying local cached records were linked/live accounts.

## Current GitHub State

- Repo is public.
- Repo description: `Local-first macOS menu bar app for Codex usage limits and reset credits.`
- Latest release is `v0.3.2`.
- `v0.2.0` release asset cleanup was completed; the duplicate generic
  `Codex.Reset.Watcher.zip` was removed and the versioned zip was kept.
- PR #1 shipped usage limits and reset nudges.
- PR #2 shipped the weekly menu bar title.
- PR #4 fixed the visible menu bar label and versioned release upload path.
- PR #5 added the menu bar metric toggle.
- PR #6 labeled dropdown reset dates and limit reset timing.

## Key Decisions

- Keep the app read-only.
- Keep the app open source.
- Do not add telemetry or analytics.
- Do not redeem resets or mutate Codex account state.
- Do not store Codex bearer tokens outside the running app process.
- Keep the UI focused on the reset/usage question instead of growing into a
  broader Codex Cockpit.
- Keep visual updates on the shared `CodexPalette` and `CodexStyle` tokens
  before adding one-off colors, radii, spacing, or panel styles.
- Multi-account support is snapshot-based. The active Codex account refreshes
  live; other accounts are cached last-seen records only.
- Use the local Codex Desktop auth-context account ID as the snapshot key when
  it exists. Treat the usage response account ID as a fallback key only; it may
  be a different namespace and should not break the active account by itself.
- Menu rows that open cached snapshot details must reuse/focus the registered
  main window. `WindowGroup` is still used for launch behavior, so direct
  repeated `openWindow(id: "main")` calls can recreate the duplicate-window bug.
- The desktop account view uses a fixed two-pane sidebar/detail shell on
  purpose. Avoid reintroducing `NavigationSplitView` unless its hidden-sidebar
  behavior is manually tested in the packaged menu bar app.
- User-facing copy should call non-active saved records `cached snapshots`, not
  linked accounts or profiles. They are local last-seen records only.
- Persisted snapshots must remain derived-only and must not include tokens, raw
  auth, raw API responses, full account IDs, user IDs, or reset credit IDs.
- Use [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) as the future-maintainer guardrail
  for menu and desktop visual changes.
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
the active account id. Each refresh loads one auth context and uses it for both
usage and reset-credit calls.

The app also stores minimized multi-account snapshots at:

```text
~/Library/Application Support/Codex Reset Watcher/account-snapshots.json
```

The snapshot key is a salted hash. The local salt is stored next to the snapshot
file under Application Support.

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
- Add optional user nicknames for cached accounts.
