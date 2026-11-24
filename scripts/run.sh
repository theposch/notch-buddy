#!/bin/bash
# Build Notch Buddy, put it in ~/Applications and start it.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$HOME/Applications/Notch Buddy.app"

# Quit the copy that is already running, if any.
if pkill -x NotchBuddy 2>/dev/null; then
    while pgrep -x NotchBuddy >/dev/null; do sleep 0.2; done
    sleep 0.5
fi

scripts/bundle.sh "$APP" "0.0-dev"
# A local signature so macOS lets it run. Real signing happens in release.sh.
codesign --force --sign - "$APP" >/dev/null
open "$APP"
echo "Started $APP"
