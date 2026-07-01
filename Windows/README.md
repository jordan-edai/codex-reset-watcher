# Codex Reset Watcher for Windows

Native Windows tray version of Codex Reset Watcher.

It uses the same read-only data path as the macOS app:

- reads `%USERPROFILE%\.codex\auth.json`, or `%CODEX_HOME%\auth.json` when `CODEX_HOME` is set
- calls `GET https://chatgpt.com/backend-api/wham/usage`
- calls `GET https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- stores only minimized derived snapshots under `%APPDATA%\Codex Reset Watcher`

It does not redeem reset credits, reset usage, modify your account, or send analytics.

## Requirements

- Windows 10 or newer
- Codex Desktop installed and signed in
- .NET Framework 4.8 runtime

The build script uses the Windows .NET Framework C# compiler at:

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
```

No .NET SDK is required.

## Build

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\Windows\build.ps1 -Configuration Release -Clean -Verify
```

The app is written to:

```text
dist\windows\Codex Reset Watcher Windows\CodexResetWatcher.Windows.exe
```

`-Verify` runs offline diagnostics and a short launch smoke test.

## Run

```powershell
& ".\dist\windows\Codex Reset Watcher Windows\CodexResetWatcher.Windows.exe"
```

The app starts in the system tray. Left-click the tray icon for the flyout.
Double-click or choose **Open** for the main window. Closing the main window
keeps the tray app running.

## Package

```powershell
powershell -ExecutionPolicy Bypass -File .\Windows\package.ps1 -Version 0.3.3-windows.1 -Verify
```

Outputs:

```text
dist\windows\Codex.Reset.Watcher.Windows.zip
dist\windows\Codex.Reset.Watcher.Windows.v0.3.3-windows.1.zip
```

## Diagnostics

Self-test without live network calls:

```powershell
& ".\dist\windows\Codex Reset Watcher Windows\CodexResetWatcher.Windows.exe" --self-test-output ".\dist\windows\self-test.json"
```

Live read-only endpoint check:

```powershell
& ".\dist\windows\Codex Reset Watcher Windows\CodexResetWatcher.Windows.exe" --live-check-output ".\dist\windows\live-check.json"
```
