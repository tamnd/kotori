import SwiftUI
import KotoriKit

/// A user's posts behind Route.profile. The full profile header with
/// bio, stats, and tab strip lands with M5; this gets taps somewhere real.
struct ProfileTimelineScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Router.self) private var router

    var handle: String
    @State private var store: TimelineStore?

    var body: some View {
        Group {
            if let store {
                TimelineListView(store: store) { route in
                    router.push(route)
                }
            } else {
                Color.kotoriBackground
            }
        }
        .navigationTitle("@\(handle)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if store == nil {
                store = TimelineStore(client: env.client, handles: [handle])
            }
        }
    }
}
