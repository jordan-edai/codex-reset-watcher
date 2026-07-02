# Agent Notes

This repo is **Codex Reset Watcher**, not Codex Cockpit.

Codex Reset Watcher is a small, open-source, local-first macOS menu bar app for
Codex usage limits and reset credits. Keep changes scoped to that product.

## Current State

- Public GitHub repo: `https://github.com/jordan-edai/codex-reset-watcher`
- Canonical local path: `/Users/everydayai/Documents/!Codex Projects/Rate Refresher Project`
- Compatibility path: `/Users/everydayai/Documents/Rate Refresher Project`
- Latest shipped release: `v0.3.7`
- Check `git log --oneline --decorate -5` for the current `main` commit; this
  note tracks the repo state through the `v0.3.7` compact responsive layout fix.
- App bundle version is set in `script/build_and_run.sh`.

## Product Decisions

- The app must stay read-only.
- Do not redeem reset credits, reset usage, mutate account state, or add
  analytics.
- No OpenAI API key is required. The app uses the existing local Codex Desktop
  login at `~/.codex/auth.json`.
- The app currently calls internal Codex Desktop endpoints:
  - `https://chatgpt.com/backend-api/wham/usage`
  - `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- These endpoints can change without notice. Keep decoding tolerant and failure
  handling partial-data-friendly.
- The menu bar title should prioritize the selected limit's remaining usage and
  next reset cue, for example `57% | Sunday` for weekly or `80% | 9:50 PM` for
  5-hour, with the status icon beside it.
- Use an explicit SwiftUI `HStack` label for `MenuBarExtra`; a `Label` can
  collapse to icon-only in the real macOS menu bar even when the title string
  itself is correct.
- The dropdown includes a persisted `Menu bar` segmented control. `Week` shows
  weekly remaining usage plus the next weekly reset weekday, and `5h` shows the
  5-hour remaining usage plus the next 5-hour reset time.
- Reset-credit rows in the dropdown should always label the date, for example
  `Reset 1 expires:`. The 5-hour and weekly usage rows should also label when
  those windows reset.
- Visual styling should flow through `CodexPalette` and `CodexStyle`. Prefer
  shared spacing, radius, type, row, and panel tokens over one-off view-local
  constants so the menu dropdown and desktop window stay visually aligned.
- Appearance mode is shared by the menu dropdown and desktop window. Keep
  Light/Dark/Auto routed through `CodexAppearanceMode`, SwiftUI
  `preferredColorScheme`, and `NSApp.appearance` so custom palette colors
  actually switch in menu-bar popovers.
- Usage capacity bars use remaining-percentage thresholds from the 2026 design
  refresh: green at 60% or higher, amber from 25% through 59%, and red below
  25%. Blocked usage windows override percentage color with danger styling.
- Keep desktop reset rows responsive and column-based. Labels/details and large
  expiry dates should never share one flexible inline text row, because that
  caused overlap at the default utility-window width.
- Routine app surfaces should stay light. Avoid smoky gray, dark tinted row
  fills, and dark terminal-block branding for normal states; use icons, borders,
  badges, and meters for emphasis, and reserve colored fills for warning/danger.
- Read `DESIGN_SYSTEM.md` before making visual changes.
- The menu dropdown uses fixed icon, content, metric, and date columns. Preserve
  that rhythm when adding rows so labels do not bleed into popover edges.
- Keep the menu dropdown comfortably sized. Do not solve menu fit by stacking
  overly dense rows; widen the popover and use readable row heights when reset
  credits, cached snapshots, and footer actions are all visible together.
- The active account label can come from the usage response email, local
  `id_token` email/name, or a short account-id fallback.
- Multi-account support is snapshot-based. The active account refreshes live;
  other accounts are cached last-seen snapshots only.
- Do not describe cached snapshots as simultaneous live accounts. They are
  local records from previous active Codex Desktop logins.
- Snapshot persistence must stay minimized and derived-only. Do not store bearer
  tokens, refresh tokens, ID tokens, raw auth JSON, raw endpoint JSON, full
  account IDs, user IDs, cookies, API keys, or reset credit IDs.
- Account snapshot keys are salted hashes stored under Application Support.
- Refreshes must use one loaded auth context for identity, usage, and reset
  credits so account switches cannot mix data across accounts.
- When the auth context has a stable account ID, use that as the snapshot key.
  The usage endpoint can report an account identifier from a different namespace;
  do not reject otherwise-valid active usage data solely because those strings
  differ.
- Menu cached-snapshot rows should focus the existing main window and update the
  shared account selection. Do not call `openWindow(id: "main")` directly from
  those rows, because `WindowGroup` can create duplicate main windows.
- The desktop window intentionally uses a fixed two-pane sidebar/detail shell,
  not a native `NavigationSplitView`. The native split view's sidebar toggle can
  hide the account list in this compact utility window.
- User-facing copy should call non-active saved records `cached snapshots`, not
  linked accounts or profiles. They are local last-seen records only.
- Stale cached snapshots must be removable without clearing all cached
  snapshots. Keep `Clear stale` available from the desktop sidebar/footer and
  menu dropdown, and keep the selected stale row action labeled `Forget stale`.
- Before claiming a two-real-account flow is verified on a user machine, manual
  QA must include signing into a second real Codex Desktop account and checking
  that the previous login appears only as a cached snapshot.
- Reset count should use server `available_count` when provided so malformed
  detail rows do not undercount banked resets.
- If `available_count` is higher than the usable expiry rows returned by Codex,
  show explicit missing-expiry rows rather than hiding the extra banked resets.
- Treat Codex `allowed: false` / `limit_reached` usage responses as blocked
  even if the percentage fields still decode. Blocked is more urgent than
  normal reset-advice nudges.
- Do not infer `5h limit` or `Weekly limit` from endpoint order when
  `limit_window_seconds` is missing. Use generic `Primary limit` /
  `Secondary limit` rows until Codex returns a trustworthy duration.
- If Codex returns duplicate known window durations, keep the first known
  window and downgrade the duplicate to a generic row so the UI does not show
  two weekly or two 5h cards.
- Guard `reset_at` and reset-duration math. Implausible epochs, infinities,
  and overflowing intervals should become missing timing data, not crashes.
- Trusted Codex endpoint checks should stay exact: HTTPS, `chatgpt.com`, known
  `/backend-api/wham/...` path, and no userinfo, query, fragment, or custom port.

## Git And Workspace Rules

- Keep this project open source.
- Use branches for changes, open PRs, wait for CI, then merge and release when
  the user-facing app changes.
- Do not commit unrelated local repair or recovery files. As of this note,
  there are untracked `codex-thread-folder-repair/` and
  `codex-thread-recovery-*` files in the workspace; leave them alone unless the
  user explicitly asks.
- Do not mix Codex Cockpit work back into this repository. Cockpit work was
  split away after accidental commits briefly touched this repo.

## Verification Commands

Run tests:

```bash
swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1
```

Package a release app:

```bash
CONFIGURATION=release ./script/package.sh
```

Smoke-test the packaged app:

```bash
CONFIGURATION=release ./script/build_and_run.sh --verify
```

Check the bundle version:

```bash
plutil -extract CFBundleShortVersionString raw -o - \
  "dist/Codex Reset Watcher.app/Contents/Info.plist"
```

## Release Checklist

1. Update `CHANGELOG.md`.
2. Update `VERSION` in `script/build_and_run.sh`.
3. Run tests and package verification.
4. Push a branch and open a PR.
5. Wait for PR CI.
6. Merge to `main`.
7. Wait for main CI.
8. Tag the release, for example `v0.2.2`.
9. Upload a versioned zip only, for example
   `Codex.Reset.Watcher.v0.2.2.zip`.
10. Inspect packaged release strings for real emails, full account IDs,
    JWT-looking strings, token prefixes, local auth paths, and raw endpoint JSON.
