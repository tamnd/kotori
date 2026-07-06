import SwiftUI
import KotoriKit

/// Circular avatar, gray placeholder while loading.
struct AvatarView: View {
    var url: URL?
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Color.kotoriBackgroundSecondary
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// The checkmark after a display name, colored by verification kind.
struct VerifiedBadge: View {
    var verification: User.Verification

    var body: some View {
        switch verification {
        case .none:
            EmptyView()
        case .blue:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.kotoriAccent)
                .accessibilityLabel("Verified")
        case .gold:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
                .accessibilityLabel("Verified organization")
        case .gray:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.51, green: 0.55, blue: 0.59))
                .accessibilityLabel("Government account")
        }
    }
}
