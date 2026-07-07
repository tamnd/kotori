import SwiftUI

/// The tab shell. One NavigationStack per tab so each keeps its own history;
/// the Router owns each stack's path so cells and text spans can push routes.
struct RootView: View {
    @State private var router = Router()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.activeTab) {
            Tab("Home", systemImage: "house", value: Router.Tab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: Router.Tab.search) {
                NavigationStack(path: $router.searchPath) {
                    SearchScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Notifications", systemImage: "bell", value: Router.Tab.notifications) {
                NavigationStack(path: $router.notificationsPath) {
                    NotificationsScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
            Tab("Messages", systemImage: "envelope", value: Router.Tab.messages) {
                NavigationStack(path: $router.messagesPath) {
                    MessagesScreen()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
        }
        .environment(router)
        .environment(\.openURL, OpenURLAction { url in
            router.handle(url) ? .handled : .systemAction
        })
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .tweet(let id):
            TweetDetailScreen(id: id)
        case .profile(let handle):
            ProfileTimelineScreen(handle: handle)
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
