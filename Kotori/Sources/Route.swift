import Foundation

/// Every place the app can navigate to. Any cell can push any of these.
enum Route: Hashable {
    case tweet(id: String)
    case profile(handle: String)
    case list(id: String)
    case search(query: String)
    case settings
}
