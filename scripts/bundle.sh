#!/bin/bash
# Builds Notch Buddy and wraps it as a Mac app.
# Usage: scripts/bundle.sh <where/Notch Buddy.app> <version> [downloads page feed]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$1"
VERSION="$2"
FEED="${3:-}"
NAME="Notch Buddy"

swift build -c release >&2
BIN="$(swift build -c release --show-bin-path)/NotchBuddy"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchBuddy"
cp Resources/clawd.html "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>local.notchbuddy</string>
  <key>CFBundleExecutable</key><string>NotchBuddy</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Clicking a session brings its Terminal tab forward.</string>
  <key>NBReleasesURL</key><string>$FEED</string>
</dict></plist>
PLIST
