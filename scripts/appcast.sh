#!/usr/bin/env bash
#
# Signs dist/Apace.dmg with the Sparkle EdDSA private key and writes dist/appcast.xml.
# Run after scripts/package.sh + scripts/notarize.sh, with the private key in the env:
#
#   export SPARKLE_PRIVATE_KEY="<base64 private key from generate_keys>"
#   scripts/appcast.sh v0.1.0
#
# The private key is read from the environment only — never written to a tracked file.

set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?pass the release tag, e.g. v0.1.0}"
: "${SPARKLE_PRIVATE_KEY:?set SPARKLE_PRIVATE_KEY to the Sparkle EdDSA private key}"
REPO="Lyons800/apace-mac"

[ -f dist/Apace.dmg ] || { echo "error: dist/Apace.dmg not found — run scripts/package.sh first"; exit 1; }

echo "==> Fetching Sparkle tools"
TOOLS_URL="$(curl -fsSL https://api.github.com/repos/sparkle-project/Sparkle/releases/latest \
  | grep browser_download_url | grep '\.tar\.xz' | cut -d'"' -f4 | head -1)"
curl -fsSL -o sparkle.tar.xz "$TOOLS_URL"
mkdir -p sparkle-tools && tar -xJf sparkle.tar.xz -C sparkle-tools
rm sparkle.tar.xz
GENERATE_APPCAST="$(find sparkle-tools -name generate_appcast -type f | head -1)"

echo "==> Signing the DMG and building the appcast"
KEYFILE="$(mktemp)"
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEYFILE"
trap 'rm -f "$KEYFILE"' EXIT

"$GENERATE_APPCAST" \
  --ed-key-file "$KEYFILE" \
  --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
  dist/

rm -rf sparkle-tools
echo "==> Wrote dist/appcast.xml"
