import SwiftUI
import KotoriKit

/// The conversation view behind Route.tweet: ancestors, the focal tweet
/// at full size, engagement rows, and the reply gate.
struct TweetDetailScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Router.self) private var router

    var id: String
    @State private var store: TweetDetailStore?

    var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                Color.kotoriBackground
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.kotoriBackground)
        .onAppear {
            if store == nil {
                store = TweetDetailStore(client: env.client, id: id)
            }
        }
        .task(id: id) {
            await store?.load()
        }
    }

    @ViewBuilder
    private func content(_ store: TweetDetailStore) -> some View {
        switch store.phase {
        case .loading:
            VStack(spacing: 0) {
                SkeletonCell()
                Spacer()
            }
        case .failed(let error):
            ErrorState(error: error) {
                Task { await store.load() }
            }
        case .loaded:
            if let focal = store.focal {
                loaded(focal: focal, ancestors: store.ancestors)
            }
        }
    }

    private func loaded(focal: Tweet, ancestors: [Tweet]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(Array(ancestors.enumerated()), id: \.element.id) { index, tweet in
                        TweetCell(
                            model: TweetCellModel(tweet),
                            thread: index == 0 ? .first : .middle,
                            onOpen: { router.push($0) }
                        )
                    }
                    FocalTweetView(tweet: focal) { route in
                        router.push(route)
                    }
                    .id("focal")
                    replyGate
                }
            }
            .onChange(of: ancestors.count) {
                // Ancestors stream in above the focal tweet; keep it in view.
                if !ancestors.isEmpty {
                    proxy.scrollTo("focal", anchor: .top)
                }
            }
        }
    }

    /// Where the reply tree will live once the session plane can fetch it.
    private var replyGate: some View {
        VStack(spacing: 10) {
            Divider().overlay(Color.kotoriSeparator)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(Color.kotoriTextSecondary)
            Text("Replies need an account")
                .font(.tweetName)
                .foregroundStyle(Color.kotoriText)
            Text("X only serves conversation threads to signed-in sessions. Sign-in arrives with a later milestone.")
                .font(.tweetMeta)
                .foregroundStyle(Color.kotoriTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }
}

/// The focal tweet, rendered large the way X does at the center of a detail
/// screen: full author row, 17pt text, absolute stamp, labeled count rows.
struct FocalTweetView: View {
    var tweet: Tweet
    var onOpen: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            authorRow
            if !tweet.text.isEmpty {
                TweetTextView(text: tweet.text, entities: tweet.entities, lang: tweet.lang, font: .focal)
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
            stampRow
            Divider().overlay(Color.kotoriSeparator)
            countsRow
            Divider().overlay(Color.kotoriSeparator)
            ActionRow(tweet: tweet, showsCounts: false)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            Button {
                onOpen(.profile(handle: tweet.author.handle))
            } label: {
                AvatarView(url: tweet.author.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(tweet.author.displayName)
                        .font(.tweetName)
                        .foregroundStyle(Color.kotoriText)
                        .lineLimit(1)
                    VerifiedBadge(verification: tweet.author.verification)
                }
                Text("@\(tweet.author.handle)")
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(.profile(handle: tweet.author.handle))
        }
    }

    private var stampRow: some View {
        HStack(spacing: 4) {
            if let createdAt = tweet.createdAt {
                Text(Format.absoluteStamp(createdAt))
            }
            if let source = tweet.source, !source.isEmpty {
                Text("· \(source)")
            }
            if let views = tweet.viewCount, views > 0 {
                Text("· ")
                Text(Format.count(views)).fontWeight(.semibold).foregroundStyle(Color.kotoriText)
                Text(" Views")
            }
        }
        .font(.tweetMeta)
        .foregroundStyle(Color.kotoriTextSecondary)
    }

    private var countsRow: some View {
        HStack(spacing: 14) {
            labeledCount(tweet.retweetCount, "Reposts")
            labeledCount(tweet.quoteCount, "Quotes")
            labeledCount(tweet.likeCount, "Likes")
            if let bookmarks = tweet.bookmarkCount {
                labeledCount(bookmarks, "Bookmarks")
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func labeledCount(_ count: Int, _ label: String) -> some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text(Format.count(count))
                    .font(.tweetName)
                    .foregroundStyle(Color.kotoriText)
                Text(label)
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
            }
        }
    }
}
