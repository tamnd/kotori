import SwiftUI

struct SearchScreen: View {
    @State private var query = ""

    var body: some View {
        PlaceholderScreen(
            title: "Search",
            detail: "Typeahead, results, and trends arrive with M6.",
            symbol: "magnifyingglass"
        )
        .searchable(text: $query, prompt: "Search")
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SearchScreen() }
}
