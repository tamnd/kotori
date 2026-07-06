import SwiftUI
import KotoriKit

@main
struct KotoriApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .tint(Color.kotoriAccent)
        }
    }
}
