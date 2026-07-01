# Changelog

## 0.3.5 - 2026-06-30

- Treats Codex `allowed: false` / `limit_reached` usage responses as a first-class
  blocked state in the nudge logic, menu dropdown, desktop usage cards, and
  status icon instead of falling back to ordinary capacity advice.
- Stops guessing 5-hour versus weekly windows from endpoint order when
  `limit_window_seconds` is missing, and falls back to generic labeled usage
  rows until Codex returns a trustworthy duration.
- Hardens cached snapshot date math against implausible reset epochs and marks
  snapshots with no usage or reset signals as stale.
- Keeps missing-auth refreshes from stamping a fresh `last checked` time or
  leaving the UI selected on a cached snapshot that cannot be refreshed live.
- Removes the raw account-id suffix fallback from account labels when Codex does
  not provide an email or name.

## 0.3.4 - 2026-06-30

- Restores compact per-snapshot rows in the menu dropdown so cached snapshots
  select their detail view before opening the desktop window.
- Keeps cached-account detail copy honest by labeling cached usage as last-seen
  data, not live limits.
- Shows up to four reset expiry rows in the menu and includes the next hidden
  expiry cue when additional reset credits are available.
- Shows explicit unavailable-expiry rows when Codex reports more available reset
  credits than it returns usable expiry records for.
- Keeps `Clear stale` visible whenever stale cached snapshots exist.
- Shows elapsed reset windows as `now` instead of rounding expired cached reset
  timers up to `1m`.
- Hardens refresh reliability for same-account token rotation, swapped usage
  window ordering, flexible numeric endpoint fields, exact trusted Codex endpoint
  checks, sanitized live error messages, and reset-credit partial failures that
  should not carry old expiry rows forward as fresh data.
- Moves routine UI surfaces back onto light shared design tokens and documents
  the `CodexTone` / reusable component layer for future visual changes.
- Tightens the GitHub release workflow so tagged releases run tests, package the
  app, verify the bundle version against the tag, check the code signature, and
  validate the versioned zip before upload.
- Strips release binaries before signing so packaged apps do not retain local
  build/source paths in symbol metadata.
- Cleans old versioned release zips before packaging so release uploads cannot
  accidentally include stale artifacts.
- Documents versioned release zip assets in the install instructions.
- Verifies the packaged app with local UI QA against the menu bar title,
  dropdown metric toggle, cached snapshot selection, and stale cleanup surfaces.

## 0.3.3 - 2026-06-26

- Adds an explicit `Clear stale` action in the desktop sidebar, desktop footer,
  and menu dropdown so stale cached snapshots can be removed without clearing
  every cached snapshot.
- Renames the selected stale snapshot action to `Forget stale` so removing a
  single stale record is easier to discover.
- Adds a regression test for stale-snapshot cleanup persistence.

## 0.3.2 - 2026-06-25

- Fixes a menu-dropdown regression where clicking cached accounts could create
  additional main windows instead of focusing the existing window.
- Replaces the fragile desktop `NavigationSplitView` shell with a fixed two-pane
  sidebar/detail layout so cached-snapshot navigation cannot hide the sidebar.
- Renames the former `Other accounts` sections to `Cached snapshots` so local
  last-seen records are not confused with linked/live Codex accounts.
- Adds a small main-window presenter so menu actions reuse the registered main
  window and only create a new one if no main window exists.

## 0.3.1 - 2026-06-25

- Fixes a `v0.3.0` regression where the active account could be rejected with
  `Codex returned a different account than the active login` when the usage
  endpoint reported an account identifier in a different namespace than the
  local Codex Desktop auth context.
- Uses the Codex Desktop auth context as the active snapshot key when available,
  and falls back to the usage response account ID only when auth has no stable
  account ID.
- Adds a regression test that keeps active usage meters visible when the usage
  endpoint account ID differs from the auth context account ID.

## 0.3.0 - 2026-06-25

- Adds local multi-account snapshots: the active Codex account refreshes live,
  while previously seen accounts remain available as cached last-seen records.
