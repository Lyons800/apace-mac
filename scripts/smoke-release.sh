#!/usr/bin/env bash
# Verifies the exact signed/notarized DMG and Sparkle feed that will be published.

set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:-dist/Apace.dmg}"
APPCAST="${2:-dist/appcast.xml}"
[ -f "$DMG" ] || { echo "error: $DMG not found"; exit 1; }
[ -f "$APPCAST" ] || { echo "error: $APPCAST not found"; exit 1; }

MOUNT="$(mktemp -d -t apace-release-smoke)"
cleanup() {
  hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Mounting release image"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
APP="$MOUNT/Apace.app"
[ -d "$APP" ] || { echo "error: Apace.app missing from DMG"; exit 1; }
[ -L "$MOUNT/Applications" ] || { echo "error: Applications drag target missing"; exit 1; }
[ "$(readlink "$MOUNT/Applications")" = "/Applications" ] \
  || { echo "error: Applications drag target is invalid"; exit 1; }

echo "==> Verifying signature and notarization"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
xcrun stapler validate "$DMG"

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
xmllint --noout "$APPCAST"
grep -Fq "<sparkle:shortVersionString>$SHORT_VERSION</sparkle:shortVersionString>" "$APPCAST" \
  || { echo "error: appcast short version does not match app"; exit 1; }
grep -Fq "<sparkle:version>$BUILD_VERSION</sparkle:version>" "$APPCAST" \
  || { echo "error: appcast build version does not match app"; exit 1; }
grep -Eq 'sparkle:edSignature="[^"]+"' "$APPCAST" \
  || { echo "error: appcast is missing its Sparkle signature"; exit 1; }
grep -Fq "/releases/download/v$SHORT_VERSION/Apace.dmg" "$APPCAST" \
  || { echo "error: appcast release URL does not match app version"; exit 1; }

echo "==> Release smoke check passed for Apace $SHORT_VERSION ($BUILD_VERSION)"
