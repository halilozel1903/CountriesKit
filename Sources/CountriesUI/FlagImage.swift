import SwiftUI
import CountriesKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an image URL. ``FlagImage`` loads through the loader in the environment,
/// so you can swap in your own cache or, in previews and tests, bundled artwork.
///
/// ```swift
/// ContentView()
///     .flagImageLoader(FlagImageLoader { url in
///         try await MyImageCache.shared.data(for: url)
///     })
/// ```
public struct FlagImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared` (or from disk for file URLs), keeping recent images in
    /// memory.
    public static let urlSession = FlagImageLoader { url in
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await FlagDataCache.shared.data(for: url) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await FlagDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back doesn't hit the network again.
actor FlagDataCache {
    static let shared = FlagDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 400

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so a flag that scrolls back into view appears at once.
@MainActor
final class DecodedFlagCache {
    static let shared = DecodedFlagCache()

    private var images: [URL: DecodedFlag] = [:]
    private var order: [URL] = []
    private let limit = 400

    func image(for url: URL) -> DecodedFlag? {
        images[url]
    }

    func insert(_ image: DecodedFlag, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }
}

/// A decoded image and its aspect ratio (width / height).
struct DecodedFlag {
    let image: Image
    let aspectRatio: CGFloat

    static func decode(_ data: Data) -> DecodedFlag? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), image.size.height > 0 else { return nil }
        return DecodedFlag(image: Image(uiImage: image), aspectRatio: image.size.width / image.size.height)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data), image.size.height > 0 else { return nil }
        return DecodedFlag(image: Image(nsImage: image), aspectRatio: image.size.width / image.size.height)
        #else
        return nil
        #endif
    }
}

private struct FlagImageLoaderKey: EnvironmentKey {
    static let defaultValue: FlagImageLoader = .urlSession
}

extension EnvironmentValues {
    /// The loader ``FlagImage`` uses. Defaults to ``FlagImageLoader/urlSession``.
    public var flagImageLoader: FlagImageLoader {
        get { self[FlagImageLoaderKey.self] }
        set { self[FlagImageLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every flag below this view with `loader`.
    public func flagImageLoader(_ loader: FlagImageLoader) -> some View {
        environment(\.flagImageLoader, loader)
    }
}

/// A country's flag from its PNG, fitted into the space it is given with a hairline border and
/// rounded corners, and the flag emoji while it loads.
///
/// Flags have many shapes (Switzerland is square, Nepal is not a rectangle), so the image is
/// fitted, never cropped. Give it a frame:
///
/// ```swift
/// FlagImage(country: turkey)
///     .frame(width: 48, height: 32)
/// ```
public struct FlagImage: View {
    private let url: URL?
    private let emoji: String?
    private let label: String?
    private let cornerRadius: CGFloat

    @Environment(\.flagImageLoader) private var loader
    @State private var loaded: (url: URL, flag: DecodedFlag)?

    /// The flag of `country`.
    public init(country: Country, cornerRadius: CGFloat = 4) {
        self.init(url: country.flagURL, emoji: country.flagEmoji, label: country.flagDescription ?? "Flag of " + country.commonName, cornerRadius: cornerRadius)
    }

    /// A flag image by URL, with an emoji placeholder.
    public init(url: URL?, emoji: String? = nil, label: String? = nil, cornerRadius: CGFloat = 4) {
        self.url = url
        self.emoji = emoji
        self.label = label
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let flag = currentFlag {
                    flag.image
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(flag.aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label ?? "Flag"))
            .accessibilityAddTraits(.isImage)
            .task(id: url) {
                await load()
            }
    }

    private var placeholder: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .overlay {
                    if let emoji {
                        Text(emoji)
                            .font(.system(size: max(10, min(proxy.size.width, proxy.size.height) * 0.6)))
                    }
                }
        }
    }

    private var currentFlag: DecodedFlag? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.flag
        }
        return DecodedFlagCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedFlagCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let flag = DecodedFlag.decode(data) else { return }
        DecodedFlagCache.shared.insert(flag, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = (url, flag)
        }
    }
}
