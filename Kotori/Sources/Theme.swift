import SwiftUI

// The X palette, defined in the asset catalog with light and dark variants.
extension Color {
    static let kotoriBackground = Color("BackgroundPrimary")
    static let kotoriBackgroundSecondary = Color("BackgroundSecondary")
    static let kotoriText = Color("TextPrimary")
    static let kotoriTextSecondary = Color("TextSecondary")
    static let kotoriAccent = Color("AccentBlue")
    static let kotoriLike = Color("LikeRed")
    static let kotoriRepost = Color("RepostGreen")
    static let kotoriSeparator = Color("Separator")
}

// X's type scale. Sizes track the official app; all participate in Dynamic Type.
extension Font {
    /// Tweet body text.
    static let tweetBody = Font.system(size: 15)
    /// Display names and emphasized runs.
    static let tweetName = Font.system(size: 15, weight: .semibold)
    /// Handles, timestamps, counts.
    static let tweetMeta = Font.system(size: 13)
    /// Section and screen titles.
    static let screenTitle = Font.system(size: 20, weight: .bold)
    /// Profile stat numbers, focal tweet text.
    static let focal = Font.system(size: 17)
}
