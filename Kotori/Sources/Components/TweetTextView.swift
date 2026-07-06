import SwiftUI
import KotoriKit

/// Tweet body text with entity spans styled and tappable.
/// Spans become kotori:// (mentions, tags) or web links; taps flow through
/// the OpenURLAction installed by RootView, which routes them to the Router.
struct TweetTextView: View {
    var text: String
    var entities: [TextEntity]
    var font: Font = .tweetBody
    var lineLimit: Int? = nil

    var body: some View {
        Text(attributed)
            .font(font)
            .foregroundStyle(Color.kotoriText)
            .lineLimit(lineLimit)
            .tint(Color.kotoriAccent)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let scalars = text.unicodeScalars
        for entity in entities {
            // Entity ranges are unicode scalar offsets into the resolved text.
            guard let lower = scalars.index(scalars.startIndex, offsetBy: entity.range.lowerBound, limitedBy: scalars.endIndex),
                  let upper = scalars.index(scalars.startIndex, offsetBy: entity.range.upperBound, limitedBy: scalars.endIndex),
                  let range = Range(lower..<upper, in: result)
            else { continue }
            result[range].foregroundColor = .kotoriAccent
            result[range].link = link(for: entity)
        }
        return result
    }

    private func link(for entity: TextEntity) -> URL? {
        switch entity.kind {
        case .url:
            return URL(string: entity.target)
        case .mention:
            let handle = entity.target.hasPrefix("@") ? String(entity.target.dropFirst()) : entity.target
            return URL(string: "kotori://profile/\(handle)")
        case .hashtag, .cashtag:
            let query = entity.target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? entity.target
            return URL(string: "kotori://search/\(query)")
        }
    }
}
