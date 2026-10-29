# Codex app-server feasibility probe

Run `swift tools/probe-app-server.swift` with Codex CLI installed and signed in.
The probe launches a private stdio child process, initializes it as
`codex_meter_probe`, and requests `account/rateLimits/read`. It starts no
conversation or model turn. It prints only allowlisted quota fields, suppresses
server diagnostics, and terminates its child when finished. Analytics are
explicitly disabled for the child.

Verified locally on 2026-10-29 with codex-cli 0.165.0: both quota windows and
banked-reset count were returned successfully. The app now uses `AppServerProvider`, which launches a short-lived stdio child per poll, coalesces concurrent refreshes, enforces a 20-second deadline, and cleans up the child on completion or cancellation. The command-line probe
uses blocking pipe reads and has no timeout; interrupt it if the server stalls.

## Mapping into the existing presentation

- Select `rateLimitsByLimitId.codex`, falling back to `rateLimits`.
- `usedPercent` maps to `UsageWindow.utilization`.
- `windowDurationMins * 60` maps to `UsageWindow.duration`.
- `resetsAt` is Unix seconds, mapping to `UsageWindow.resetsAt`.
- Reuse `UsageSnapshot.classify` for session/weekly placement.
- Map `rateLimitResetCredits.availableCount` and the earliest available credit
  expiry into `BankedResetInfo` when detail rows exist. A count without expiry
  needs a deliberate model/UI decision; do not invent an expiry.

The shipping `AppServerProvider` returns the same `UsageSnapshot`, preserving the
current gauges, popover, settings, and projection calculations. The provider implements async polling of a nonblocking pipe, a 20-second deadline, child cleanup, common GUI CLI paths, typed errors, and mapping tests. Measure the
child's memory and startup/network activity against the tiny-footprint goals.
Do not silently fall back to direct credential reads if app-server fails.

Verified the actual provider against CLI 0.165.0: both windows and banked-reset details mapped successfully. Reset expiry accepts Unix seconds (observed live) and ISO dates. Count-only reset data remains hidden because the existing presentation requires an expiry.

The legacy HTTP backend, credential readers, and token-printing scripts have been removed.

Reference: https://learn.chatgpt.com/docs/app-server
