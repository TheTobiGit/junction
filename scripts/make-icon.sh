#!/usr/bin/env bash
# Build Resources/AppIcon.icns from a 1024x1024 source PNG.
#
# Usage:
#     ./scripts/make-icon.sh path/to/icon.png
#
# Requires: sips, iconutil (both ship with macOS).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SRC="${1:-}"
if [[ -z "$SRC" ]]; then
    echo "usage: scripts/make-icon.sh path/to/icon.png" >&2
    exit 1
fi
if [[ ! -f "$SRC" ]]; then
    echo "error: source file not found: $SRC" >&2
    exit 1
fi

OUT="Resources/AppIcon.icns"
TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for entry in "${SIZES[@]}"; do
    size="${entry%%:*}"
    name="${entry##*:}"
    sips -z "$size" "$size" "$SRC" --out "$ICONSET/$name" >/dev/null
done

iconutil --convert icns --output "$OUT" "$ICONSET"
rm -rf "$TMP"

echo "Wrote $OUT"
