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

CONFIG="${1:-release}"
APP_NAME="Junction"
APP_BUNDLE="build/${APP_NAME}.app"
CLI_NAME="junction"
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

cp "${APP_EXEC_SRC}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "Resources/Readability.js" "${APP_BUNDLE}/Contents/Resources/Readability.js"

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
else
    printf '\033[33m⚠ Resources/AppIcon.icns missing — bundle will use the generic macOS icon.\033[0m\n' >&2
fi

cat > "${APP_BUNDLE}/Contents/PkgInfo" <<EOF
APPL????
EOF

codesign "${APP_SIGN_FLAGS[@]}" "${APP_BUNDLE}"

cp "${CLI_EXEC_SRC}" "${CLI_OUT}"
chmod +x "${CLI_OUT}"
codesign "${SIGN_FLAGS[@]}" "${CLI_OUT}"

echo "Built ${APP_BUNDLE}"
echo "Built ${CLI_OUT}"
echo "Signed with ${CODE_SIGN_IDENTITY}"

if [[ "${2:-}" == "--register" ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_BUNDLE}"
    echo "Registered with LaunchServices."
fi

if [[ "${2:-}" == "--install-cli" || "${3:-}" == "--install-cli" ]]; then
    INSTALL_DIR="/usr/local/bin"
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        sudo mkdir -p "${INSTALL_DIR}"
    fi
    sudo cp "${CLI_OUT}" "${INSTALL_DIR}/${CLI_NAME}"
    echo "Installed CLI to ${INSTALL_DIR}/${CLI_NAME}"
fi
