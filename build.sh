#!/usr/bin/env bash
# Build, install, and launch codex-meter. Used by the README quickstart; safe to re-run.
set -euo pipefail

cd "$(dirname "$0")"

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full Xcode is required. Open Xcode to complete setup, then select it with:" >&2
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
    exit 1
fi

xcodebuild -project CodexMeter/CodexMeter.xcodeproj \
           -scheme CodexMeter \
           -configuration Release \
           -derivedDataPath build \
           build

# Install to ~/Applications so Alfred (and Spotlight) can find it.
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/CodexMeter.app"
cp -R build/Build/Products/Release/CodexMeter.app "$HOME/Applications/CodexMeter.app"

open "$HOME/Applications/CodexMeter.app"
