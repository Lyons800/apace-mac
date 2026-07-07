#!/usr/bin/env bash
#
# One-command release: bump the version, tag, and push. CI (release.yml) then builds,
# signs, notarizes, staples, signs the update, builds the appcast, and publishes the
# GitHub Release — no local build or secrets needed.
#
# Usage: scripts/cut-release.sh 0.1.2

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/cut-release.sh <version>   e.g. 0.1.2}"
TAG="v$VERSION"

# Bump marketing version and increment the build number (Sparkle compares build numbers).
BUILD="$(grep CURRENT_PROJECT_VERSION project.yml | grep -oE '[0-9]+' | head -1)"
NEXT_BUILD=$((BUILD + 1))
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/" project.yml

git add project.yml
git commit -m "release: bump to $VERSION"
git tag "$TAG"
git push origin HEAD "$TAG"

echo "==> Pushed $TAG (build $NEXT_BUILD). Watch the release build:"
echo "    gh run watch --workflow=release.yml"
