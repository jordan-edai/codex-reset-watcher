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
- Release candidates should also verify the packaged executable contains both
  `arm64` and `x86_64` slices, the versioned zip opens cleanly, and the binary
  contains no emails, account IDs, JWT-looking strings, token prefixes, local
  auth paths, or raw endpoint JSON.
- Menu-bar UI changes require real popover QA. Confirm the dropdown hugs its
  visible rows with no forced-height blank bands, uses the documented section
  order, shows all banked reset dates, and contains no cached-snapshot section.
- Confirm the compact macOS menu bar title shows weekly percentage plus reset
  weekday. Missing weekly data must show `--% | week`, never a 5-hour value or
  reset count; the dropdown must not expose a metric selector during the
  temporary weekly-only phase.
- Keep release zips versioned. Do not upload wildcard or stale `dist/` artifacts.

## Icon

The checked-in `Assets/AppIcon.icns` is used by normal builds. To regenerate the icon:

```bash
python3 -m pip install pillow
./script/make_icon.py
```
