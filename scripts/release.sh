#!/bin/bash
# Makes a release of Notch Buddy in one command:
#   scripts/release.sh 0.4
#
# It builds the app, signs it, has Apple check it, and zips it into dist/.
# These optional settings turn on the steps that need accounts:
#   SIGN_ID         your "Developer ID Application: …" certificate (Apple developer account)
#   NOTARY_PROFILE  a saved notarytool profile, so Apple checks the app (needs SIGN_ID)
#   RELEASE_REPO    owner/name of the public GitHub repository for downloads; with it, the zip is
#                   uploaded as a new release and the app's "Update available" notice reads from there
# Without them you get a zip that only opens on this Mac without warnings.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Which version? For example: scripts/release.sh 0.4}"
REPO="${RELEASE_REPO:-}"
FEED=""
[ -n "$REPO" ] && FEED="https://api.github.com/repos/$REPO/releases/latest"

APP="dist/Notch Buddy.app"
ZIP="dist/Notch-Buddy-$VERSION.zip"
mkdir -p dist
swift test >&2
scripts/bundle.sh "$APP" "$VERSION" "$FEED"

if [ -n "${SIGN_ID:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
    codesign --force --sign - "$APP"
    echo "Note: no SIGN_ID, so this copy is only signed for this Mac." >&2
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

if [ -n "${SIGN_ID:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
fi

if [ -n "$REPO" ]; then
    gh release create "v$VERSION" "$ZIP" --repo "$REPO" --title "Notch Buddy $VERSION" --generate-notes
    echo "Released v$VERSION on $REPO"
else
    echo "Built $ZIP (not uploaded: no RELEASE_REPO)"
fi
