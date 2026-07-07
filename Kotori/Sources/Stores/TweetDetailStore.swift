import Foundation
import Observation
import KotoriKit

/// Loads one conversation: the focal tweet plus the ancestor chain above it.
/// Replies need TweetDetail, which the anonymous plane can't reach; the
/// screen explains that until the session plane lands (M7).
@Observable @MainActor
final class TweetDetailStore {
    enum Phase {
        case loading
        case loaded
        case failed(KotoriError)
    }

    private(set) var focal: Tweet?
    /// Root first, immediate parent last.
    private(set) var ancestors: [Tweet] = []
    private(set) var phase: Phase = .loading

    private let client: XClient
    private let id: String

    /// Ancestor fetches cost one request each, so the walk is capped.
    private static let maxAncestors = 5

    init(client: XClient, id: String) {
        self.client = client
        self.id = id
    }

    func load() async {
        guard focal == nil else { return }
        do {
            let tweet = try await client.tweet(id: id)
            focal = tweet
            phase = .loaded
            await loadAncestors(from: tweet)
        } catch let error as KotoriError {
            phase = .failed(error)
        } catch {
            phase = .failed(.transport(underlying: error.localizedDescription))
        }
    }

    private func loadAncestors(from tweet: Tweet) async {
        var chain: [Tweet] = []
        var parentID = tweet.inReplyToID
        while let id = parentID, chain.count < Self.maxAncestors {
            guard let parent = try? await client.tweet(id: id) else { break }
            chain.append(parent)
            parentID = parent.inReplyToID
        }
        ancestors = chain.reversed()
    }
}
