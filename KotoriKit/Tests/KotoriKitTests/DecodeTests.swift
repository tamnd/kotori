import Foundation
import Testing
@testable import KotoriKit

func fixture(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try Data(contentsOf: url)
}

@Suite struct UserDecodeTests {
    @Test func userByScreenName() throws {
        let envelope = try decodeEnvelope(try fixture("user_by_screen_name"), operation: "UserByScreenName")
        let user = try Mapping.user(envelope.data!.user!.result!)

        #expect(user.id == "12")
        #expect(user.handle == "jack")
        #expect(user.displayName == "jack")
        #expect(user.verification == .blue)
        #expect(user.followersCount > 1_000_000)
        #expect(user.followingCount == 3)
        #expect(user.pinnedTweetID == "1833951636005552366")
        #expect(user.website?.absoluteString == "http://primal.net/jack")
        #expect(user.isProtected == false)

        let joined = try #require(user.joinedAt)
        let year = Calendar(identifier: .gregorian).component(.year, from: joined)
        #expect(year == 2006)
    }
}

@Suite struct TweetDecodeTests {
    @Test func tweetResultByRestID() throws {
        let envelope = try decodeEnvelope(try fixture("tweet_result"), operation: "TweetResultByRestId")
        let tweet = try #require(Mapping.tweet(envelope.data!.tweetResult!.result!))

        #expect(tweet.id == "20")
        #expect(tweet.text == "just setting up my twttr")
        #expect(tweet.author.handle == "jack")
        #expect(tweet.likeCount > 300_000)
        #expect(tweet.replyCount > 10_000)
        #expect(tweet.bookmarkCount != nil)
        #expect(tweet.source == "Twitter Web Client")
        #expect(tweet.conversationID == "20")
        #expect(tweet.media.isEmpty)
    }

    @Test func syndicationTweet() throws {
        let data = try fixture("syndication_tweet")
        let wire = try JSONDecoder().decode(Syndication.SyndicationTweet.self, from: data)
        let tweet = Syndication.map(wire)

        #expect(tweet.id == "20")
        #expect(tweet.text == "just setting up my twttr")
        #expect(tweet.author.handle == "jack")
        #expect(tweet.likeCount > 100_000)
        #expect(tweet.createdAt != nil)
    }
}

@Suite struct TimelineDecodeTests {
    @Test func userTweets() throws {
        let envelope = try decodeEnvelope(try fixture("user_tweets"), operation: "UserTweets")
        let holder = envelope.data?.user?.result?.timeline ?? envelope.data?.user?.result?.timeline_v2
        let page = Mapping.timelinePage(holder)

        #expect(page.items.count > 50)

        // The pinned entry leads the page.
        if case .tweet(let first) = page.items[0] {
            #expect(first.isPinned)
        } else {
            Issue.record("first item is not a tweet")
        }

        let tweets = page.tweets
        #expect(tweets.contains { $0.id == "20" })
        #expect(tweets.allSatisfy { !$0.author.handle.isEmpty })
        #expect(tweets.allSatisfy { $0.createdAt != nil })

        // Resolved text never leaks t.co shorteners.
        #expect(tweets.allSatisfy { !$0.text.contains("https://t.co/") })

        // The capture includes media tweets and they carry dimensions.
        let withMedia = tweets.filter { !$0.media.isEmpty }
        #expect(!withMedia.isEmpty)
        #expect(withMedia.allSatisfy { $0.media.allSatisfy { m in m.previewURL != nil } })
    }
}

@Suite struct TextResolverTests {
    @Test func htmlEscapesCollapse() {
        let (text, _) = TextResolver.resolve(.init(
            fullText: "a &amp; b &lt;tag&gt; &quot;q&quot;",
            displayRange: nil,
            entities: nil,
            extendedMedia: nil
        ))
        #expect(text == "a & b <tag> \"q\"")
    }

    @Test func urlSubstitution() {
        let url = WireURLEntity(
            url: "https://t.co/abc123XYZ0",
            expanded_url: "https://example.com/page",
            display_url: "example.com/page",
            indices: [5, 28]
        )
        let (text, entities) = TextResolver.resolve(.init(
            fullText: "look https://t.co/abc123XYZ0 now",
            displayRange: nil,
            entities: WireEntities(urls: [url], user_mentions: nil, hashtags: nil, symbols: nil, media: nil),
            extendedMedia: nil
        ))
        #expect(text == "look example.com/page now")
        #expect(entities.count == 1)
        #expect(entities[0].kind == .url)
        #expect(entities[0].target == "https://example.com/page")
        let range = entities[0].range
        let scalars = Array(text.unicodeScalars)
        #expect(String(String.UnicodeScalarView(scalars[range])) == "example.com/page")
    }

    @Test func mentionAndHashtagRanges() {
        let mention = WireMentionEntity(screen_name: "jack", indices: [0, 5])
        let hashtag = WireTagEntity(text: "swift", indices: [12, 18])
        let (text, entities) = TextResolver.resolve(.init(
            fullText: "@jack ships #swift",
            displayRange: nil,
            entities: WireEntities(urls: nil, user_mentions: [mention], hashtags: [hashtag], symbols: nil, media: nil),
            extendedMedia: nil
        ))
        #expect(text == "@jack ships #swift")
        #expect(entities.count == 2)
        let scalars = Array(text.unicodeScalars)
        #expect(String(String.UnicodeScalarView(scalars[entities[0].range])) == "@jack")
        #expect(String(String.UnicodeScalarView(scalars[entities[1].range])) == "#swift")
    }

    @Test func trailingMediaLinkStripped() {
        let media = WireMediaEntity(
            id_str: "1", media_key: nil, type: "photo", url: "https://t.co/img",
            media_url_https: nil, ext_alt_text: nil, indices: [8, 24],
            original_info: nil, video_info: nil
        )
        let (text, _) = TextResolver.resolve(.init(
            fullText: "picture https://t.co/img",
            displayRange: nil,
            entities: WireEntities(urls: nil, user_mentions: nil, hashtags: nil, symbols: nil, media: [media]),
            extendedMedia: nil
        ))
        #expect(text == "picture")
    }
}

@Suite struct SyndicationTokenTests {
    @Test func tokenMatchesEmbedAlgorithm() {
        // Golden values from the embed JS: ((id / 1e15) * PI).toString(36).replace(/(0+|\.)/g, "")
        #expect(Syndication.token(for: "20").hasPrefix("6dq1a2xwd"))
        #expect(Syndication.token(for: "1833951636005552366").hasPrefix("4g1j1kejr"))
        #expect(!Syndication.token(for: "20").contains("."))
    }
}
