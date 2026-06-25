# Privacy

Codex Reset Watcher is read-only.

The app reads your existing Codex Desktop login from:

```text
~/.codex/auth.json
```

It uses that login to call:

```text
https://chatgpt.com/backend-api/wham/usage
https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

The app does not:

- ask for an OpenAI API key
- redeem or modify reset credits
- reset usage
- send data to third-party services
- include analytics
- copy or store your token outside the running app process

The app displays the active account label when Codex exposes one, plus plan type, rate-limit window percentages, reset timing, and reset-credit expiry data returned by Codex. That data stays in the running app process and is not written to disk by Codex Reset Watcher.

Future multi-account snapshot support would change this privacy surface and must update this policy before release.

If an endpoint or Codex auth format changes, the app may stop working or show partial data.
