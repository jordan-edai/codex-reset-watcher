# Project Status

Last updated: 2026-07-11

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
v0.4.2
```

Latest tracked release state:

```text
v0.4.2 natural-height menu and section-order fix
```

Latest local release branch:

```text
codex/v0.4.2-natural-menu-height
```

The v0.4.2 fix removes the v0.4.1 screen-sized viewport entirely. The menu now
hugs its intrinsic content height, uses the requested settings/limits/banked
expiration order, and leaves cached snapshots in the full desktop app only.

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
- `v0.3.3`: added visible stale-snapshot cleanup controls in the desktop sidebar,
  desktop footer, and menu dropdown, plus clearer `Forget stale` copy for single
  stale snapshot removal.
- `v0.3.4`: hardened the multi-account snapshot and endpoint edge cases, restored
  a light shared UI system, added explicit missing-expiry rows when server counts
  exceed usable expiry records, tightened release packaging checks, and refreshed
  maintainer docs.
- `v0.3.5`: treats blocked usage responses as first-class UI/nudge states,
  stops guessing 5h/weekly windows when duration fields are missing or
  duplicated, guards implausible reset epochs, avoids fresh timestamps on
  missing-auth refreshes, and removes raw account-id suffix label fallbacks.
- `v0.3.6`: refreshes the shared visual system, adds Light/Dark/Auto modes,
  adds tested green/amber/red usage-capacity bars, and keeps menu/desktop
  styling aligned around the same tokens and meters.
- `v0.3.7`: fixes desktop reset-row column overlap, reduces wasteful desktop
  vertical spacing, and gives the real menu dropdown a wider, more comfortable
  rhythm for ordinary reset states.
- `v0.3.8`: opens the desktop window roughly 10% larger by default, enforces a
  roomier minimum for restored windows, and adds a regression test for the
  window-size floor.
- `v0.4.0`: makes unknown and partial live states explicit, prevents mixed
  account snapshots during login changes, keeps cached advice neutral, uses
  server reset counts honestly, bounds hostile response values, rejects unsafe
  redirects and semantically empty payloads, and expands release/secret-scan
  verification.
- `v0.4.1`: fixes the menu reopening partway down, removes the static content
  height cap, expands to the active screen when possible, and keeps scrolling as
  a top-anchored fallback only for genuinely constrained screens.
- `v0.4.2`: removes that v0.4.1 fallback viewport after it created large blank
  bands, restores intrinsic menu height, reorders the menu sections, renames the
  reset section, and removes cached snapshots from the dropdown.

## Current GitHub State

- Repo is public.
- Repo description: `Local-first macOS menu bar app for Codex usage limits and reset credits.`
- Latest release is `v0.4.2`.
- `v0.2.0` release asset cleanup was completed; the duplicate generic
  `Codex.Reset.Watcher.zip` was removed and the versioned zip was kept.
- v0.3.4 audit fixes restored per-snapshot menu navigation, distinguish
  cached last-seen limits from live limits, tighten endpoint decoding/trust
  checks, sanitize live refresh errors, and avoid showing stale reset expiry rows
  after reset-credit endpoint failures.
- v0.3.4 release hygiene now verifies the release tag against the packaged
  app version, strips local build paths from release binaries, checks the bundle
  signature and zip integrity, and uploads the exact current versioned zip
  instead of a wildcard.
- v0.3.4 also shows explicit unavailable-expiry rows when Codex reports a higher
  reset-credit count than it returns usable expiry rows for.
- Release `v0.3.4` was published on 2026-06-30 with
  `Codex.Reset.Watcher.v0.3.4.zip`.
- v0.3.5 audit follow-up fixes make blocked limits visible across the menu and
  desktop UI, keep unknown usage windows generic instead of guessed, harden
  reset-date conversion, and clarify no-auth refresh state.
- Release `v0.3.5` was published on 2026-06-30 with
  `Codex.Reset.Watcher.v0.3.5.zip`.
- Release `v0.3.6` refreshes the UI with adaptive appearance modes and
  tested capacity bar colors.
- Release `v0.3.7` fixes the follow-up layout issues from `v0.3.6`: desktop
  reset date overlap, excessive desktop vertical spacing, and menu sizing that
  needs enough width/height to avoid a cramped dropdown.
- Release `v0.3.8` fixes the remaining desktop first-open sizing issue by
  growing the default/minimum window so ordinary content is not cut off at the
  bottom.
- Release `v0.4.0` hardens state presentation, refresh/account race handling,
  response trust/validation, input bounds, nudge logic, snapshot privacy, and
  universal release verification.
- Release `v0.4.1` restores the menu's primary job: current limits and reset
  expiry dates remain visible whenever the active screen has room for the full
  dropdown.
- Release `v0.4.2` corrects the remaining v0.4.1 height regression by removing
  forced menu sizing and simplifying the dropdown to its active-account content.
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
- Keep Light, Dark, and Auto appearance behavior wired through
  `CodexAppearanceMode`, `preferredColorScheme`, and `NSApp.appearance` so the
  custom palette follows the selected mode in menu-bar popovers and windows.
- Usage capacity colors are semantic: green for 60% or more remaining, amber
  for 25-59%, red below 25%, and danger styling for blocked windows regardless
  of decoded percentage.
- Keep desktop reset rows column-based so labels, long dates, and status
  treatment cannot overlap at the default window width.
- Multi-account support is snapshot-based. The active Codex account refreshes
  live; other accounts are cached last-seen records only.
- Multi-account support is not simultaneous multi-login. A cached snapshot is a
  local last-seen record, not a live dashboard for that account.
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
- Stale snapshots must have an obvious cleanup path. Preserve `Clear stale`
  controls and the `Forget stale` single-record action when changing this UI.
- Counts must stay honest. If Codex reports banked resets without usable expiry
  data, the UI should show missing-expiry rows instead of silently hiding them.
- If Codex reports `allowed: false` or `limit_reached`, show a blocked state
  even when the remaining percentage fields still look nonzero.
- Do not infer 5-hour or weekly windows from response order alone. When
  `limit_window_seconds` is missing or duplicates an existing known window,
  show a generic usage row rather than presenting guessed 5h/weekly data.
- Treat implausible `reset_at` values as missing data. Reset-date math must
  stay bounded and non-crashing because these are unofficial internal endpoints.
- Persisted snapshots must remain derived-only and must not include tokens, raw
  auth, raw API responses, full account IDs, user IDs, or reset credit IDs.
- If both live endpoints fail, do not rewrite an existing cached snapshot with
  empty fresh data. Preserve the last known cached snapshot as cached.
- Endpoint trust checks should remain exact: HTTPS, `chatgpt.com`, known `/wham`
  paths, and no userinfo, query, fragment, or custom port.
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
- Multi-account logic is covered by unit tests and local snapshot QA, but any
  claim about a specific two-real-account login flow should be manually
  rechecked by signing into the second Codex Desktop account on that machine.

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

## Latest Local Verification

The `v0.4.2` release candidate was locally verified on 2026-07-11 with:

```bash
swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1
git diff --check
CONFIGURATION=release ./script/package.sh
CONFIGURATION=release ./script/build_and_run.sh --verify
plutil -extract CFBundleShortVersionString raw -o - \
  "dist/Codex Reset Watcher.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Codex Reset Watcher.app"
unzip -t "dist/Codex.Reset.Watcher.v0.4.2.zip"
strings "dist/Codex Reset Watcher.app/Contents/MacOS/CodexResetWatcher" | rg \
  "youreverydayai|everydayai|acct_|user_|credit-full|eyJ|access_token|refresh_token|id_token|auth\\.json|rate_limit"
```

The final string scan returned no matches.

The SwiftPM suite passed 106 tests. The release workflow also checks the tag
version, universal arm64/x86_64 packaging, signature, zip integrity, and
sensitive-string scan before publishing an asset.

The packaged app opened successfully during local smoke QA. Screenshot checks
confirmed the active desktop view, current limits, reset-credit rows, cached
snapshot sidebar, and the real menu bar title render from the release bundle.
Menu-height QA used the reported v0.4.1 screenshot plus an `ImageRenderer`
geometry check of the real three-reset menu view. The corrected view rendered at
470 by 740 points with no forced frame, no top/bottom blank bands, the requested
section order, all three expiry dates, and no cached-snapshot section. Native
segmented controls and buttons still require a live-window check because
`ImageRenderer` does not faithfully draw those AppKit-backed controls.
