# codex-meter

A macOS menu bar app that displays Codex subscription usage.

![Codex Meter showing the menu bar gauge and popover open on a normal desktop](assets/screenshots/hero.png)

Based on [Mister-Meeseeks/codex-meter](https://github.com/Mister-Meeseeks/codex-meter), a fork of [claude-meter](https://github.com/CrocSwap/claude-meter) targeting OpenAI's Codex CLI. Same battery-indicator UX, different backend.

## Requirements

- macOS 27 or newer
- Full Xcode 27 or newer — the standalone command-line tools are not enough.
- **Codex CLI installed and signed in.** codex-meter reads the bearer token Codex CLI caches at `~/.codex/auth.json`. Codex CLI does not need to be running; it just has to have completed `codex login` at least once. After that, codex-meter polls the same `wham/usage` endpoint Codex CLI itself uses for `/status`.

If you don't have Codex CLI: <https://developers.openai.com/codex>.

## Quickstart

```sh
git clone https://github.com/marvin-richter/codex-meter.git
cd codex-meter
./build.sh
```

Before building, open Xcode once to complete its setup. If your active developer directory points to the standalone command-line tools, select Xcode:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

**First launch:** macOS may prompt for the usual unidentified-developer warning.

No Dock icon — look for the vessel icon in the menu bar (top-right of the screen). Click it for the popover; ⌘, opens the settings panel.

## Build Script

`build.sh` builds the Release configuration into `./build/`, replaces `~/Applications/CodexMeter.app`, and launches the installed copy. Incremental builds reuse `./build/`. Quit Codex Meter before rebuilding an installed version.

To update, pull the latest code and rebuild:

```sh
git pull --ff-only
./build.sh
```

## Codex Auth

There are no Keychain dialogs. Codex CLI stores its tokens in plaintext at `~/.codex/auth.json`, so codex-meter just reads the file. macOS may prompt for the usual notarization / unidentified-developer warning.

## Coexistence with claude-meter

codex-meter ships a different bundle ID and a visually distinct AppIcon so the two can coexist in the menu bar. If you use both Claude and Codex, install both — each tracks its own subscription.

## From Xcode

If you'd rather build interactively:

```sh
open CodexMeter/CodexMeter.xcodeproj
```

Then hit ⌘R.

## Tests

```sh
xcodebuild -project CodexMeter/CodexMeter.xcodeproj \
           -scheme CodexMeter \
           -destination 'platform=macOS' test
```

## Layout

- `CodexMeter/` — Xcode project and app source
- `docs/` — architecture, metrics, UI, brand, API, auth, backlog
- `assets/` — brand assets (canonical icon SVG), `fixtures/` for parser test data, `screenshots/` for README images
- `tools/render-icon.swift` — re-renders the AppIcon set from the SVG spec
- `utils/extract-codex-token.sh` — prints the cached Codex CLI bearer token (for the `probe-codex-usage-api.sh` helper)
- `utils/probe-codex-usage-api.sh` — fetches the live `wham/usage` endpoint and saves a fresh fixture
