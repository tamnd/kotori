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

    /// Routes kotori:// URLs coming out of tweet text spans.
    /// Returns false for anything that should fall through to the system.
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "kotori" else { return false }
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
}
