#!/usr/bin/env bash
#
# Notarizes dist/Apace.dmg with Apple and staples the ticket. Run after
# scripts/package.sh. Requires an app-specific password (never commit it):
#
#   export AC_USERNAME="you@example.com"     # Apple ID
#   export AC_PASSWORD="abcd-efgh-ijkl-mnop" # app-specific password
#   export AC_TEAM="BWD692VD35"
#   scripts/notarize.sh
#
# The password is read from the environment only — it is never written to disk here.

set -euo pipefail
cd "$(dirname "$0")/.."

: "${AC_USERNAME:?set AC_USERNAME to your Apple ID}"
: "${AC_PASSWORD:?set AC_PASSWORD to an app-specific password}"
: "${AC_TEAM:=BWD692VD35}"

DMG="dist/Apace.dmg"
[ -f "$DMG" ] || { echo "error: $DMG not found — run scripts/package.sh first"; exit 1; }

echo "==> Submitting to notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG" \
  --apple-id "$AC_USERNAME" \
  --password "$AC_PASSWORD" \
  --team-id "$AC_TEAM" \
  --wait

echo "==> Stapling the ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Notarized and stapled: $DMG"
