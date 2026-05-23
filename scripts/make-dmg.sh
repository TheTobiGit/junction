#!/usr/bin/env bash
# Build a notarizable DMG from a Junction.app bundle.
#
# Usage:
#     ./scripts/make-dmg.sh <APP_BUNDLE_PATH> <OUTPUT_DMG_PATH> <VOLUME_NAME>
#
# Example:
#     ./scripts/make-dmg.sh build/Junction.app build/Junction-0.5.0.dmg "Junction 0.5.0"
#
# The DMG includes:
#   - The .app bundle
#   - A symlink to /Applications so users drag-to-install
#
# The DMG is code-signed with JUNCTION_CODESIGN_IDENTITY (or the first
# Developer ID Application identity found). It is NOT notarized here;
# the caller (CI) must run `notarytool submit` and `stapler staple` on
# the resulting .dmg separately.

set -euo pipefail

APP_PATH="${1:-}"
DMG_PATH="${2:-}"
VOLUME_NAME="${3:-Junction}"

if [[ -z "$APP_PATH" || -z "$DMG_PATH" ]]; then
    echo "usage: scripts/make-dmg.sh <APP_BUNDLE_PATH> <OUTPUT_DMG_PATH> [VOLUME_NAME]" >&2
    exit 1
fi
if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

CODE_SIGN_IDENTITY="${JUNCTION_CODESIGN_IDENTITY:-}"
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
    CODE_SIGN_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
            | head -n 1
    )"
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

if [[ -n "$CODE_SIGN_IDENTITY" && "$CODE_SIGN_IDENTITY" != "-" ]]; then
    codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"
    codesign --verify --verbose=2 "$DMG_PATH"
fi

echo "Built $DMG_PATH"
