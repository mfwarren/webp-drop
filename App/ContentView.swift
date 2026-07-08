import SwiftUI
import UniformTypeIdentifiers
import WebPCore

struct ContentView: View {
    @State private var isTargeted = false
    @State private var statusMessage = "Drop images to convert to WebP"
    @State private var lastOutputs: [URL] = []
    @State private var showingOptions = false

    @State private var quality = 0.80
    @State private var lossless = false
    @State private var preserveMetadata = true

    private let converter = WebPConverter()
    private var isRenderingPreview: Bool {
        ProcessInfo.processInfo.environment["WEBPDROP_RENDERING_PREVIEW"] == "1"
    }

    var body: some View {
        VStack(spacing: 22) {
            HeaderView()

            let dropZone = DropZone(
                isTargeted: $isTargeted,
                message: statusMessage,
                hasOutputs: !lastOutputs.isEmpty
            )
            .frame(width: 420, height: 232)

            if isRenderingPreview {
                dropZone
            } else {
                dropZone
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                        handleDrop(providers: providers)
                    }
            }

            HStack(spacing: 10) {
                Button {
                    showingOptions = true
                } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                StatusPill(text: "Side-by-side .webp", systemImage: "square.split.2x1")
            }

            RecentOutputsView(outputs: lastOutputs)
                .frame(height: 72, alignment: .top)
                .opacity(lastOutputs.isEmpty ? 0 : 1)
        }
        .padding(.top, 34)
        .padding(.horizontal, 40)
        .padding(.bottom, 26)
        .frame(width: 520, height: 500)
        .background(WindowBackdrop())
        .containerBackground(.regularMaterial, for: .window)
        .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
            OptionsView(
                quality: $quality,
                lossless: $lossless,
                preserveMetadata: $preserveMetadata
            )
            .padding(16)
            .frame(width: 286)
        }
        .animation(.easeOut(duration: 0.25), value: lastOutputs.count)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task {
            let urls = await loadFileURLs(from: providers)
            guard !urls.isEmpty else { return }

            await MainActor.run { statusMessage = "Converting..." }

            let options = WebPConversionOptions(
                quality: quality,
                lossless: lossless,
                preserveMetadata: preserveMetadata,
                outputPolicy: .sideBySide
            )
            var outputs: [URL] = []
            var failures: [Error] = []

            for url in urls {
                do {
                    let output = try converter.convertSingle(url: url, options: options)
                    outputs.append(output)
                } catch {
                    failures.append(error)
                }
            }

            await MainActor.run {
                lastOutputs.append(contentsOf: outputs)
                if !outputs.isEmpty, failures.isEmpty {
                    statusMessage = "Converted \(outputs.count) image(s)"
                } else if !outputs.isEmpty {
                    statusMessage = "Converted \(outputs.count), failed \(failures.count)"
                } else {
                    statusMessage = failures.first?.localizedDescription ?? "No images converted"
                }
            }
        }

        return true
    }

    private func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
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

private struct HeaderView: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                Text("WebP Drop")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text("Native image conversion, built for quick Finder workflows")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

private struct DropZone: View {
    @Binding var isTargeted: Bool
    let message: String
    let hasOutputs: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isTargeted ? Color.blue.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .strokeBorder(
                    isTargeted ? Color.blue.opacity(0.72) : Color.black.opacity(0.07),
                    style: StrokeStyle(lineWidth: 1.1, dash: isTargeted ? [] : [6, 8])
                )
                .shadow(color: .black.opacity(isTargeted ? 0.11 : 0.055), radius: isTargeted ? 22 : 14, x: 0, y: 9)
                .shadow(color: .white.opacity(0.65), radius: 1, x: 0, y: 1)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isTargeted ? Color.blue.opacity(0.16) : Color.secondary.opacity(0.10))
                        .frame(width: 54, height: 54)

                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.stack")
                        .font(.system(size: 25, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isTargeted ? .blue : .secondary)
                }

                VStack(spacing: 4) {
                    Text(message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(hasOutputs ? "Drop more files any time" : "PNG, JPEG, GIF, TIFF, and other image files")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 310)

                StatusPill(text: isTargeted ? "Release to convert" : "Drag images here", systemImage: "sparkles")
                    .opacity(isTargeted ? 1 : 0.78)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isTargeted)
        .animation(.easeOut(duration: 0.2), value: message)
    }
}

private struct OptionsView: View {
    @Binding var quality: Double
    @Binding var lossless: Bool
    @Binding var preserveMetadata: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Options", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality")
                    Spacer()
                    Text("\(Int(quality * 100))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $quality, in: 0.4...1.0, step: 0.01)
            }

            Toggle("Lossless", isOn: $lossless)
            Toggle("Preserve Metadata", isOn: $preserveMetadata)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(2)
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.white.opacity(0.38), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(.black.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct RecentOutputsView: View {
    let outputs: [URL]

    var body: some View {
        VStack(spacing: 7) {
            if !outputs.isEmpty {
                Label("Recent conversions", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)

                VStack(spacing: 3) {
                    ForEach(outputs.suffix(3), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .frame(maxWidth: 360)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct WindowBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(red: 0.96, green: 0.98, blue: 1.0),
                Color(red: 0.98, green: 0.98, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.white.opacity(0.28))
        .ignoresSafeArea()
    }
}
