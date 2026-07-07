import SwiftUI
import KotoriKit

/// Everything a cell needs, computed once off the kit model.
/// Views never touch wire types and never re-derive per frame.
struct TweetCellModel: Identifiable {
    var id: String { tweet.id }
    /// The content tweet: for reposts this is the inner tweet.
    var tweet: Tweet
    /// Set when the entry was a repost; the account whose timeline this is.
    var repostedBy: User?
    var isPinned: Bool
    var stamp: String

    init(_ entry: Tweet, now: Date = Date()) {
        if let inner = entry.retweeted {
            tweet = inner.tweet
            repostedBy = entry.author
        } else {
            tweet = entry
            repostedBy = nil
        }
        isPinned = entry.isPinned
        stamp = tweet.createdAt.map { Format.relativeStamp($0, now: now) } ?? ""
    }
}

/// Where a cell sits inside a conversation module, for the thread line.
enum ThreadPosition {
    case single
    case first
    case middle
    case last

    var hasLineBelow: Bool { self == .first || self == .middle }
}

/// One timeline entry, laid out like X: avatar column, content column.
struct TweetCell: View {
    var model: TweetCellModel
    var thread: ThreadPosition = .single
    var onOpen: (Route) -> Void

    @State private var expanded = false

    private var tweet: Tweet { model.tweet }

    /// Above this the text folds behind "Show more", like X's cutoff.
    private var wantsFold: Bool {
        !expanded && (tweet.text.count > 500 || tweet.text.filter { $0 == "\n" }.count > 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            contextLine
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 3) {
                    Button {
                        onOpen(.profile(handle: tweet.author.handle))
                    } label: {
                        AvatarView(url: tweet.author.avatarURL)
                    }
                    .buttonStyle(.plain)

                    if thread.hasLineBelow {
                        // Connects this avatar to the next reply in the thread.
                        Capsule()
                            .fill(Color.kotoriSeparator)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                            .padding(.bottom, -8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    nameRow
                    replyContext
                    if !tweet.text.isEmpty {
                        TweetTextView(text: tweet.text, entities: tweet.entities, lang: tweet.lang, lineLimit: wantsFold ? 8 : nil)
                        if wantsFold {
                            Button("Show more") {
                                expanded = true
                            }
                            .font(.tweetBody)
                            .foregroundStyle(Color.kotoriAccent)
                            .buttonStyle(.plain)
                        }
                    }
                    if !tweet.media.isEmpty {
                        MediaGridView(media: tweet.media, isSensitive: tweet.isSensitive)
                    }
                    if let poll = tweet.poll {
                        PollView(poll: poll)
                    }
                    if tweet.media.isEmpty, tweet.poll == nil, let card = tweet.card {
                        CardView(card: card)
                    }
                    if let quoted = tweet.quoted {
                        QuoteBox(tweet: quoted.tweet, onOpen: onOpen)
                    }
                    ActionRow(tweet: tweet)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(.tweet(id: tweet.id))
        }
        .contextMenu { menuItems }
    }

    /// Shared by the long-press menu and the overflow button.
    @ViewBuilder
    private var menuItems: some View {
        Link(destination: statusURL) {
            Label("Open on X", systemImage: "safari")
        }
        ShareLink(item: statusURL) {
            Label("Share post", systemImage: "square.and.arrow.up")
        }
        Button {
            UIPasteboard.general.string = statusURL.absoluteString
        } label: {
            Label("Copy link", systemImage: "link")
        }
        Divider()
        // Wired to real state once accounts land (M7).
        Button {} label: {
            Label("Mute @\(tweet.author.handle)", systemImage: "speaker.slash")
        }
        .disabled(true)
    }

    private var statusURL: URL {
        URL(string: "https://x.com/\(tweet.author.handle)/status/\(tweet.id)")!
    }

    /// Repost and pinned annotations above the avatar column.
    @ViewBuilder
    private var contextLine: some View {
        if let reposter = model.repostedBy {
            annotation(symbol: "arrow.2.squarepath", text: "\(reposter.displayName) reposted")
        } else if model.isPinned {
            annotation(symbol: "pin.fill", text: "Pinned")
        }
    }

    private func annotation(symbol: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.tweetMeta)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.kotoriTextSecondary)
        .padding(.leading, 38)
        .padding(.bottom, 2)
    }

