# Codex Reset Watcher

<img src="Assets/AppIcon.png" width="128" alt="Codex Reset Watcher icon">

Unofficial macOS utility for checking Codex rate-limit windows and banked reset credits.

It reads your existing local Codex Desktop login from `~/.codex/auth.json`, calls the same internal Codex Desktop endpoints used by the app, and shows:

- current 5-hour usage remaining
- current weekly usage remaining
- menu bar display switching between weekly reset-day and 5h reset-time cues,
  for example `57% | Sunday` or `80% | 9:50 PM`
- active account label from the current local Codex login or usage response
- cached snapshots for previously seen Codex accounts, labeled separately from
  the active account
- banked reset credits and expiry dates
- expiry urgency warnings as reset credits get closer to lapsing
- a reset-use nudge based on remaining 5h/weekly capacity, reset timing, reset-credit expiry, and reset credits in the bank

Codex Reset Watcher is read-only. It does not redeem resets, reset usage, modify your account, or send analytics.

## Requirements

- macOS 14 or newer
- Codex Desktop installed and signed in

No API key is required.

## Install

1. Download `Codex Reset Watcher.zip` from the latest GitHub release.
2. Unzip it.
3. Drag `Codex Reset Watcher.app` into `/Applications`.
4. Open it.

If macOS warns that the app is from an unidentified developer, right-click the app and choose **Open**. Public distribution should use a Developer ID signed and notarized build.

## Build From Source

```bash
git clone https://github.com/jordan-edai/codex-reset-watcher.git
cd codex-reset-watcher
./script/build_and_run.sh --package
open "dist/Codex Reset Watcher.app"
```

The script uses SwiftPM and writes SwiftPM scratch files under `/tmp/codex-reset-watcher-build` to avoid file-provider issues in synced folders.

## Nudge Logic

The app uses rule-based advice from the data Codex returns for the current signed-in account. It does not use account-specific hardcoding.

- Low weekly room, resets banked, and weekly refresh far away: push the work and use a reset if Codex blocks meaningful work.
- Healthy weekly room but low 5-hour room: wait if the 5-hour refill is close, but treat it as a deadline call if the refill is still hours away.
- Healthy weekly room with weekly refresh close: keep the reset banked.
- Reset credit expiring today: show a use-it-or-lose-it warning before conservative hold advice.

Reset-credit rows also change urgency as expiry gets close: available, this week, expires soon, ends today, or expired.

## Multi-Account Snapshots

The active Codex account is always the one currently signed into Codex Desktop.
Codex Reset Watcher does not switch accounts for you, and it does not show
multiple accounts as simultaneous live dashboards.

After a successful refresh, the app saves a minimized local snapshot for that
account. If you later sign into a different Codex account, the current account
updates live and previously seen accounts appear under **Cached snapshots** as
cached snapshots.

Cached snapshots are last-seen records, not live dashboards. They are labeled
`Cached snapshot` or `Stale snapshot`, and they refresh only when that account
becomes the active Codex Desktop login again.

Use `Forget stale` to remove a selected stale snapshot, or `Clear stale` to
remove stale snapshots without clearing every cached record.

The snapshot model is covered by unit tests for account-switch races,
same-label accounts with different account IDs, stale cleanup, invalid auth,
partial endpoint failures, corrupt snapshot files, and sensitive-field
redaction. Manual QA should still include signing into a second real Codex
Desktop account before claiming a specific cross-account login flow works in a
new environment.

Snapshots are stored locally at:

```text
~/Library/Application Support/Codex Reset Watcher/account-snapshots.json
```

The app stores derived fields such as display label, plan label, last checked
time, 5-hour/weekly percentages, reset times, reset count, and reset expiry
dates. It does not store Codex bearer tokens, refresh tokens, ID tokens, raw
auth JSON, raw endpoint responses, full account IDs, user IDs, cookies, API
keys, or reset credit IDs.

## Visual Assets

`Assets/AppIconSource.png` and `Assets/UsageHeader.png` are AI-generated artwork created for this project. They are included with the MIT-licensed source and are not OpenAI logos or product marks.

## Design System

Shared visual tokens live in `Sources/CodexResetWatcher/Support/CodexPalette.swift`
and `Sources/CodexResetWatcher/Support/CodexStyle.swift`. Use those colors,
spacing values, radii, typography styles, and panel/row modifiers for menu and
desktop UI changes so the app stays visually consistent. See
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) before making visual changes.

See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for the guardrails future visual
updates should follow.

## What It Calls

```text
GET https://chatgpt.com/backend-api/wham/usage
GET https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

Headers are built from the existing Codex Desktop auth file. The app loads one
auth context per refresh, sends the saved bearer token in the `Authorization`
header and, when available, the active account id in the `ChatGPT-Account-Id`
header to those endpoints. It does not redeem resets, mutate account state, or
store your token anywhere else.

`/wham/usage` currently provides the 5-hour and weekly rate-limit windows. `/wham/rate-limit-reset-credits` provides detailed reset-credit expiry dates. These endpoints are internal and can change without notice.

## Privacy

See [PRIVACY.md](PRIVACY.md).

## Limitations

- This is unofficial and not affiliated with OpenAI.
- The endpoints are internal and may change without notice.
- Usage and reset-credit fields may differ by Codex plan, account type, region, or app version.
- The release app is ad-hoc signed unless a maintainer publishes a Developer ID notarized build.

## Maintainers

Current progress, decisions, and future-agent notes live in
[PROJECT_STATUS.md](PROJECT_STATUS.md), [AGENTS.md](AGENTS.md), and
[MULTI_ACCOUNT_PLAN.md](MULTI_ACCOUNT_PLAN.md).

Run tests:

```bash
swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1
```

Package a release zip:

```bash
./script/package.sh
```

Regenerate the icon:

```bash
python3 -m pip install pillow
./script/make_icon.py
```

## License

MIT. See [LICENSE](LICENSE).
