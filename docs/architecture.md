# Architecture

Native SwiftUI/AppKit menu bar app. Data flows in one direction:

`AppServerProvider → UsagePoller → UsageStore → views`

- `AppServerProvider` is an actor implementing `UsageProvider`. It discovers the
  installed CLI, owns each short-lived stdio child, coalesces refreshes, and maps
  JSON-RPC quota results into `UsageSnapshot`. Authentication stays inside Codex.
- `UsagePoller` owns the 60-second task loop and capped exponential backoff.
  Refresh is the only out-of-band poll. Cancellation does not record an error.
- `UsageStore` is @MainActor @Observable. It holds the latest snapshot, last
  successful refresh time, and error independently so failures preserve data.
- Models are plain values: `UsageSnapshot`, `UsageWindow`, `BankedResetInfo`,
  `Projection`, and `TrackedWindow`. Classification is based on reported duration.
- `Projector` is pure calculation. Settings and launch-at-login are small
  observable main-actor types. Views never read credentials or make HTTP calls.

The menu bar label composites vessel, pacing arc, percentage, and warning dot
into an NSImage. The popover shows remaining capacity, pacing, reset details,
refresh controls, settings, and errors. Presentation is independent of transport.

No third-party dependencies, GCD callbacks, or direct token-reading backend.
App-server transport uses a nonblocking pipe and structured concurrency. Child
stderr is discarded to avoid leaking account diagnostics. The 20-second deadline
bounds server stalls. The child is released between polls to avoid idle overhead.
Transient resource use still needs profiling against the footprint goals.

## Tests and tools

Unit tests cover response mapping, window availability/classification, projection
math, store behavior, and poller cadence/backoff. `tools/probe-app-server.swift`
is a standalone feasibility/debug probe, not part of the app. Unlike the shipping
provider, it uses blocking reads and has no timeout.

Build with the committed Xcode project or `./build.sh`. Release signing and
notarization automation is not configured.

## Specifications

- auth.md: CLI authentication boundary
- api.md: RPC lifecycle, schema mapping, errors
- metrics.md: projection calculations
- ui.md: menu bar and popover
- brand.md: colors, icon, and copy
- backlog.md: deferred features