    private var nameRow: some View {
        HStack(spacing: 4) {
            Text(tweet.author.displayName)
                .font(.tweetName)
                .foregroundStyle(Color.kotoriText)
                .lineLimit(1)
                .layoutPriority(1)
            VerifiedBadge(verification: tweet.author.verification)
            Text("@\(tweet.author.handle)")
                .font(.tweetMeta)
                .foregroundStyle(Color.kotoriTextSecondary)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(Color.kotoriTextSecondary)
            Text(model.stamp)
                .font(.tweetMeta)
                .foregroundStyle(Color.kotoriTextSecondary)
                .layoutPriority(1)
            Spacer(minLength: 0)
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kotoriTextSecondary)
                    .frame(width: 30, height: 22, alignment: .trailing)
            }
            .accessibilityLabel("More")
        }
    }

    @ViewBuilder
    private var replyContext: some View {
        if let handle = tweet.inReplyToHandle {
            HStack(spacing: 0) {
                Text("Replying to ")
                    .foregroundStyle(Color.kotoriTextSecondary)
                Text("@\(handle)")
                    .foregroundStyle(Color.kotoriAccent)
                    .onTapGesture { onOpen(.profile(handle: handle)) }
            }
            .font(.tweetMeta)
        }
    }
}

/// A quoted tweet: compact bordered box, media allowed, no further nesting.
struct QuoteBox: View {
    var tweet: Tweet
    var onOpen: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                AvatarView(url: tweet.author.avatarURL, size: 18)
                Text(tweet.author.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.kotoriText)
                    .lineLimit(1)
                VerifiedBadge(verification: tweet.author.verification)
                Text("@\(tweet.author.handle)")
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
                    .lineLimit(1)
                if let createdAt = tweet.createdAt {
                    Text("· \(Format.relativeStamp(createdAt))")
                        .font(.tweetMeta)
                        .foregroundStyle(Color.kotoriTextSecondary)
                }
            }
            if !tweet.text.isEmpty {
                TweetTextView(text: tweet.text, entities: tweet.entities, lang: tweet.lang, font: .tweetMeta, lineLimit: 6)
            }
            if !tweet.media.isEmpty {
                MediaGridView(media: tweet.media, isSensitive: tweet.isSensitive)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.kotoriSeparator, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(.tweet(id: tweet.id))
        }
    }
}

/// Reply, repost, like, views, bookmark, share with abbreviated counts.
/// Write actions need the session plane (M7); until then they're inert.
struct ActionRow: View {
    var tweet: Tweet
    /// The focal detail row shows bare icons; counts live in labeled rows.
    var showsCounts: Bool = true

    var body: some View {
        HStack {
            action("bubble.left", count: tweet.replyCount)
            Spacer()
            action("arrow.2.squarepath", count: tweet.retweetCount)
            Spacer()
            action("heart", count: tweet.likeCount)
            Spacer()
            action("chart.bar.xaxis", count: tweet.viewCount ?? 0)
            Spacer()
            // Bookmark and share act once accounts land (M7).
            Image(systemName: "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(Color.kotoriTextSecondary)
                .frame(minWidth: 30, minHeight: 30)
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15))
                .foregroundStyle(Color.kotoriTextSecondary)
                .frame(minWidth: 30, minHeight: 30)
        }
        .padding(.top, 2)
        .padding(.trailing, 24)
    }

    private func action(_ symbol: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 15))
            if showsCounts, count > 0 {
                Text(Format.count(count))
                    .font(.tweetMeta)
            }
        }
        .foregroundStyle(Color.kotoriTextSecondary)
        .frame(minWidth: 44, minHeight: 32, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Placeholder cell for deleted, withheld, or unavailable entries.
struct TombstoneCell: View {
    var text: String

    var body: some View {
        Text(text.isEmpty ? "This post is unavailable." : text)
            .font(.tweetBody)
            .foregroundStyle(Color.kotoriTextSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kotoriBackgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}
