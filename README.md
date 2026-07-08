# WebP Drop

A minimal, premium-feel macOS app for converting images to WebP with drag-and-drop and a Finder Quick Action.

## Download
Builds are produced by GitHub Actions as a DMG artifact. Version tags like `v1.0.0` also publish the DMG to GitHub Releases.

To install from a DMG:
1. Download `WebP-Drop-*.dmg` from the latest release or workflow artifact.
2. Open the DMG.
3. Drag **WebP Drop.app** into **Applications**.
4. Because the app is unsigned and not notarized, macOS may block the first launch. Right-click **WebP Drop.app**, choose **Open**, then confirm.

The automated DMG currently targets Apple Silicon Macs and macOS 15 or newer.

## App identity
- App name: WebP Drop
- Publisher: Scalar Shift
- Bundle ID (suggested): `com.scalarshift.webpdrop`

## Targets
- `WebP Drop` (SwiftUI app)
- `WebP Drop Action` (Finder Action Extension)
- `WebPCore` (Swift Package in this repo)

## Finder Quick Action
The Action Extension provides the right-click Finder Quick Action. It reads selected file URLs and writes WebP files side-by-side with the originals.

## Project setup (Xcode)
1. Create a new **macOS App** in Xcode, SwiftUI lifecycle.
2. Add the package from this repo: `WebPCore`.
3. Add a new **Action Extension** target and point it at the `ActionExtension` folder.
4. Move or copy the `App/*.swift` files into the app target.
5. Move or copy `ActionExtension/ActionRequestHandler.swift` into the extension target.
6. Add `WebPCore` to both targets' dependencies.
7. Add a bundled `cwebp` binary to both targets (Copy Bundle Resources) for the fallback encoder.

## Command-line build
The current repository build uses SwiftPM for `WebPCore` and direct `swiftc` compilation for the app bundle.

```sh
swift test
APP_VERSION=1.0.0 BUILD_NUMBER=1 Scripts/build_app.sh
Scripts/create_dmg.sh "build/release/WebP Drop.app" "dist/WebP-Drop-1.0.0.dmg"
```

The GitHub Action runs the same scripts on `macos-15`.

## Defaults
- Output: side-by-side `.webp`
- Quality: 80
- Lossless: off
- Preserve metadata: on

## Notes
- The core uses ImageIO to encode WebP when supported. If unavailable, it tries to run a bundled `cwebp` encoder.
- Add `cwebp` to both the app and extension bundles so the fallback works in Finder Quick Actions.
