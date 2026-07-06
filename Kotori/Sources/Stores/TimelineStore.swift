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

    private let client: XClient
    private let handles: [String]
    private var users: [String: User] = [:]
    private var bottomCursor: String?
    private var seenTweetIDs: Set<String> = []

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

    func refresh() async {
        phase = items.isEmpty ? .loading : .loaded
        do {
            var pages: [TimelinePage] = []
            for handle in handles {
                let user = try await resolvedUser(handle)
                pages.append(try await client.userTweets(userID: user.id))
            }
            seenTweetIDs.removeAll()
            items = merge(pages)
            bottomCursor = handles.count == 1 ? pages.first?.bottomCursor : nil
            phase = .loaded
        } catch let error as KotoriError {
            if items.isEmpty { phase = .failed(error) }
        } catch {
            if items.isEmpty { phase = .failed(.transport(underlying: error.localizedDescription)) }
        }
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

    private func resolvedUser(_ handle: String) async throws -> User {
        if let cached = users[handle] { return cached }
        let user = try await client.user(handle: handle)
        users[handle] = user
        return user
    }

    /// Interleave several accounts by date, pinned entries dropped since
    /// a merged preview has no single owner to pin for.
    private func merge(_ pages: [TimelinePage]) -> [TimelineItem] {
        guard pages.count > 1 else {
            return dedupe(pages.first?.items ?? [])
        }
        let all = pages.flatMap(\.items).filter { item in
            if case .tweet(let t) = item, t.isPinned { return false }
            return true
        }
        let sorted = all.sorted { a, b in
            (latestDate(a) ?? .distantPast) > (latestDate(b) ?? .distantPast)
        }
        return dedupe(sorted)
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
