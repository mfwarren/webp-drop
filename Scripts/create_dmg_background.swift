import AppKit

guard CommandLine.arguments.count == 4,
      let width = Double(CommandLine.arguments[2]),
      let height = Double(CommandLine.arguments[3]) else {
    fputs("Usage: create_dmg_background.swift output.png width height\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: width, height: height)
let image = NSImage(size: size)

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
bounds.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.95, green: 0.98, blue: 1.0, alpha: 1.0),
    NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.95, alpha: 1.0)
])
gradient?.draw(in: bounds, angle: 315)

let title = "Drag WebP Drop to Applications"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.14, alpha: 1.0)
]
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(
    at: NSPoint(x: (width - titleSize.width) / 2, y: 308),
    withAttributes: titleAttributes
)

let subtitle = "If macOS blocks first launch, right-click the app and choose Open."
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.44, alpha: 1.0)
]
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
subtitle.draw(
    at: NSPoint(x: (width - subtitleSize.width) / 2, y: 282),
    withAttributes: subtitleAttributes
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 258, y: 190))
arrowPath.curve(
    to: NSPoint(x: 382, y: 190),
    controlPoint1: NSPoint(x: 300, y: 214),
    controlPoint2: NSPoint(x: 340, y: 214)
)
NSColor.systemBlue.withAlphaComponent(0.72).setStroke()
arrowPath.lineWidth = 4
arrowPath.lineCapStyle = .round
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 382, y: 190))
arrowHead.line(to: NSPoint(x: 366, y: 202))
arrowHead.move(to: NSPoint(x: 382, y: 190))
arrowHead.line(to: NSPoint(x: 366, y: 178))
arrowHead.lineWidth = 4
arrowHead.lineCapStyle = .round
arrowHead.stroke()

let footer = "Drop images. Get WebP files side-by-side."
let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 1.0)
]
let footerSize = footer.size(withAttributes: footerAttributes)
footer.draw(
    at: NSPoint(x: (width - footerSize.width) / 2, y: 34),
    withAttributes: footerAttributes
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render background image\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
