import Cocoa
import UniformTypeIdentifiers
import WebPCore

final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    private let converter = WebPConverter()

    func beginRequest(with context: NSExtensionContext) {
        Task {
            let inputURLs = await collectInputURLs(from: context)
            guard !inputURLs.isEmpty else {
                context.completeRequest(returningItems: nil, completionHandler: nil)
                return
            }

            do {
                let options = WebPConversionOptions(
                    quality: 0.80,
                    lossless: false,
                    preserveMetadata: true,
                    outputPolicy: .sideBySide
                )
                _ = try converter.convert(urls: inputURLs, options: options)
                context.completeRequest(returningItems: nil, completionHandler: nil)
            } catch {
                context.cancelRequest(withError: error)
            }
        }
    }

    private func collectInputURLs(from context: NSExtensionContext) async -> [URL] {
        let items = context.inputItems.compactMap { $0 as? NSExtensionItem }
        var urls: [URL] = []

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let url = await loadFileURL(from: provider) {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
