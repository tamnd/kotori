import SwiftUI

/// The tab shell. One NavigationStack per tab so each keeps its own history.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Search", systemImage: "magnifyingglass") {
                NavigationStack {
                    SearchScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Notifications", systemImage: "bell") {
                NavigationStack {
                    NotificationsScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Messages", systemImage: "envelope") {
                NavigationStack {
                    MessagesScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .tweet(let id):
            PlaceholderScreen(title: "Post", detail: "Post \(id) lands with M4.")
        case .profile(let handle):
            PlaceholderScreen(title: "@\(handle)", detail: "Profiles land with M5.")
        case .list(let id):
            PlaceholderScreen(title: "List", detail: "List \(id) lands with M9.")
        case .search(let query):
            PlaceholderScreen(title: query, detail: "Search results land with M6.")
        case .settings:
            PlaceholderScreen(title: "Settings", detail: "Settings land with M9.")
        }
    }
}

/// Shared empty state for surfaces that arrive in later milestones.
struct PlaceholderScreen: View {
    var title: String
    var detail: String
    var symbol: String = "bird"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.kotoriTextSecondary)
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Color.kotoriText)
            Text(detail)
                .font(.tweetBody)
                .foregroundStyle(Color.kotoriTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kotoriBackground)
    }
}

#Preview {
    RootView().environment(AppEnvironment())
}
