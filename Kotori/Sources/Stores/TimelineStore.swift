import Foundation
import Observation
import KotoriKit

/// Drives one timeline list: initial load, pull refresh, cursor pagination.
@Observable @MainActor
final class TimelineStore {
    enum Phase {
        case idle
        case loading
        case loaded
        case failed(KotoriError)
    }

    private(set) var items: [TimelineItem] = []
    private(set) var phase: Phase = .idle
    private(set) var isPaginating = false
    /// Fresh posts waiting behind the "N new posts" pill after a refresh.
    private(set) var newPostsCount = 0

    private let client: XClient
    private let handles: [String]
    private var users: [String: User] = [:]
    private var bottomCursor: String?
    private var seenTweetIDs: Set<String> = []
    private var pendingRefresh: (items: [TimelineItem], seen: Set<String>, cursor: String?)?

    /// One handle renders that account's timeline; several merge by date,
    /// which is how the signed-out Home preview works until M7.
    init(client: XClient, handles: [String]) {
        self.client = client
        self.handles = handles
    }

    var isEmpty: Bool { items.isEmpty }

    func loadInitial() async {
        guard case .idle = phase else { return }
        await refresh()
    }

    /// Loads the top of the timeline. With content already on screen the
    /// result waits behind the pill instead of yanking the scroll position.
    func refresh() async {
        if items.isEmpty { phase = .loading }
        do {
            var pages: [TimelinePage] = []
            for handle in handles {
                let user = try await resolvedUser(handle)
                pages.append(try await client.userTweets(userID: user.id))
            }
            var seen = Set<String>()
            let merged = merge(pages, seen: &seen)
            let cursor = handles.count == 1 ? pages.first?.bottomCursor : nil

            if items.isEmpty {
                adopt(items: merged, seen: seen, cursor: cursor)
            } else {
                let fresh = seen.subtracting(seenTweetIDs).count
                if fresh > 0 {
                    pendingRefresh = (merged, seen, cursor)
                    newPostsCount = fresh
                } else {
                    adopt(items: merged, seen: seen, cursor: cursor)
                }
            }
            phase = .loaded
        } catch let error as KotoriError {
            if items.isEmpty { phase = .failed(error) }
        } catch {
            if items.isEmpty { phase = .failed(.transport(underlying: error.localizedDescription)) }
        }
    }

    /// The pill tap: swap in the refreshed timeline.
    func applyPendingRefresh() {
        guard let pending = pendingRefresh else { return }
        adopt(items: pending.items, seen: pending.seen, cursor: pending.cursor)
    }

    func loadMore() async {
        guard !isPaginating, let cursor = bottomCursor, let handle = handles.first, handles.count == 1 else { return }
        isPaginating = true
        defer { isPaginating = false }
        do {
            let user = try await resolvedUser(handle)
            let page = try await client.userTweets(userID: user.id, cursor: cursor)
            items += dedupe(page.items)
            bottomCursor = page.bottomCursor
        } catch {
            // Pagination failures are silent; the next scroll retries.
        }
    }

    private func adopt(items: [TimelineItem], seen: Set<String>, cursor: String?) {
        self.items = items
        seenTweetIDs = seen
        bottomCursor = cursor
        pendingRefresh = nil
        newPostsCount = 0
    }

    private func resolvedUser(_ handle: String) async throws -> User {
        if let cached = users[handle] { return cached }
        let user = try await client.user(handle: handle)
        users[handle] = user
        return user
    }

    /// Interleave several accounts by date, pinned entries dropped since
    /// a merged preview has no single owner to pin for.
    private func merge(_ pages: [TimelinePage], seen: inout Set<String>) -> [TimelineItem] {
        var candidates = pages.flatMap(\.items)
        if pages.count > 1 {
            candidates = candidates.filter { item in
                if case .tweet(let t) = item, t.isPinned { return false }
                return true
            }
            candidates.sort { a, b in
                (latestDate(a) ?? .distantPast) > (latestDate(b) ?? .distantPast)
            }
        }
        return candidates.filter { item in
            guard case .tweet(let t) = item else { return true }
            return seen.insert(t.id).inserted
        }
    }

    private func latestDate(_ item: TimelineItem) -> Date? {
        switch item {
        case .tweet(let t): t.createdAt
        case .conversation(let ts): ts.compactMap(\.createdAt).max()
        case .tombstone: nil
        }
    }

    private func dedupe(_ incoming: [TimelineItem]) -> [TimelineItem] {
        incoming.filter { item in
            guard case .tweet(let t) = item else { return true }
            return seenTweetIDs.insert(t.id).inserted
        }
    }
}
