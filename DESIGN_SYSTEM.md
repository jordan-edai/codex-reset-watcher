# Design System

Codex Reset Watcher should feel like a compact macOS developer utility:
quiet, readable, and useful at a glance. The reset credits and expiry dates are
the visual priority.

## Source Of Truth

- Colors live in `Sources/CodexResetWatcher/Support/CodexPalette.swift`.
- Appearance mode storage lives in
  `Sources/CodexResetWatcher/Models/CodexAppearanceMode.swift`.
- Radius, spacing, size, typography, and shared view modifiers live in
  `Sources/CodexResetWatcher/Support/CodexStyle.swift`.
- Semantic state tones live in
  `Sources/CodexResetWatcher/Support/CodexTone.swift`.
- Reusable visual primitives live in
  `Sources/CodexResetWatcher/Views/CodexDesignComponents.swift`.
- Menu and desktop surfaces should use `codexPanel(...)` and `codexRow(...)`
  before adding view-local backgrounds, borders, shadows, or corner radii.

## Rules

- Keep card and row corners at 8px or less.
- Keep root surfaces high-contrast and adaptive to Light, Dark, and Auto modes.
  Custom palette colors must work when `NSApp.appearance` is forced as well as
  when macOS follows the system appearance.
- Keep normal light mode warm and quiet: app background `#f5f4f2`, white cards,
  black text, and hairline borders. Keep dark mode dark gray, not pure black.
- Keep routine rows and cards light. Do not use smoky gray or dark tinted fills
  for normal, selected, or informational rows.
- Use one accent color for neutral emphasis. Reserve green, amber, orange, and
  red for actual availability or urgency state.
- Usage capacity bars use remaining percentage thresholds from the 2026 refresh:
  green at 60% or higher, amber from 25% through 59%, and red below 25%.
  Blocked usage windows override the percentage and render danger styling.
- Let icons, borders, badges, and meters carry state. Use colored row fills only
  for real warning or danger states.
- Do not add decorative gradients or extra background art to routine product
  UI. The checked-in app icon and header artwork are enough.
- Use the small checked-in header artwork as the app identity mark. Do not
  replace it with a dark terminal block or oversized banner.
- Preserve the menu row grid: fixed icon column, flexible content column,
  compact metric column, and wider date/detail column when needed.
- Keep the menu width roomy enough for fixed columns, reset dates, and the
  Light/Dark/Auto control. Do not shrink the menu to solve whitespace concerns
  until the real dropdown has been checked for clipping.
- The menu dropdown may be tall enough to breathe. Do not compress every row to
  keep all possible content above the fold; if the real popover feels jammed,
  prefer a wider menu and comfortable row heights before shrinking type.
- Preserve count honesty: when a server count is higher than decoded display
  rows, render a calm unavailable/missing row instead of making the count and
  visible rows disagree.
- Preserve state honesty: loading, partial, signed-out, failed, and cached
  records need distinct copy and tone. Do not render an unknown count as `0` or
  a cached number as a current live limit.
- Keep the desktop multi-account sidebar native and lightweight: one icon, one
  account label line, and one cached/active/stale detail line. Put dense metrics
  in the detail pane, not the sidebar.
- Keep the menu bar title decision-oriented: weekly mode shows the next reset
  weekday, and 5h mode shows the next reset time.
- Menu rows should fit without horizontal clipping. If text gets tight, shorten
  copy before shrinking fonts.
- Prefer `LimitMeterView` for every usage/capacity bar so color thresholds,
  clamping, and accessibility labels stay consistent.
- Desktop reset rows must keep label/detail text and expiry dates in separate
  columns. Do not put the label and large expiry date in one flexible inline
  text row; it will overlap in the default utility-window width.
- The default desktop window should show active usage, reset expiries, the nudge,
  and footer controls without requiring a first-glance scroll for ordinary
  accounts with one to three banked resets.
- The desktop window default and minimum sizes should stay large enough for that
  ordinary one-to-three-reset state. If macOS restores an older undersized
  frame, the main window should expand to the design-system minimum instead of
  clipping the footer or nudge card.
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
- cached account rows truncate long labels cleanly and never change the menu bar
  title away from the active account
- light and dark system appearances still have enough contrast
- loading, partial endpoint failure, missing auth, blocked limits, and cached or
  stale snapshots remain understandable without relying on color alone
