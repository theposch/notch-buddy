#!/bin/bash
# Build Notch Buddy, put it in ~/Applications and start it.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Notch Buddy"
APP="$HOME/Applications/$NAME.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NotchBuddy"

# Quit the copy that is already running, if any.
if pkill -x NotchBuddy 2>/dev/null; then
    while pgrep -x NotchBuddy >/dev/null; do sleep 0.2; done
    sleep 0.5
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchBuddy"
cp Resources/clawd.html "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>local.notchbuddy</string>
  <key>CFBundleExecutable</key><string>NotchBuddy</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Clicking a session brings its Terminal tab forward.</string>
</dict></plist>
EOF

# A local signature so macOS lets it run. Real signing comes with releases.
codesign --force --sign - "$APP" >/dev/null

open "$APP"
echo "Started $APP"
