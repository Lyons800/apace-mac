#!/usr/bin/env bash
#
# Builds a Release, Developer ID-signed, hardened-runtime Apace.app and wraps it in a
# DMG. This is the pre-notarization step — run scripts/notarize.sh afterwards.
#
# Usage: scripts/package.sh
# Output: dist/Apace.app and dist/Apace.dmg

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${DEVELOPMENT_TEAM:-BWD692VD35}"
IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"
DERIVED="$(mktemp -d)"
DIST="dist"

echo "==> Generating project"
xcodegen generate

echo "==> Building Release (Developer ID, hardened runtime)"
xcodebuild -project Apace.xcodeproj -scheme Apace -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  ENABLE_HARDENED_RUNTIME=YES \
  build

APP="$DERIVED/Build/Products/Release/Apace.app"
[ -d "$APP" ] || { echo "error: build did not produce $APP"; exit 1; }

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer ID|flags.*runtime" \
  || { echo "error: not Developer ID signed with hardened runtime"; exit 1; }

echo "==> Assembling DMG"
rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$APP" "$DIST/"
hdiutil create -volname "Apace" -srcfolder "$DIST/Apace.app" \
  -ov -format UDZO "$DIST/Apace.dmg"

echo "==> Done: $DIST/Apace.dmg"
