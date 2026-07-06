import SwiftUI

/// Home: For You / Following. Until the session plane lands (M7) the anonymous
/// plane can't serve a personal feed, so this states that instead of spinning.
struct HomeScreen: View {
    private enum Feed: String, CaseIterable {
        case forYou = "For You"
        case following = "Following"
    }

    @State private var feed: Feed = .forYou

    var body: some View {
        VStack(spacing: 0) {
            Picker("Feed", selection: $feed) {
                ForEach(Feed.allCases, id: \.self) { f in
                    Text(f.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider().overlay(Color.kotoriSeparator)

            PlaceholderScreen(
                title: "Your timeline",
                detail: "The home feed arrives with M3; signing in (M7) unlocks For You and Following.",
                symbol: "house"
            )
        }
        .background(Color.kotoriBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image(systemName: "bird.fill")
                    .foregroundStyle(Color.kotoriAccent)
                    .accessibilityLabel("kotori")
            }
            ToolbarItem(placement: .topBarLeading) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Color.kotoriTextSecondary)
                    .accessibilityLabel("Account")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HomeScreen() }
}
