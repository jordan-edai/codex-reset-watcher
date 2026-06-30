# Contributing

Thanks for taking a look at Codex Reset Watcher.

## Local Setup

Requirements:

- macOS 14 or newer
- Xcode Command Line Tools
- Codex Desktop installed and signed in if you want live data

Build:

```bash
swift build
```

Test:

```bash
swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1
```

Package a clickable app bundle:

```bash
./script/build_and_run.sh --package
```

Run the packaged app:

```bash
open "dist/Codex Reset Watcher.app"
```

## Pull Requests

- Read [AGENTS.md](AGENTS.md) before making changes in this repo.
- Keep the app small and read-only.
- Do not add telemetry.
- Do not store, print, upload, or copy Codex auth tokens.
- Keep user-facing copy clear that this is unofficial and uses an internal endpoint.
- Include a short validation note in PRs. For user-facing macOS changes, prefer:
  `swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1`,
  `CONFIGURATION=release ./script/package.sh`, and
  `CONFIGURATION=release ./script/build_and_run.sh --verify`.
- Keep release zips versioned. Do not upload wildcard or stale `dist/` artifacts.

## Icon

The checked-in `Assets/AppIcon.icns` is used by normal builds. To regenerate the icon:

```bash
python3 -m pip install pillow
./script/make_icon.py
```
