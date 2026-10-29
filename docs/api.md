# Local quota interface

Codex Meter uses the documented Codex app-server JSON-RPC interface over private
stdio. The app makes no direct HTTP requests. Codex CLI owns its network activity.

## Lifecycle

Each poll starts `codex app-server --stdio -c analytics.enabled=false`, sends
`initialize` with client name `codex_meter`, waits for its response, and sends
`initialized`. It then calls `account/read` with `refreshToken: false` followed by
`account/rateLimits/read`. No model turn, conversation, or reset consumption is
requested. Concurrent refreshes share the current request.

The whole exchange has a 20-second deadline, a 1 MiB buffered-message limit,
cancellation checks, and child cleanup. Server stderr and RPC error messages are
not displayed or logged because they may contain account information.

## Mapping

Use `rateLimitsByLimitId.codex`, falling back to `rateLimits`. Map primary and
secondary windows by reported duration, not slot position:

| App-server field | Model |
|---|---|
| usedPercent | UsageWindow.utilization |
| windowDurationMins × 60 | UsageWindow.duration (seconds) |
| resetsAt | UTC Date from Unix seconds |

Windows up to 24 hours are session windows; longer windows are weekly. Missing
durations retain the historical primary/session and secondary/weekly fallback.
Unknown fields are ignored. A missing quota envelope is an error; null windows
inside an existing envelope represent no available windows.

`rateLimitResetCredits.availableCount` is authoritative. Display reset details
only when positive and an available credit has a valid expiry. Use the earliest
expiry. Unix seconds and ISO dates are accepted. Count-only responses are hidden
because the current presentation requires an expiry.

Poll every 60 seconds, with exponential error backoff capped at 5 minutes. The
RPC does not expose the previous HTTP Retry-After handling. Errors retain the
last successful snapshot and surface a stale/unavailable state.

Verified live with codex-cli 0.165.0 on 2026-10-29. Mapping tests cover bucket
selection, window classification, missing envelopes, and reset expiry formats.
Reference: https://learn.chatgpt.com/docs/app-server
