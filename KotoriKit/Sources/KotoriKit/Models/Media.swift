import Foundation

/// One attached photo, video, or gif.
public struct Media: Sendable, Codable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Codable {
        case photo
        case video
        case animatedGif
    }

    /// One playable rendition of a video.
    public struct Variant: Sendable, Codable, Hashable {
        public var url: URL
        public var contentType: String
        public var bitrate: Int?

        public init(url: URL, contentType: String, bitrate: Int?) {
            self.url = url
            self.contentType = contentType
            self.bitrate = bitrate
        }
    }

    public var id: String
    public var kind: Kind
    /// Poster image for videos, the image itself for photos.
    public var previewURL: URL?
    public var variants: [Variant]
    public var width: Int
    public var height: Int
    public var altText: String?
    public var durationMs: Int?

    public init(
        id: String,
        kind: Kind,
        previewURL: URL?,
        variants: [Variant] = [],
        width: Int = 0,
        height: Int = 0,
        altText: String? = nil,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.previewURL = previewURL
        self.variants = variants
        self.width = width
        self.height = height
        self.altText = altText
        self.durationMs = durationMs
    }

    public var aspectRatio: Double {
        guard width > 0, height > 0 else { return 16.0 / 9.0 }
        return Double(width) / Double(height)
    }

    /// Highest-bitrate mp4, the variant worth playing.
    public var bestVariant: Variant? {
        variants
            .filter { $0.contentType == "video/mp4" }
            .max { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }
            ?? variants.first
    }
}
