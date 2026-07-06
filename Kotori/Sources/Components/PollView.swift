import SwiftUI
import KotoriKit

/// Poll results as X shows them to viewers: bars, percentages, total, state.
struct PollView: View {
    var poll: Poll

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(poll.choices.enumerated()), id: \.offset) { _, choice in
                bar(choice)
            }
            Text(footer)
                .font(.tweetMeta)
                .foregroundStyle(Color.kotoriTextSecondary)
        }
    }

    private func bar(_ choice: Poll.Choice) -> some View {
        let fraction = poll.totalVotes > 0 ? Double(choice.count) / Double(poll.totalVotes) : 0
        let leading = poll.choices.map(\.count).max() == choice.count && poll.totalVotes > 0
        return ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6)
                    .fill(leading ? Color.kotoriAccent.opacity(0.35) : Color.kotoriBackgroundSecondary)
                    .frame(width: max(geo.size.width * fraction, 8))
            }
            HStack {
                Text(choice.label)
                    .font(.tweetBody)
                    .fontWeight(leading ? .semibold : .regular)
                    .foregroundStyle(Color.kotoriText)
                Spacer()
                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.tweetMeta)
                    .foregroundStyle(Color.kotoriTextSecondary)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 30)
    }

    private var footer: String {
        let votes = "\(Format.count(poll.totalVotes)) votes"
        if !poll.isOpen { return "\(votes) · Final results" }
        guard let endsAt = poll.endsAt else { return votes }
        let left = endsAt.timeIntervalSinceNow
        if left <= 0 { return "\(votes) · Final results" }
        if left < 3600 { return "\(votes) · \(Int(left / 60))m left" }
        if left < 86400 { return "\(votes) · \(Int(left / 3600))h left" }
        return "\(votes) · \(Int(left / 86400))d left"
    }
}
