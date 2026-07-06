import Foundation

/// A span inside resolved tweet text that the UI styles and makes tappable.
public struct TextEntity: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable {
        case url
        case mention
        case hashtag
        case cashtag
    }

    public var kind: Kind
    /// What the span shows: "example.com/page", "@jack", "#wwdc".
    public var display: String
    /// Where the span goes: the expanded URL, the handle, the tag.
    public var target: String
    /// Unicode scalar offsets into the resolved text.
    public var range: Range<Int>

    public init(kind: Kind, display: String, target: String, range: Range<Int>) {
        self.kind = kind
        self.display = display
        self.target = target
        self.range = range
    }
}

/// A poll attached to a tweet.
public struct Poll: Sendable, Codable, Hashable {
    public struct Choice: Sendable, Codable, Hashable {
        public var label: String
        public var count: Int

        public init(label: String, count: Int) {
            self.label = label
            self.count = count
        }
    }

    public var choices: [Choice]
    public var endsAt: Date?
    public var isOpen: Bool

    public init(choices: [Choice], endsAt: Date?, isOpen: Bool) {
        self.choices = choices
        self.endsAt = endsAt
        self.isOpen = isOpen
    }

    public var totalVotes: Int { choices.reduce(0) { $0 + $1.count } }
}

/// A link unfurl card.
public struct Card: Sendable, Codable, Hashable {
    public var name: String
    public var url: URL?
    public var title: String?
    public var summary: String?
    public var imageURL: URL?

    public init(name: String, url: URL?, title: String?, summary: String?, imageURL: URL?) {
        self.name = name
        self.url = url
        self.title = title
        self.summary = summary
        self.imageURL = imageURL
    }
}

/// One tweet, fully resolved: entities substituted, retweet and quote unwrapped.
public struct Tweet: Sendable, Codable, Identifiable, Hashable {
    public var id: String
    /// Display text: t.co links expanded, trailing media links stripped, HTML unescaped.
    public var text: String
    /// Styled spans inside `text`, offsets in unicode scalars.
    public var entities: [TextEntity]
    public var author: User
    public var createdAt: Date?
    public var replyCount: Int
    public var retweetCount: Int
    public var likeCount: Int
    public var quoteCount: Int
    public var bookmarkCount: Int?
    public var viewCount: Int?
    public var lang: String?
    /// Client name stripped of its anchor tag ("Twitter Web Client").
    public var source: String?
    public var conversationID: String?
    public var inReplyToID: String?
    public var inReplyToHandle: String?
    public var media: [Media]
    public var poll: Poll?
    public var card: Card?
    public var quoted: Quoted?
    /// Set when this entry was a repost; author is the reposter, content lives in `retweeted`.
    public var retweeted: Quoted?
    public var isPinned: Bool
    /// The wire's possibly_sensitive flag; media hides behind an interstitial.
    public var isSensitive: Bool

    /// Boxes the nested tweet so the type can contain itself.
    public struct Quoted: Sendable, Codable, Hashable {
        public var tweet: Tweet {
            get { storage[0] }
            set { storage = [newValue] }
        }
        private var storage: [Tweet]

        public init(_ tweet: Tweet) { storage = [tweet] }
    }

    public init(
        id: String,
        text: String,
        entities: [TextEntity] = [],
        author: User,
        createdAt: Date? = nil,
        replyCount: Int = 0,
        retweetCount: Int = 0,
        likeCount: Int = 0,
        quoteCount: Int = 0,
        bookmarkCount: Int? = nil,
        viewCount: Int? = nil,
        lang: String? = nil,
        source: String? = nil,
        conversationID: String? = nil,
        inReplyToID: String? = nil,
        inReplyToHandle: String? = nil,
        media: [Media] = [],
        poll: Poll? = nil,
        card: Card? = nil,
        quoted: Quoted? = nil,
        retweeted: Quoted? = nil,
        isPinned: Bool = false,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.text = text
        self.entities = entities
        self.author = author
        self.createdAt = createdAt
        self.replyCount = replyCount
        self.retweetCount = retweetCount
        self.likeCount = likeCount
        self.quoteCount = quoteCount
        self.bookmarkCount = bookmarkCount
        self.viewCount = viewCount
        self.lang = lang
        self.source = source
        self.conversationID = conversationID
        self.inReplyToID = inReplyToID
        self.inReplyToHandle = inReplyToHandle
        self.media = media
        self.poll = poll
        self.card = card
        self.quoted = quoted
        self.retweeted = retweeted
        self.isPinned = isPinned
        self.isSensitive = isSensitive
    }
}
