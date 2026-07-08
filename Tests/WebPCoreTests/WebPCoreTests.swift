import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import WebPCore

@Test func optionsDefaultQuality() {
    let options = WebPConversionOptions()
    #expect(options.quality == 0.80)
}

@Test func conversionProducesReadableWebP() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let inputURL = temporaryDirectory.appendingPathComponent("fixture.png")
    try writePNGFixture(to: inputURL, width: 16, height: 12)

    let outputURL = try WebPConverter().convertSingle(url: inputURL)

    #expect(outputURL.pathExtension == "webp")
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    #expect(try webPSignatureIsValid(at: outputURL))

    let source = try #require(CGImageSourceCreateWithURL(outputURL as CFURL, nil))
    let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    )
    #expect(properties[kCGImagePropertyPixelWidth] as? Int == 16)
    #expect(properties[kCGImagePropertyPixelHeight] as? Int == 12)
}

@Test func conversionNormalizesImageIOReadableInputForBundledEncoder() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let inputURL = temporaryDirectory.appendingPathComponent("fixture.gif")
    try writeGIFFixture(to: inputURL, width: 9, height: 7)

    let outputURL = try WebPConverter().convertSingle(url: inputURL)

    #expect(outputURL.pathExtension == "webp")
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    #expect(try webPSignatureIsValid(at: outputURL))
}

@Test func webPEncodingBackendIsAvailable() throws {
    let destinationTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    let supportsNativeWebP = destinationTypes.contains(UTType.webP.identifier)
    let bundledEncoder = WebPConverter.bundledCWebPURL

    #expect(
        supportsNativeWebP || bundledEncoder != nil,
        "WebP conversion needs ImageIO WebP encoding support or a bundled cwebp fallback."
    )

    guard let bundledEncoder else {
        return
    }

    #expect(FileManager.default.isExecutableFile(atPath: bundledEncoder.path))
    try expectBundledEncoderDependenciesAreResolvable(for: bundledEncoder)
}

@Test func conversionErrorHasUserFacingDescription() {
    #expect(WebPConversionError.loadFailed.localizedDescription == "Failed to load image.")
}

private func writePNGFixture(to url: URL, width: Int, height: Int) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ))

    context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0))
    context.fill(CGRect(x: 3, y: 2, width: 7, height: 5))

    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func writeGIFFixture(to url: URL, width: Int, height: Int) throws {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ))

    context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.gif.identifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private func webPSignatureIsValid(at url: URL) throws -> Bool {
    let data = try Data(contentsOf: url)
    guard data.count >= 12 else {
        return false
    }

    let riff = String(decoding: data[0..<4], as: UTF8.self)
    let webp = String(decoding: data[8..<12], as: UTF8.self)
    return riff == "RIFF" && webp == "WEBP"
}

private func expectBundledEncoderDependenciesAreResolvable(for encoderURL: URL) throws {
    let otoolURL = URL(fileURLWithPath: "/usr/bin/otool")
    guard FileManager.default.isExecutableFile(atPath: otoolURL.path) else {
        return
    }

    let process = Process()
    process.executableURL = otoolURL
    process.arguments = ["-L", encoderURL.path]

    let output = Pipe()
    process.standardOutput = output

    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let data = output.fileHandleForReading.readDataToEndOfFile()
    let text = String(decoding: data, as: UTF8.self)
    let dependencyPaths = text
        .split(separator: "\n")
        .dropFirst()
        .compactMap { line -> String? in
            line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ")
                .first
                .map(String.init)
        }

    for dependencyPath in dependencyPaths {
        #expect(
            dependencyIsResolvable(dependencyPath, relativeTo: encoderURL),
            "Bundled cwebp dependency is not available in the bundle: \(dependencyPath)"
        )
    }
}

private func dependencyIsResolvable(_ path: String, relativeTo encoderURL: URL) -> Bool {
    if path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/Library/") {
        return true
    }

    if path.hasPrefix("/") {
        return FileManager.default.fileExists(atPath: path)
    }

    let dependencyName = URL(fileURLWithPath: path).lastPathComponent
    let candidateDirectories = [
        encoderURL.deletingLastPathComponent(),
        encoderURL.deletingLastPathComponent().appendingPathComponent("../Frameworks"),
        encoderURL.deletingLastPathComponent().appendingPathComponent("../Libraries")
    ]

    return candidateDirectories.contains { directory in
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(dependencyName).standardized.path
        )
    }
}
