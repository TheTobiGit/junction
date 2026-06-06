#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Warn (don't fail) when commit hooks aren't activated. release-please
# parses Conventional Commits and will reject non-conformant history.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    hooks_path="$(git config --get core.hooksPath || true)"
    if [[ "${hooks_path}" != ".githooks" ]]; then
        printf '\033[33m⚠ Commit hooks not activated.\033[0m Run: \033[1m./scripts/setup.sh\033[0m\n' >&2
    fi
fi

PREVIEW_MODE=false
REGISTER=false
INSTALL_CLI=false
CONFIG="release"

for arg in "$@"; do
    case "$arg" in
        debug|release)
            CONFIG="$arg"
            ;;
        --preview)
            PREVIEW_MODE=true
            ;;
        --register)
            REGISTER=true
            ;;
        --install-cli)
            INSTALL_CLI=true
            ;;
    esac
done

APP_NAME="Junction"
if [[ "${PREVIEW_MODE}" == "true" ]]; then
    APP_BUNDLE="build/Junction Preview.app"
    CLI_NAME="junction-preview"
else
    APP_BUNDLE="build/${APP_NAME}.app"
    CLI_NAME="junction"
fi
APP_PLIST="${APP_BUNDLE}/Contents/Info.plist"
CLI_OUT="build/${CLI_NAME}"
ENTITLEMENTS="Resources/Junction.entitlements"
CODE_SIGN_IDENTITY="${JUNCTION_CODESIGN_IDENTITY:-}"

if [[ -z "${CODE_SIGN_IDENTITY}" ]]; then
    CODE_SIGN_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
            | head -n 1
    )"
fi
if [[ -z "${CODE_SIGN_IDENTITY}" ]]; then
    CODE_SIGN_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null \
            | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
            | head -n 1
    )"
fi
if [[ -z "${CODE_SIGN_IDENTITY}" ]]; then
    CODE_SIGN_IDENTITY="-"
fi

# Distribution-grade signing (hardened runtime + entitlements + secure
# timestamp) is only required for Developer ID identities used in
# notarized public releases. Local dev keeps lightweight ad-hoc signing.
SIGN_FLAGS=(--force --sign "${CODE_SIGN_IDENTITY}")
if [[ "${CODE_SIGN_IDENTITY}" == Developer\ ID\ Application:* ]]; then
    SIGN_FLAGS+=(--options runtime --timestamp)
    if [[ -f "${ENTITLEMENTS}" ]]; then
        APP_SIGN_FLAGS=("${SIGN_FLAGS[@]}" --entitlements "${ENTITLEMENTS}")
    else
        APP_SIGN_FLAGS=("${SIGN_FLAGS[@]}")
    fi
else
    SIGN_FLAGS+=(--deep)
    APP_SIGN_FLAGS=("${SIGN_FLAGS[@]}")
fi

echo "Building Junction (${CONFIG})..."
swift build -c "${CONFIG}" --product Junction
swift build -c "${CONFIG}" --product JunctionCLI

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"
APP_EXEC_SRC="${BIN_PATH}/${APP_NAME}"
CLI_EXEC_SRC="${BIN_PATH}/JunctionCLI"

if [[ ! -f "${APP_EXEC_SRC}" ]]; then
    echo "error: app executable not found at ${APP_EXEC_SRC}" >&2
    exit 1
fi
if [[ ! -f "${CLI_EXEC_SRC}" ]]; then
    echo "error: CLI executable not found at ${CLI_EXEC_SRC}" >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

cp "${APP_EXEC_SRC}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_PLIST}"

