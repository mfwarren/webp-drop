#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /path/to/WebP\\ Drop.app /path/to/WebP-Drop.dmg" >&2
  exit 64
fi

APP_BUNDLE="$1"
OUTPUT_DMG="$2"
APP_NAME="$(basename "$APP_BUNDLE")"
VOLUME_NAME="${VOLUME_NAME:-WebP Drop}"
WINDOW_WIDTH="${WINDOW_WIDTH:-640}"
WINDOW_HEIGHT="${WINDOW_HEIGHT:-400}"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 66
fi

mkdir -p "$WORK_DIR/dmg-root/.background"
ditto "$APP_BUNDLE" "$WORK_DIR/dmg-root/$APP_NAME"
ln -s /Applications "$WORK_DIR/dmg-root/Applications"

swift "$PWD/Scripts/create_dmg_background.swift" \
  "$WORK_DIR/dmg-root/.background/background.png" \
  "$WINDOW_WIDTH" \
  "$WINDOW_HEIGHT"

TEMP_DMG="$WORK_DIR/WebP-Drop.rw.dmg"
MOUNT_DIR="$WORK_DIR/mount"
mkdir -p "$MOUNT_DIR"

rm -f "$OUTPUT_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$WORK_DIR/dmg-root" \
  -fs HFS+ \
  -ov \
  -format UDRW \
  "$TEMP_DMG" >/dev/null

hdiutil attach "$TEMP_DMG" \
  -mountpoint "$MOUNT_DIR" \
  -readwrite \
  -quiet

chflags hidden "$MOUNT_DIR/.background" 2>/dev/null || true

set +e
osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$MOUNT_DIR" as alias
tell application "Finder"
    tell folder dmgFolder
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 120 + $WINDOW_WIDTH, 120 + $WINDOW_HEIGHT}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to POSIX file "$MOUNT_DIR/.background/background.png"
        set position of item "$APP_NAME" of container window to {175, 212}
        set position of item "Applications" of container window to {465, 212}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
finder_status=$?
set -e

if [[ $finder_status -ne 0 ]]; then
  echo "Warning: Finder DMG layout customization failed; continuing with a basic DMG." >&2
fi

sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$TEMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG" \
  -quiet

hdiutil verify "$OUTPUT_DMG"
echo "$OUTPUT_DMG"
