import SwiftUI
import AVKit
import KotoriKit

/// What the grid hands the fullscreen viewer: the tweet's media set plus
/// the tile that was tapped.
struct MediaSelection: Identifiable {
    var media: [Media]
    var index: Int
    var id: String { media[index].id }
}

/// Fullscreen media pager the way X presents it: black backdrop, swipe
/// between attachments, pinch-zoom photos, video with controls and sound,
/// drag down to dismiss.
struct MediaViewer: View {
    var selection: MediaSelection

    @Environment(\.dismiss) private var dismiss
    @State private var page: Int
    @State private var dragOffset: CGFloat = 0
    @State private var showsAlt = false

    init(selection: MediaSelection) {
        self.selection = selection
        _page = State(initialValue: selection.index)
    }

    private var current: Media { selection.media[min(page, selection.media.count - 1)] }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(backdropOpacity)

            TabView(selection: $page) {
                ForEach(Array(selection.media.enumerated()), id: \.element.id) { index, media in
                    pageView(media)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: selection.media.count > 1 ? .automatic : .never))
            .offset(y: dragOffset)
        }
        .overlay(alignment: .top) { topBar }
        .statusBarHidden()
        .simultaneousGesture(dismissDrag)
        .sheet(isPresented: $showsAlt) { altSheet }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func pageView(_ media: Media) -> some View {
        switch media.kind {
        case .photo:
            ZoomablePhotoView(url: media.previewURL)
        case .video:
            VideoPage(media: media)
        case .animatedGif:
            // Gifs loop muted, same as inline.
            if let variant = media.bestVariant {
                InlineVideoView(url: variant.url)
                    .aspectRatio(media.aspectRatio, contentMode: .fit)
            } else {
                ZoomablePhotoView(url: media.previewURL)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.5), in: Circle())
            }
            Spacer()
            if selection.media.count > 1 {
                Text("\(page + 1) of \(selection.media.count)")
                    .font(.tweetMeta)
                    .foregroundStyle(.white)
            }
            Spacer()
            if current.altText?.isEmpty == false {
                Button("ALT") {
                    showsAlt = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(.black.opacity(0.5), in: Capsule())
            }
            if let shareURL {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }
        }
        .padding(.horizontal, 12)
        .opacity(dragOffset == 0 ? 1 : 0)
    }

    private var altSheet: some View {
        ScrollView {
            Text(current.altText ?? "")
                .font(.tweetBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .presentationDetents([.medium])
    }

    private var shareURL: URL? {
        if current.kind == .photo { return current.previewURL }
        return current.bestVariant?.url
    }

    private var backdropOpacity: Double {
        1 - min(Double(abs(dragOffset)) / 600, 0.5)
    }

    /// Vertical pull fades the backdrop and dismisses past the threshold;
    /// horizontal swipes stay with the pager.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if abs(dragOffset) > 120 || abs(value.predictedEndTranslation.height) > 400 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

/// A video page with system transport controls and sound, playing on
/// arrival and paused when swiped away.
private struct VideoPage: View {
    var media: Media

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                Color.black
            }
        }
        .onAppear {
            guard player == nil, let variant = media.bestVariant else { return }
            let p = AVPlayer(url: variant.url)
            p.play()
            player = p
        }
        .onDisappear {
            player?.pause()
        }
    }
}

/// Pinch and double-tap zoom for photos, on a plain UIScrollView because
/// SwiftUI still has no native equivalent.
private struct ZoomablePhotoView: UIViewRepresentable {
    var url: URL?

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = context.coordinator

        let imageView = UIImageView(frame: scroll.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        if let url {
            context.coordinator.load(url)
        }
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        func load(_ url: URL) {
            Task {
                // Full quality here; the timeline already cached a smaller cut.
                imageView?.image = try? await ImageLoader.shared.image(for: url, maxPixel: 2400)
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            scroll.setZoomScale(scroll.zoomScale > 1 ? 1 : 2.5, animated: true)
        }
    }
}