if [[ "${PREVIEW_MODE}" == "true" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 'Junction Preview'" "${APP_PLIST}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier 'dev.gideonsarfo.JunctionPreview'" "${APP_PLIST}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName 'Junction Preview'" "${APP_PLIST}"
    url_type_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:1:CFBundleURLName" "${APP_PLIST}" 2>/dev/null || true)"
    if [[ "${url_type_name}" != "Junction" ]]; then
        echo "error: expected CFBundleURLTypes[1].CFBundleURLName to be 'Junction' before setting preview URL scheme." >&2
        exit 1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:1:CFBundleURLSchemes:0 'junction-preview'" "${APP_PLIST}"
fi

# Sparkle reads update feed settings from Info.plist. The public EdDSA key
# is intentionally injected at build/release time so the private signing key
# never has to live in the repository. Local unsigned builds may keep the
# placeholder and simply won't be able to perform real update checks.
if [[ -n "${SPARKLE_FEED_URL:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL ${SPARKLE_FEED_URL}" "${APP_PLIST}"
fi
if [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${SPARKLE_PUBLIC_ED_KEY}" "${APP_PLIST}"
elif [[ "${CODE_SIGN_IDENTITY}" == Developer\ ID\ Application:* ]]; then
    echo "error: SPARKLE_PUBLIC_ED_KEY is required for Developer ID release builds." >&2
    echo "Generate it with Sparkle's bin/generate_keys and store the private key separately for appcast signing." >&2
    exit 1
fi

SPARKLE_FRAMEWORK="$(find .build -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -type d -print -quit)"
if [[ -z "${SPARKLE_FRAMEWORK}" ]]; then
    SPARKLE_FRAMEWORK="$(find .build -path '*/Sparkle.framework' -type d -print -quit)"
fi
if [[ -z "${SPARKLE_FRAMEWORK}" ]]; then
    echo "error: Sparkle.framework not found under .build. Run swift package resolve/build first." >&2
    exit 1
fi
ditto "${SPARKLE_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"

cp "Resources/Readability.js" "${APP_BUNDLE}/Contents/Resources/Readability.js"

if [[ -f "Resources/MenuBarIcon.png" ]]; then
    cp "Resources/MenuBarIcon.png" "${APP_BUNDLE}/Contents/Resources/MenuBarIcon.png"
fi

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
else
    printf '\033[33m⚠ Resources/AppIcon.icns missing — bundle will use the generic macOS icon.\033[0m\n' >&2
fi

cat > "${APP_BUNDLE}/Contents/PkgInfo" <<EOF
APPL????
EOF

SPARKLE_IN_APP="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
if [[ "${CODE_SIGN_IDENTITY}" == Developer\ ID\ Application:* ]]; then
    # Sparkle's nested tools must be explicitly signed for hardened runtime
    # release builds; do not rely on --deep for distribution signing.
    for item in \
        "${SPARKLE_IN_APP}/Versions/B/XPCServices/Installer.xpc" \
        "${SPARKLE_IN_APP}/Versions/B/XPCServices/Downloader.xpc" \
        "${SPARKLE_IN_APP}/Versions/B/Autoupdate" \
        "${SPARKLE_IN_APP}/Versions/B/Updater.app" \
        "${SPARKLE_IN_APP}"; do
        if [[ -e "${item}" ]]; then
            codesign "${SIGN_FLAGS[@]}" "${item}"
        fi
    done
fi

codesign "${APP_SIGN_FLAGS[@]}" "${APP_BUNDLE}"

cp "${CLI_EXEC_SRC}" "${CLI_OUT}"
chmod +x "${CLI_OUT}"
codesign "${SIGN_FLAGS[@]}" "${CLI_OUT}"

echo "Built ${APP_BUNDLE}"
echo "Built ${CLI_OUT}"
echo "Signed with ${CODE_SIGN_IDENTITY}"

if [[ "${REGISTER}" == "true" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_BUNDLE}"
    echo "Registered with LaunchServices."
fi

if [[ "${INSTALL_CLI}" == "true" ]]; then
    INSTALL_DIR="/usr/local/bin"
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        sudo mkdir -p "${INSTALL_DIR}"
    fi
    sudo cp "${CLI_OUT}" "${INSTALL_DIR}/${CLI_NAME}"
    echo "Installed CLI to ${INSTALL_DIR}/${CLI_NAME}"
fi
