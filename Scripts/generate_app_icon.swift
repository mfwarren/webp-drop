import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root
    .appendingPathComponent("WebP Drop")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

struct IconSlot {
    let size: Int
    let scale: Int

    var pixels: Int { size * scale }
    var filename: String { "AppIcon-\(size)x\(size)@\(scale)x.png" }
}

let slots = [
    IconSlot(size: 16, scale: 1),
    IconSlot(size: 16, scale: 2),
    IconSlot(size: 32, scale: 1),
    IconSlot(size: 32, scale: 2),
    IconSlot(size: 128, scale: 1),
    IconSlot(size: 128, scale: 2),
    IconSlot(size: 256, scale: 1),
    IconSlot(size: 256, scale: 2),
    IconSlot(size: 512, scale: 1),
    IconSlot(size: 512, scale: 2)
]

func drawIcon(size: Int) throws -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size) / 1024

    NSColor.clear.setFill()
    rect.fill()

    let shadowPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: 42 * scale, dy: 36 * scale),
        xRadius: 220 * scale,
        yRadius: 220 * scale
    )
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.shadowBlurRadius = 42 * scale
    shadow.set()
    NSColor.black.withAlphaComponent(0.22).setFill()
    shadowPath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let baseRect = rect.insetBy(dx: 54 * scale, dy: 54 * scale)
    let basePath = NSBezierPath(
        roundedRect: baseRect,
        xRadius: 205 * scale,
        yRadius: 205 * scale
    )
    let baseGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.46, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.76, blue: 0.72, alpha: 1)
    ])
    baseGradient?.draw(in: basePath, angle: 315)

    let highlightPath = NSBezierPath(
        roundedRect: baseRect.insetBy(dx: 20 * scale, dy: 20 * scale),
        xRadius: 184 * scale,
        yRadius: 184 * scale
    )
    NSColor.white.withAlphaComponent(0.18).setStroke()
    highlightPath.lineWidth = max(1, 5 * scale)
    highlightPath.stroke()

    let tileRect = NSRect(
        x: 174 * scale,
        y: 212 * scale,
        width: 676 * scale,
        height: 598 * scale
    )
    let tilePath = NSBezierPath(
        roundedRect: tileRect,
        xRadius: 150 * scale,
        yRadius: 150 * scale
    )
    NSColor.white.withAlphaComponent(0.92).setFill()
    tilePath.fill()

    NSColor.black.withAlphaComponent(0.08).setStroke()
    tilePath.lineWidth = max(1, 3 * scale)
    tilePath.stroke()

    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: 702 * scale, y: 810 * scale))
    foldPath.line(to: NSPoint(x: 850 * scale, y: 662 * scale))
    foldPath.line(to: NSPoint(x: 726 * scale, y: 662 * scale))
    foldPath.curve(
        to: NSPoint(x: 702 * scale, y: 686 * scale),
        controlPoint1: NSPoint(x: 712 * scale, y: 662 * scale),
        controlPoint2: NSPoint(x: 702 * scale, y: 672 * scale)
    )
    foldPath.close()
    NSColor(calibratedRed: 0.74, green: 0.88, blue: 1.0, alpha: 1).setFill()
    foldPath.fill()

    let word = "WebP"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize = 190 * scale
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
        .paragraphStyle: paragraph,
        .kern: -7 * scale
    ]
    let wordRect = NSRect(x: 150 * scale, y: 390 * scale, width: 724 * scale, height: 238 * scale)
    word.draw(in: wordRect, withAttributes: attributes)

    let capsuleRect = NSRect(x: 401 * scale, y: 312 * scale, width: 222 * scale, height: 86 * scale)
    let capsule = NSBezierPath(
        roundedRect: capsuleRect,
        xRadius: 43 * scale,
        yRadius: 43 * scale
    )
    NSColor(calibratedRed: 0.06, green: 0.55, blue: 0.92, alpha: 0.11).setFill()
    capsule.fill()

    let arrowAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 54 * scale, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.88, alpha: 1),
        .paragraphStyle: paragraph
    ]
    "↓".draw(
        in: NSRect(x: 401 * scale, y: 325 * scale, width: 222 * scale, height: 58 * scale),
        withAttributes: arrowAttributes
    )

    return image
}

for slot in slots {
    let image = try drawIcon(size: slot.pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: outputDirectory.appendingPathComponent(slot.filename))
}

let imagesJSON = slots.map { slot -> String in
    """
        {
          "filename" : "\(slot.filename)",
          "idiom" : "mac",
          "scale" : "\(slot.scale)x",
          "size" : "\(slot.size)x\(slot.size)"
        }
    """
}.joined(separator: ",\n")

let contents = """
{
  "images" : [
\(imagesJSON)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contents.write(
    to: outputDirectory.appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)
