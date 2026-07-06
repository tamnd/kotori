import SwiftUI
import UIKit
import ImageIO

/// Image loading tuned for timeline scroll: memory cache in front of a
/// 100MB disk cache, decode downsampled to display size off the main
/// thread, and loads cancel with the cell through .task.
actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init() {
        cache.totalCostLimit = 64 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "kotori-images"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }

    func image(for url: URL, maxPixel: CGFloat) async throws -> UIImage {
        let key = url as NSURL
        if let hit = cache.object(forKey: key) {
            return hit
        }
        if let running = inFlight[url] {
            return try await running.value
        }
        let task = Task<UIImage, Error> { [session] in
            let (data, _) = try await session.data(from: url)
            guard let image = Self.downsample(data, maxPixel: maxPixel) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let image = try await task.value
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// ImageIO thumbnailing decodes straight to the target size instead of
    /// inflating the full bitmap and scaling it down.
    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Drop-in replacement for AsyncImage on timeline surfaces.
struct RemoteImage: View {
    var url: URL?
    /// Longest edge the decoded bitmap needs; 2x-ish the display points.
    var maxPixel: CGFloat = 1200

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.kotoriBackgroundSecondary
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            let loaded = try? await ImageLoader.shared.image(for: url, maxPixel: maxPixel)
            guard !Task.isCancelled, let loaded else { return }
            let hadImage = image != nil
            withAnimation(hadImage ? nil : .easeIn(duration: 0.15)) {
                image = loaded
            }
        }
    }
}
