import SwiftUI
import KotoriKit

/// Attached media in X's 1/2/3/4 grid layouts.
/// Tapping a tile opens the fullscreen viewer on that attachment.
struct MediaGridView: View {
    var media: [Media]
    /// Hides the grid behind an interstitial until the viewer opts in.
    var isSensitive: Bool = false

    @State private var revealed = false
    @State private var viewer: MediaSelection?

    private let corner: CGFloat = 12
    private let gap: CGFloat = 2

    var body: some View {
        Group {
            switch media.count {
            case 0:
                EmptyView()
            case 1:
                single
            case 2:
                pair
            case 3:
                triple
            default:
                quad
            }
        }
        .overlay {
            if isSensitive && !revealed {
                interstitial
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .stroke(Color.kotoriSeparator, lineWidth: 0.5)
        )
        .fullScreenCover(item: $viewer) { selection in
            MediaViewer(selection: selection)
        }
    }

    /// One grid slot wired to open the viewer on its attachment.
    private func tile(_ index: Int) -> some View {
        MediaTile(media: media[index])
            .onTapGesture {
                viewer = MediaSelection(media: media, index: index)
            }
    }

    private var interstitial: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.kotoriTextSecondary)
                Text("Sensitive content")
                    .font(.tweetName)
                    .foregroundStyle(Color.kotoriText)
                Text("The author flagged this media.")
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
                Button("Show") {
                    revealed = true
                }
                .font(.tweetMeta)
                .fontWeight(.semibold)
                .buttonStyle(.bordered)
            }
            .padding(12)
        }
    }

    private var single: some View {
        // Tall media gets capped near square so one photo can't fill the screen.
        tile(0)
            .aspectRatio(max(media[0].aspectRatio, 0.75), contentMode: .fit)
    }

    private var pair: some View {
        HStack(spacing: gap) {
            tile(0)
            tile(1)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var triple: some View {
        HStack(spacing: gap) {
            tile(0)
            VStack(spacing: gap) {
                tile(1)
                tile(2)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var quad: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                tile(0)
                tile(1)
            }
            HStack(spacing: gap) {
                tile(2)
                tile(3)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }
}

/// One image slot: fills its frame, badges for alt text, video, gif.
private struct MediaTile: View {
    var media: Media

    var body: some View {
        Color.kotoriBackgroundSecondary
            .overlay {
                if media.kind != .photo, let variant = media.bestVariant {
                    InlineVideoView(url: variant.url)
                } else {
                    RemoteImage(url: media.previewURL)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 4) {
                    if media.kind == .video, let ms = media.durationMs {
                        pill(Format.duration(milliseconds: ms))
                    }
                    if media.kind == .animatedGif {
                        pill("GIF")
                    }
                    if media.altText?.isEmpty == false {
                        pill("ALT")
                    }
                }
                .padding(6)
            }
            .accessibilityLabel(media.altText ?? media.kind.rawValue)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
    }
}
