import SwiftUI
import KotoriKit

/// Link unfurl. Large image on top for summary_large_image, small thumb
/// on the left for summary, text-only fallback when there is no image.
struct CardView: View {
    var card: Card

    private var isLarge: Bool {
        card.name.contains("summary_large_image") || card.name.contains("player")
    }

    var body: some View {
        if let url = card.url {
            Link(destination: url) { layout }
                .buttonStyle(.plain)
        } else {
            layout
        }
    }

    private var layout: some View {
        Group {
            if isLarge, card.imageURL != nil {
                largeLayout
            } else {
                smallLayout
            }
        }
        .background(Color.kotoriBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.kotoriSeparator, lineWidth: 0.5)
        )
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: card.imageURL)
                .aspectRatio(1.91, contentMode: .fit)
                .clipped()
            textBlock
        }
    }

    private var smallLayout: some View {
        HStack(spacing: 0) {
            if card.imageURL != nil {
                RemoteImage(url: card.imageURL, maxPixel: 360)
                    .frame(width: 88, height: 88)
                    .clipped()
            }
            textBlock
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let host = card.url?.host() {
                Text(host)
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
            }
            if let title = card.title {
                Text(title)
                    .font(.tweetBody)
                    .foregroundStyle(Color.kotoriText)
                    .lineLimit(2)
            }
            if let summary = card.summary, !summary.isEmpty {
                Text(summary)
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
