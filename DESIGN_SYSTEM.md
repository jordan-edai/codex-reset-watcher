# Design System

Codex Reset Watcher should feel like a compact macOS developer utility:
quiet, readable, and useful at a glance. The reset credits and expiry dates are
the visual priority.

## Source Of Truth

- Colors live in `Sources/CodexResetWatcher/Support/CodexPalette.swift`.
- Radius, spacing, size, typography, and shared view modifiers live in
  `Sources/CodexResetWatcher/Support/CodexStyle.swift`.
- Menu and desktop surfaces should use `codexPanel(...)` and `codexRow(...)`
  before adding view-local backgrounds, borders, shadows, or corner radii.

## Rules

- Keep card and row corners at 8px or less.
- Keep root surfaces high-contrast and system-adaptive. Avoid fixed white,
  fixed black, and heavy gray fills.
- Use one accent color for neutral emphasis. Reserve green, amber, orange, and
  red for actual availability or urgency state.
- Do not add decorative gradients or extra background art to routine product
  UI. The checked-in app icon and header artwork are enough.
- Preserve the menu row grid: fixed icon column, flexible content column,
  compact metric column, and wider date/detail column when needed.
- Keep the menu bar title decision-oriented: weekly mode shows the next reset
  weekday, and 5h mode shows the next reset time.
- Menu rows should fit without horizontal clipping. If text gets tight, shorten
  copy before shrinking fonts.
- Reset expiry rows should always label the reset number and show weekday,
  date, and time.
- The menu dropdown and desktop window should share the same visual language.
  If a style changes in one, check the other before shipping.

## Visual QA

Before releasing a visual change:

```bash
swift test --scratch-path /tmp/codex-reset-watcher-test --jobs 1
CONFIGURATION=release ./script/package.sh
CONFIGURATION=release ./script/build_and_run.sh --verify
```

Then open the real macOS menu bar dropdown and check:

- both usage rows are visible without truncating the important reset timing
- reset rows fit without scrolling when one or two resets are banked
- the active segmented control is readable
- the nudge detail does not crowd the percentage/date columns
- light and dark system appearances still have enough contrast
