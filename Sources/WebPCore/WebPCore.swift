import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct WebPConversionOptions: Sendable {
    public enum OutputPolicy: Sendable {
        case sideBySide
    }

    public var quality: Double
    public var lossless: Bool
    public var preserveMetadata: Bool
    public var outputPolicy: OutputPolicy

    public init(
        quality: Double = 0.80,
        lossless: Bool = false,
        preserveMetadata: Bool = true,
        outputPolicy: OutputPolicy = .sideBySide
    ) {
        self.quality = quality
        self.lossless = lossless
        self.preserveMetadata = preserveMetadata
        self.outputPolicy = outputPolicy
    }
}

public enum WebPConversionError: Error, CustomStringConvertible, LocalizedError {
    case unsupportedType
    case loadFailed
    case destinationFailed
    case encodeFailed

    public var description: String {
        switch self {
        case .unsupportedType:
            return "WebP encoding is not available on this system."
        case .loadFailed:
            return "Failed to load image."
        case .destinationFailed:
            return "Failed to create output destination."
        case .encodeFailed:
            return "Failed to encode WebP."
        }
    }

    public var errorDescription: String? {
        description
    }
}

public final class WebPConverter: Sendable {
    public init() {}

    public func convert(urls: [URL], options: WebPConversionOptions = .init()) throws -> [URL] {
        var outputs: [URL] = []
        outputs.reserveCapacity(urls.count)

        for url in urls {
            let output = try convertSingle(url: url, options: options)
            outputs.append(output)
        }

        return outputs
    }

    public func convertSingle(url: URL, options: WebPConversionOptions = .init()) throws -> URL {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let outputURL = try outputURLForInput(url, policy: options.outputPolicy)

        if !options.lossless, supportsNativeWebPEncoding() {
            try encodeWithImageIO(inputURL: url, outputURL: outputURL, options: options)
            return outputURL
        }

        if try encodeWithBundledCWebP(inputURL: url, outputURL: outputURL, options: options) {
            return outputURL
        }

        throw WebPConversionError.unsupportedType
    }
}

extension WebPConverter {
    static var bundledCWebPURL: URL? {
        locateBundledCWebP()
    }
}

private func supportsNativeWebPEncoding() -> Bool {
    let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    return identifiers.contains(UTType.webP.identifier)
}

private func encodeWithImageIO(
    inputURL: URL,
    outputURL: URL,
    options: WebPConversionOptions
) throws {
    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
        throw WebPConversionError.loadFailed
    }

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.webP.identifier as CFString,
        1,
        nil
    ) else {
        throw WebPConversionError.destinationFailed
    }

    var properties: [CFString: Any] = [:]
    if options.preserveMetadata,
       let sourceProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
        properties = sourceProps
    }
    properties[kCGImageDestinationLossyCompressionQuality] = options.quality

    CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)

    if !CGImageDestinationFinalize(destination) {
        throw WebPConversionError.encodeFailed
    }
}

private func encodeWithBundledCWebP(
    inputURL: URL,
    outputURL: URL,
    options: WebPConversionOptions
) throws -> Bool {
    guard let encoderURL = locateBundledCWebP() else {
        return false
    }

    let encoderInputURL = try temporaryPNGForEncoding(inputURL)
    defer {
        try? FileManager.default.removeItem(at: encoderInputURL.deletingLastPathComponent())
    }

    var arguments: [String] = []
    if options.lossless {
        arguments.append("-lossless")
    } else {
        let quality = max(0, min(100, Int(options.quality * 100)))
        arguments.append(contentsOf: ["-q", "\(quality)"])
    }

    if options.preserveMetadata {
        arguments.append(contentsOf: ["-metadata", "all"])
    }

    arguments.append(contentsOf: [
        encoderInputURL.path,
        "-o",
        outputURL.path
    ])

    let process = Process()
    process.executableURL = encoderURL
    process.arguments = arguments

    let stderr = Pipe()
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw WebPConversionError.encodeFailed
    }

    return true
}

private func temporaryPNGForEncoding(_ inputURL: URL) throws -> URL {
    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw WebPConversionError.loadFailed
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("WebPDrop-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let pngURL = directory.appendingPathComponent("input.png")
    guard let destination = CGImageDestinationCreateWithURL(
        pngURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw WebPConversionError.destinationFailed
    }

    CGImageDestinationAddImage(destination, image, nil)

    if !CGImageDestinationFinalize(destination) {
        throw WebPConversionError.encodeFailed
    }

    return pngURL
}

private func locateBundledCWebP() -> URL? {
    var candidates: [Bundle] = [.main]
#if SWIFT_PACKAGE
    candidates.append(.module)
#endif
    candidates.append(Bundle(for: WebPConverter.self))

    for bundle in candidates {
        if let url = bundle.url(forResource: "cwebp", withExtension: nil) {
            return url
        }
        if let url = bundle.url(forResource: "cwebp", withExtension: nil, subdirectory: "Resources") {
            return url
        }
    }

    return nil
}

private func outputURLForInput(_ inputURL: URL, policy: WebPConversionOptions.OutputPolicy) throws -> URL {
    let baseURL = inputURL.deletingPathExtension()
    let directory = inputURL.deletingLastPathComponent()
    let baseName = baseURL.lastPathComponent

    var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("webp")
    var counter = 2

    while FileManager.default.fileExists(atPath: candidate.path) {
        let nextName = "\(baseName) \(counter)"
        candidate = directory.appendingPathComponent(nextName).appendingPathExtension("webp")
        counter += 1
    }

    return candidate
}
