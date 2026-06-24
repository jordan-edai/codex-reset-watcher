# Changelog

## 0.2.1 - 2026-06-24

- Updates the menu bar title to show weekly usage remaining, for example `63% | week`.
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
