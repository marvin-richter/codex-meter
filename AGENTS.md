# AGENTS.md

A macOS menu bar app that displays Codex subscription usage like a battery indicator. This file lists the rules that apply to **every** code change. For deeper specifications, load the relevant doc from `docs/`.

A fork of [claude-meter](https://github.com/anthropics/claude-meter) targeting OpenAI's Codex CLI. Same battery-indicator UX, different backend.

## North star

A user installs via Homebrew, launches once, and forever after has ambient awareness of their Codex usage. The app is invisible until they need it. If a user has to *think about* this app after install, the design failed.

## Hard constraints — non-negotiable

- **macOS only, native.** SwiftUI + AppKit. No Electron, web views, Python.
- **Single signed binary.** `.dmg` distributed via Homebrew cask + GitHub Releases. No installers.
- **Zero config on first run.** Uses the installed Codex CLI app-server over private stdio. Codex CLI owns credential storage and refresh; the app does not read tokens. No login UI or settings to configure to start working. See `docs/auth.md`.
- **Hard dependency on Codex CLI.** codex-meter is a client of Codex CLI's local app-server. The CLI must be installed and the user must have run `codex login`. Token freshness is Codex CLI's job.
- **Documented local interface.** Use `account/rateLimits/read` through `codex app-server`. Unknown fields are ignored and failures show actionable errors. Do not fall back to direct token reads or internal HTTP endpoints. See `docs/api.md`.
- **No telemetry, no analytics.** The app-server child is launched with analytics explicitly disabled. Codex CLI owns its network activity; the app itself sends no HTTP requests. Treat user data accordingly.
- **Tiny footprint.** Idle RAM under 50MB. CPU under 0.1% idle. Slow polling cadence — 60s in all states. The endpoint rate-limits, so polling harder while the popover is open just trips the limiter sooner.
- **Graceful degradation.** Network/API/auth failures show a clear error state — never a crash, never a misleading number.

## Tech stack

- Swift 5.9+, SwiftUI with `MenuBarExtra` (macOS 14+)
- Codex app-server over private stdio for quota reads. **No third-party dependencies** without explicit approval. (Codex CLI owns credential storage.)
- Swift structured concurrency (`async/await`, actors) — no GCD callbacks
- Observation macros (`@Observable`) for UI state, not Combine
- `os.Logger` with subsystem `dev.codexmeter` — no `print()`
- Build via Xcode project committed to repo

Supported setup: macOS 27 and Xcode 27 or newer. The deployment target may remain lower; older releases are not tested.

## Code style

- Swift API Design Guidelines, full stop
- No force unwraps (`!`) outside test code or genuinely-impossible-nil cases (with comment explaining)
- No force casts (`as!`)
- `let` over `var` everywhere mutation isn't real
- Actors for shared mutable state, not locks
- Typed errors (`enum APIError: Error`) — no string-throwing
- Public APIs documented with `///`

## Scope discipline

This is a **battery indicator for Codex usage**. If a feature wouldn't fit on a battery icon, it doesn't belong here. Specifically out of scope, forever or until someone has a very good reason:

- Per-task burn logging or session attribution
- Coaching, advice, productivity tips, gamification
- Cost estimation for API users (different audience)
- Cloud sync, accounts, web dashboards
- Windows/Linux ports
- iOS companion
- Multi-provider support — codex-meter is Codex-only. Claude users should run claude-meter alongside.

For v1.x roadmap items (notifications, sparklines, auto-update), see `docs/backlog.md`.

## When to ask before acting

**Ask before:**
- Adding any dependency
- Changing API contract assumptions (see `docs/api.md`)
- Changing the authentication boundary (see `docs/auth.md`)
- Touching code signing or notarization
- Expanding beyond v1 scope (see `docs/backlog.md` for what's deferred)

**Don't ask before:**
- Renaming for clarity
- Refactoring within a file
- Improving error messages
- Adding tests

## Where to find what

| Working on... | Load this doc |
|---|---|
| Architecture, module layout, dependency rules | `docs/architecture.md` |
| API endpoint, response shape, error matrix | `docs/api.md` |
| Codex CLI authentication boundary | `docs/auth.md` |
| Metric calculation, projections, EWMA | `docs/metrics.md` |
| Menu bar gauge, popover, visual specs | `docs/ui.md` |
| Colors, icon, README, marketing | `docs/brand.md` |
| What's deferred to v1.x | `docs/backlog.md` |

## Reading order for a new agent

If you're touching this codebase for the first time and don't know which doc to load: start with `docs/architecture.md`. It will tell you what each other doc covers and which ones apply to your current task.
