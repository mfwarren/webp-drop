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
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 66
fi

mkdir -p "$WORK_DIR/dmg-root"
ditto "$APP_BUNDLE" "$WORK_DIR/dmg-root/$APP_NAME"
ln -s /Applications "$WORK_DIR/dmg-root/Applications"

rm -f "$OUTPUT_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$WORK_DIR/dmg-root" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

hdiutil verify "$OUTPUT_DMG"
echo "$OUTPUT_DMG"
