import SwiftUI
import Observation

/// Programmatic navigation for the active tab, so tappable text spans
/// (mentions, hashtags) can push screens without a NavigationLink.
@Observable @MainActor
final class Router {
    var homePath = NavigationPath()
    var searchPath = NavigationPath()
    var notificationsPath = NavigationPath()
    var messagesPath = NavigationPath()

    enum Tab: Hashable {
        case home, search, notifications, messages
    }

    var activeTab: Tab = .home

    func push(_ route: Route) {
        switch activeTab {
        case .home: homePath.append(route)
        case .search: searchPath.append(route)
        case .notifications: notificationsPath.append(route)
        case .messages: messagesPath.append(route)
        }
    }

    /// Routes kotori:// URLs coming out of tweet text spans, plus x.com and
    /// twitter.com status links so tapped tweet URLs open in-app.
    /// Returns false for anything that should fall through to the system.
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "kotori" else { return handleStatusLink(url) }
        switch url.host() {
        case "profile":
            let handle = url.lastPathComponent
            guard !handle.isEmpty else { return false }
            push(.profile(handle: handle))
        case "search":
            guard let query = url.lastPathComponent.removingPercentEncoding, !query.isEmpty else { return false }
            push(.search(query: query))
        case "tweet":
            let id = url.lastPathComponent
            guard !id.isEmpty else { return false }
            push(.tweet(id: id))
        default:
            return false
        }
        return true
    }

    private static let statusHosts: Set<String> = [
        "x.com", "www.x.com", "mobile.x.com",
        "twitter.com", "www.twitter.com", "mobile.twitter.com",
    ]

    /// Matches /<user>/status/<id> and /i/web/status/<id>, ignoring
    /// trailing segments like /photo/1.
    private func handleStatusLink(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased(), Self.statusHosts.contains(host) else { return false }
        var parts = url.path().split(separator: "/").map(String.init)
        if parts.count >= 2, parts[0] == "i", parts[1] == "web" {
            parts.removeFirst()
        }
        guard parts.count >= 3, parts[1] == "status" else { return false }
        let id = parts[2]
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return false }
        push(.tweet(id: id))
        return true
    }
}
