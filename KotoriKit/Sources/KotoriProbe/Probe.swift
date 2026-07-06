import Foundation
import KotoriKit

// Scratch CLI for poking the wire layer without the simulator.
//   swift run kotori-probe user jack
//   swift run kotori-probe tweets jack
//   swift run kotori-probe tweet 20

@main
struct Probe {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else {
            print("usage: kotori-probe user <handle> | tweets <handle> | tweet <id>")
            exit(2)
        }

        let client = XClient()
        do {
            switch args[0] {
            case "user":
                let user = try await client.user(handle: args[1])
                printUser(user)
            case "tweets":
                let user = try await client.user(handle: args[1])
                let page = try await client.userTweets(userID: user.id)
                for item in page.items {
                    printItem(item)
                }
                print("-- bottom cursor: \(page.bottomCursor ?? "none")")
            case "tweet":
                let tweet = try await client.tweet(id: args[1])
                printTweet(tweet, prefix: "")
            default:
                print("unknown command \(args[0])")
                exit(2)
            }
        } catch {
            print("error: \(error)")
            exit(1)
        }
    }

    static func printUser(_ u: User) {
        print("@\(u.handle) (\(u.displayName)) [\(u.verification.rawValue)]")
        if !u.bio.isEmpty { print(u.bio) }
        print("followers \(u.followersCount)  following \(u.followingCount)  tweets \(u.tweetCount)")
        if let joined = u.joinedAt { print("joined \(joined.formatted(date: .abbreviated, time: .omitted))") }
        if let site = u.website { print("site \(site)") }
    }

    static func printItem(_ item: TimelineItem) {
        switch item {
        case .tweet(let t):
            printTweet(t, prefix: t.isPinned ? "[pinned] " : "")
        case .conversation(let ts):
            print("── thread (\(ts.count)) ──")
            for t in ts { printTweet(t, prefix: "  ") }
        case .tombstone(_, let text):
            print("[tombstone] \(text)")
        }
    }

    static func printTweet(_ t: Tweet, prefix: String) {
        let when = t.createdAt?.formatted(date: .numeric, time: .shortened) ?? "?"
        print("\(prefix)@\(t.author.handle) · \(when) · ♥ \(t.likeCount) ↺ \(t.retweetCount) 💬 \(t.replyCount)")
        if let rt = t.retweeted {
            print("\(prefix)  reposted @\(rt.tweet.author.handle): \(rt.tweet.text.prefix(120))")
        } else {
            print("\(prefix)  \(t.text)")
        }
        for m in t.media {
            print("\(prefix)  [\(m.kind.rawValue)] \(m.previewURL?.absoluteString ?? "")")
        }
        if let q = t.quoted {
            print("\(prefix)  quoting @\(q.tweet.author.handle): \(q.tweet.text.prefix(120))")
        }
        print("")
    }
}
