import SwiftUI
import KotoriKit

/// Attached media in X's 1/2/3/4 grid layouts.
/// Videos and gifs show their poster with a play glyph and duration pill;
/// the inline player arrives with the media viewer milestone.
struct MediaGridView: View {
    var media: [Media]

    private let corner: CGFloat = 12
    private let gap: CGFloat = 2

    var body: some View {
        Group {
            switch media.count {
            case 0:
                EmptyView()
            case 1:
                single(media[0])
            case 2:
                pair(media[0], media[1])
            case 3:
                triple
            default:
                quad
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .stroke(Color.kotoriSeparator, lineWidth: 0.5)
        )
    }

    private func single(_ m: Media) -> some View {
        // Tall media gets capped near square so one photo can't fill the screen.
        MediaTile(media: m)
            .aspectRatio(max(m.aspectRatio, 0.75), contentMode: .fit)
    }

    private func pair(_ a: Media, _ b: Media) -> some View {
        HStack(spacing: gap) {
            MediaTile(media: a)
            MediaTile(media: b)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var triple: some View {
        HStack(spacing: gap) {
            MediaTile(media: media[0])
            VStack(spacing: gap) {
                MediaTile(media: media[1])
                MediaTile(media: media[2])
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private var quad: some View {
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                MediaTile(media: media[0])
                MediaTile(media: media[1])
            }
            HStack(spacing: gap) {
                MediaTile(media: media[2])
                MediaTile(media: media[3])
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
