# WebP Drop

A minimal, premium-feel macOS app for converting images to WebP with drag-and-drop and a Finder Quick Action.

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

## Defaults
- Output: side-by-side `.webp`
- Quality: 80
- Lossless: off
- Preserve metadata: on

## Notes
- The core uses ImageIO to encode WebP when supported. If unavailable, it tries to run a bundled `cwebp` encoder.
- Add `cwebp` to both the app and extension bundles so the fallback works in Finder Quick Actions.
