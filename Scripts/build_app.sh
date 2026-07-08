#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-"$ROOT_DIR/build/release"}"
APP_NAME="WebP Drop"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MODULE_DIR="$BUILD_DIR/Modules"
MACOS_VERSION="${MACOS_DEPLOYMENT_TARGET:-15.0}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="${ARCH:-arm64}"

rm -rf "$BUILD_DIR"
mkdir -p "$MODULE_DIR" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swiftc \
  -O \
  -target "$ARCH-apple-macos$MACOS_VERSION" \
  -parse-as-library \
  -emit-module \
  -emit-object \
  -module-name WebPCore \
  -emit-module-path "$MODULE_DIR/WebPCore.swiftmodule" \
  -o "$MODULE_DIR/WebPCore.o" \
  "$ROOT_DIR/Sources/WebPCore/WebPCore.swift"

swiftc \
  -O \
  -target "$ARCH-apple-macos$MACOS_VERSION" \
  -I "$MODULE_DIR" \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
  "$ROOT_DIR/App/WebPDropApp.swift" \
  "$ROOT_DIR/App/ContentView.swift" \
  "$MODULE_DIR/WebPCore.o"

cp -p "$ROOT_DIR"/Sources/WebPCore/Resources/* "$APP_BUNDLE/Contents/Resources/"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.scalarshift.webpdrop</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MACOS_VERSION</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" >&2
plutil -lint "$APP_BUNDLE/Contents/Info.plist" >&2
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >&2

echo "$APP_BUNDLE"
