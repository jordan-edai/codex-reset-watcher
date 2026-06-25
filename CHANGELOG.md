# Changelog

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
