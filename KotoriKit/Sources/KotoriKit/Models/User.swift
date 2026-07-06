import Foundation

/// A profile, mapped from any wire shape into one clean model.
public struct User: Sendable, Codable, Identifiable, Hashable {
    /// Which checkmark, if any.
    public enum Verification: String, Sendable, Codable {
        case none
        case blue
        case gold
        case gray
    }

    public var id: String
    public var handle: String
    public var displayName: String
    public var bio: String
    public var location: String
    public var website: URL?
    public var joinedAt: Date?
    public var followersCount: Int
    public var followingCount: Int
    public var tweetCount: Int
    public var mediaCount: Int
    public var likesCount: Int
    public var avatarURL: URL?
    public var bannerURL: URL?
    public var verification: Verification
    public var isProtected: Bool
    public var pinnedTweetID: String?

    public init(
        id: String,
        handle: String,
        displayName: String,
        bio: String = "",
        location: String = "",
        website: URL? = nil,
        joinedAt: Date? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        tweetCount: Int = 0,
        mediaCount: Int = 0,
        likesCount: Int = 0,
        avatarURL: URL? = nil,
        bannerURL: URL? = nil,
        verification: Verification = .none,
        isProtected: Bool = false,
        pinnedTweetID: String? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.bio = bio
        self.location = location
        self.website = website
        self.joinedAt = joinedAt
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.tweetCount = tweetCount
        self.mediaCount = mediaCount
        self.likesCount = likesCount
        self.avatarURL = avatarURL
        self.bannerURL = bannerURL
        self.verification = verification
        self.isProtected = isProtected
        self.pinnedTweetID = pinnedTweetID
    }

    /// The avatar at original resolution instead of the _normal thumb.
    public var avatarOriginalURL: URL? {
        guard let avatarURL else { return nil }
        let s = avatarURL.absoluteString.replacingOccurrences(of: "_normal.", with: ".")
        return URL(string: s)
    }
}
