#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="${1:-release}"
APP_NAME="Junction"
APP_BUNDLE="build/${APP_NAME}.app"
CLI_NAME="junction"
CLI_OUT="build/${CLI_NAME}"

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

cat > "${APP_BUNDLE}/Contents/PkgInfo" <<EOF
APPL????
EOF

codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

cp "${CLI_EXEC_SRC}" "${CLI_OUT}"
chmod +x "${CLI_OUT}"
codesign --force --sign - "${CLI_OUT}" >/dev/null 2>&1 || true

echo "Built ${APP_BUNDLE}"
echo "Built ${CLI_OUT}"

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
