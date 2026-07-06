import SwiftUI
import KotoriKit

/// Home: For You / Following. The anonymous plane can't serve a personal
/// feed, so until sign-in lands (M7) both segments show a curated preview
/// of well-known accounts with a banner saying what login unlocks.
struct HomeScreen: View {
    /// Accounts the signed-out preview merges. Swapped for the real
    /// home feed once the session plane exists.
    private static let curatedHandles = ["nasa", "tim_cook", "elonmusk"]

    private enum Feed: String, CaseIterable {
        case forYou = "For You"
        case following = "Following"
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(Router.self) private var router

    @State private var feed: Feed = .forYou
    @State private var store: TimelineStore?

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

            loginBanner

            if let store {
                TimelineListView(store: store) { route in
                    router.push(route)
                }
            }
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
        .onAppear {
            if store == nil {
                store = TimelineStore(client: env.client, handles: Self.curatedHandles)
            }
        }
    }

    private var loginBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.kotoriAccent)
            Text("Browsing without an account shows a preview. Sign in (coming soon) to unlock your real feed.")
                .font(.tweetMeta)
                .foregroundStyle(Color.kotoriTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kotoriBackgroundSecondary)
    }
}

#Preview {
    NavigationStack { HomeScreen() }
        .environment(AppEnvironment())
        .environment(Router())
}
