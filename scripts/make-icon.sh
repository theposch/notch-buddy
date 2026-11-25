#!/bin/bash
# Rebuilds Resources/AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
swift scripts/make-icon.swift "$WORK/icon.png"
SET="$WORK/AppIcon.iconset"; mkdir "$SET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$WORK/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$WORK"
echo "Wrote Resources/AppIcon.icns"
