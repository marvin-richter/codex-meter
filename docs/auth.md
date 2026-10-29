# Authentication

Codex Meter delegates authentication to the installed Codex CLI. It never reads,
copies, logs, or stores access tokens, refresh tokens, API keys, or auth.json.
Sign in with `codex login` using your ChatGPT account. Codex CLI owns credential
storage (including Keychain), refresh, and authenticated network requests.

Each refresh starts a private `codex app-server --stdio` child with analytics
explicitly disabled. After initialization, `account/read` checks that an account
is available. API-key-only accounts are rejected because subscription quotas
require ChatGPT authentication. No login or logout RPC is called by the meter.

The child is stopped when the request finishes, fails, times out, or is cancelled.
There is no fallback to direct credential reads or internal HTTP endpoints.
Missing CLI, sign-in, connection, and protocol errors appear in the popover.

The CLI is discovered using PATH and common Homebrew, ~/.local/bin, and
~/.cargo/bin locations. Codex must remain installed but need not already be running.

Verified with codex-cli 0.165.0 on 2026-10-29.
Reference: https://learn.chatgpt.com/docs/app-server#auth-endpoints
