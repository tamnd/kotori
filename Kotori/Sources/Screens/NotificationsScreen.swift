import SwiftUI

struct NotificationsScreen: View {
    var body: some View {
        PlaceholderScreen(
            title: "Nothing yet",
            detail: "Notifications need a signed-in session and arrive with M8.",
            symbol: "bell"
        )
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { NotificationsScreen() }
}
