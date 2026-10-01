#!/bin/bash
# Install the locally prepared development build. All paths are relative to
# this file, so the whole project can be moved without breaking the installer.
set -euo pipefail
PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP_PATH="$PROJECT_DIR/build/ios-testing/AlienInvasion.app"
LOG_DIR="$PROJECT_DIR/build/ios-testing/manual-install"
PHONE_NAME="${ALIEN_IPHONE_DEVICE:-${1:-}}"
if [[ -z "$PHONE_NAME" && -f "$PROJECT_DIR/build/ios-testing/device-name.txt" ]]; then
    PHONE_NAME="$(cat "$PROJECT_DIR/build/ios-testing/device-name.txt")"
fi
if [[ -z "$PHONE_NAME" ]]; then
    xcrun devicectl list devices
    read -r -p 'Enter your iPhone name from the list: ' PHONE_NAME
fi
mkdir -p "$LOG_DIR"
pause_on_error() {
    printf '\nInstallation stopped. Unlock the iPhone and connect it by USB or paired Wi-Fi.\n'
    printf 'See INSTALL-ON-IPHONE.md for profile renewal and troubleshooting.\n'
    read -r -p 'Press Return to close.' _reply || true
}
trap pause_on_error ERR
test -d "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
printf 'Installing Alien Invasion on %s...\n' "$PHONE_NAME"
xcrun devicectl device install app --device "$PHONE_NAME" "$APP_PATH" --timeout 120 --json-output "$LOG_DIR/install.json"
printf '\nInstalled. Launching...\n'
xcrun devicectl device process launch --device "$PHONE_NAME" --terminate-existing com.walgak.alieninvasion --timeout 60 --json-output "$LOG_DIR/launch.json"
printf '\nAlien Invasion is open on your iPhone.\n'
read -r -p 'Press Return to close.' _reply || true
