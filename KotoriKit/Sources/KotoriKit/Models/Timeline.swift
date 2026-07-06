import Foundation

/// One rendered row of a timeline.
public enum TimelineItem: Sendable, Identifiable {
    case tweet(Tweet)
    /// A connected thread module (self-thread or conversation preview).
    case conversation([Tweet])
    /// Deleted, withheld, or age-gated entry with X's explainer text.
    case tombstone(id: String, text: String)

    public var id: String {
        switch self {
        case .tweet(let t): "tweet-\(t.id)"
        case .conversation(let ts): "conv-\(ts.first?.id ?? "empty")"
        case .tombstone(let id, _): "tombstone-\(id)"
        }
    }
}

/// One page of a timeline plus where to go next.
public struct TimelinePage: Sendable {
    public var items: [TimelineItem]
    public var topCursor: String?
    public var bottomCursor: String?
    /// Which plane actually served this page.
    public var servedBy: Plane

    public init(items: [TimelineItem], topCursor: String? = nil, bottomCursor: String? = nil, servedBy: Plane = .anonymous) {
        self.items = items
        self.topCursor = topCursor
        self.bottomCursor = bottomCursor
        self.servedBy = servedBy
    }

    public var tweets: [Tweet] {
        items.flatMap { item -> [Tweet] in
            switch item {
            case .tweet(let t): [t]
            case .conversation(let ts): ts
            case .tombstone: []
            }
        }
    }
}
