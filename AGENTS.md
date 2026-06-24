# Agent Notes

This repo is **Codex Reset Watcher**, not Codex Cockpit.

Codex Reset Watcher is a small, open-source, local-first macOS menu bar app for
Codex usage limits and reset credits. Keep changes scoped to that product.

## Current State

- Public GitHub repo: `https://github.com/jordan-edai/codex-reset-watcher`
- Canonical local path: `/Users/everydayai/Documents/!Codex Projects/Rate Refresher Project`
- Compatibility path: `/Users/everydayai/Documents/Rate Refresher Project`
- Latest shipped release: `v0.2.1`
- Current `main` commit at the time of this note: `c9194e1`
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
- The menu bar title should prioritize weekly remaining usage, for example
  `63% | week`, with the status icon beside it.
- Reset count should use server `available_count` when provided so malformed
  detail rows do not undercount banked resets.

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

