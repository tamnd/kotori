import SwiftUI
import KotoriKit

/// A scrolling timeline backed by a TimelineStore: cells, separators,
/// pull to refresh, cursor pagination, loading and error states.
struct TimelineListView: View {
    var store: TimelineStore
    var onOpen: (Route) -> Void

    var body: some View {
        Group {
            switch store.phase {
            case .idle, .loading:
                loadingState
            case .failed(let error):
                ErrorState(error: error) {
                    Task { await store.refresh() }
                }
            case .loaded where store.isEmpty:
                emptyState
            case .loaded:
                list
            }
        }
        .task { await store.loadInitial() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.items.enumerated()), id: \.offset) { index, item in
                    cell(for: item)
                    Divider().overlay(Color.kotoriSeparator)
                        .onAppear {
                            if index >= store.items.count - 5 {
                                Task { await store.loadMore() }
                            }
                        }
                }
                if store.isPaginating {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
        .refreshable { await store.refresh() }
        .background(Color.kotoriBackground)
    }

    @ViewBuilder
    private func cell(for item: TimelineItem) -> some View {
        switch item {
        case .tweet(let tweet):
            TweetCell(model: TweetCellModel(tweet), onOpen: onOpen)
        case .conversation(let tweets):
            // Connected thread cells arrive with the conversation-module pass;
            // until then each member renders as a normal cell.
            ForEach(tweets) { tweet in
                TweetCell(model: TweetCellModel(tweet), onOpen: onOpen)
            }
        case .tombstone(_, let text):
            TombstoneCell(text: text)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                SkeletonCell()
                Divider().overlay(Color.kotoriSeparator)
            }
            Spacer(minLength: 0)
        }
        .background(Color.kotoriBackground)
    }

    private var emptyState: some View {
        PlaceholderScreen(
            title: "Nothing here yet",
            detail: "No posts to show right now. Pull to refresh.",
            symbol: "bird"
        )
    }
}

/// Gray-block placeholder cell shown while the first page loads.
struct SkeletonCell: View {
    @State private var pulsing = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.kotoriBackgroundSecondary)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.kotoriBackgroundSecondary)
                    .frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.kotoriBackgroundSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.kotoriBackgroundSecondary)
                    .frame(width: 220, height: 12)
            }
        }
        .padding(12)
        .opacity(pulsing ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
        .onAppear { pulsing = true }
    }
}

/// Typed error surface with a retry button; copy varies by failure.
struct ErrorState: View {
    var error: KotoriError
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Color.kotoriTextSecondary)
            Text(message)
                .font(.tweetBody)
                .foregroundStyle(Color.kotoriTextSecondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Color.kotoriAccent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kotoriBackground)
    }

    private var symbol: String {
        switch error {
        case .rateLimited: "hourglass"
        case .walled: "lock"
        case .transport: "wifi.slash"
        case .protected: "lock.fill"
        default: "exclamationmark.triangle"
        }
    }

    private var message: String {
        switch error {
        case .rateLimited(let reset):
            if let reset {
                return "Rate limited. Try again \(reset.formatted(.relative(presentation: .named)))."
            }
            return "Rate limited. Give it a minute."
        case .walled:
            return "X is blocking anonymous access right now. Signing in will fix this once accounts land."
        case .transport:
            return "Can't reach X. Check your connection."
        case .protected:
            return "This account's posts are protected."
        case .suspended:
            return "This account is suspended."
        case .notFound:
            return "Nothing found here."
        default:
            return "Something went wrong."
        }
    }
}
