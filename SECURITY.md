# Security Policy

## Supported Versions

This is a small unofficial utility. Only the latest commit on `main` is supported.

## Reporting A Vulnerability

Please open a private GitHub security advisory if available, or contact the repository owner.

Do not paste Codex auth tokens, `~/.codex/auth.json`, screenshots containing secrets, or bearer tokens into public issues.

## Security Notes

Codex Reset Watcher:

- reads the local Codex Desktop auth file at `~/.codex/auth.json`
- sends the saved Codex bearer token only to:
  - `https://chatgpt.com/backend-api/wham/usage`
  - `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`
- sends the active account id in the `ChatGPT-Account-Id` header to those same endpoints when Codex auth exposes it
- does not redeem resets
- does not write to the auth file
- does not store tokens elsewhere
- does not include analytics or telemetry

The endpoint is internal and may change without notice.
