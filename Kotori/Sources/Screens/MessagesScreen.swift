import SwiftUI

struct MessagesScreen: View {
    var body: some View {
        PlaceholderScreen(
            title: "No messages",
            detail: "Direct messages need a signed-in session and arrive with M8.",
            symbol: "envelope"
        )
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { MessagesScreen() }
}