- Adds a desktop sidebar with `Active account` and `Other accounts` sections,
  plus cached-account detail views, stale labels, `Forget`, and `Clear cached`
  controls.
- Keeps the menu bar title active-account-only, and adds compact cached-account
  rows in the dropdown that open the desktop window.
- Refactors refreshes around one loaded auth context so usage and reset-credit
  calls cannot mix account identities during a login switch.
- Stores only derived snapshot fields under Application Support, with salted
  hashed account keys and no bearer tokens, raw auth JSON, raw endpoint JSON,
  full account IDs, user IDs, or reset credit IDs.
- Adds tests for redaction, account-switch races, stale snapshots, missing auth,
  partial endpoint failures, duplicate labels across accounts, and deletion.

## 0.2.6 - 2026-06-25

- Aligns the menu bar popover and desktop window around the same app identity,
  accent color, rounded type scale, and panel surface treatment.
- Adds the checked-in header artwork to the menu popover header so both
  surfaces immediately read as Codex Reset Watcher.
- Moves neutral emphasis away from system blue and back to the shared green
  operational accent used by reset, nudge, and usage-meter states.
- Keeps usage-meter tracks visible after normalizing menu rows and desktop cards
  to the same panel surface.

## 0.2.5 - 2026-06-24

- Adds a shared SwiftUI design-system layer for Codex Reset Watcher spacing,
  radii, typography, row sizing, and panel styling.
- Updates the menu bar title to show the selected limit's next reset cue, for
  example `57% | Sunday` for weekly or `80% | 9:50 PM` for 5-hour.
- Reworks the menu dropdown around stable icon, content, metric, and date
  columns so rows no longer crowd or bleed into the popover edge.
- Splits reset-credit expiry dates into a deliberate weekday/date line and
  time line in the dropdown.
- Aligns the main desktop window with the same panel, row, color, and type
  tokens used by the menu bar dropdown.
- Reduces color drift by routing status colors through shared palette roles and
  removing the multi-color fallback artwork gradient.
- Adds `DESIGN_SYSTEM.md` so future visual updates have concrete guardrails.

## 0.2.4 - 2026-06-24

- Labels reset-credit expiry rows in the menu bar dropdown, for example
  `Reset 1 expires: Fri, Jul 17 at 7:38 PM`.
- Adds reset timing labels under the 5-hour and weekly limit rows in the
  dropdown.
- Adds weekdays to reset and expiry timestamps and improves the dropdown's
  contrast, row spacing, and type scale.
- Shows the active Codex account label in the menu bar dropdown and main app.
- Documents the conservative `v0.3.0` multi-account snapshot plan.

## 0.2.3 - 2026-06-24

- Adds a menu-bar display toggle in the dropdown so each user can choose
  whether the menu bar follows the weekly or 5-hour usage window.
- Persists the selected display mode locally with macOS app storage.

## 0.2.2 - 2026-06-24

- Fixes the visible macOS menu bar label so the status icon renders beside the
  weekly usage text.
- Keeps the `0.2.1` weekly percentage behavior, but corrects the actual
  menu-bar presentation that could collapse to icon-only.

## 0.2.1 - 2026-06-24

- Updates the menu bar title to show weekly usage remaining.
- Keeps the status icon in the menu bar so the weekly meter is glanceable without opening the popover.

## 0.2.0 - 2026-06-19

- Adds 5-hour and weekly Codex usage windows.
- Adds a reset-use nudge based on remaining usage, reset timing, reset-credit expiry, and banked reset credits.
- Adds expiry urgency states for reset rows, including this week, expires soon, ends today, and expired.
- Adds Codex-adjacent header artwork and a more visual main window.
- Adds a brighter high-contrast layout and generated reset-button app icon.
- Adds unit tests for reset-expiry urgency and reset-use nudge thresholds.
- Keeps usage and reset-credit endpoint failures independent so partial data can still render.

## 0.1.0

- Initial public release.
- Shows Codex reset credits and expiry dates.
- Adds menu-bar status and manual refresh.
- Packages as a simple macOS app bundle.
