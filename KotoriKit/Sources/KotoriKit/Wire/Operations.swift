import Foundation

/// One GraphQL operation as X currently serves it.
/// Query ids churn upstream; when one dies, this file is the whole fix.
public struct Operation: Sendable {
    public let name: String
    public let queryID: String

    var path: String { "/graphql/\(queryID)/\(name)" }
}

/// The operation table. Verified against live guest responses on 2026-07-06.
public enum Operations {
    /// The public web bearer, used for guest activation and guest GraphQL.
    public static let bearer = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    public static let userByScreenName = Operation(name: "UserByScreenName", queryID: "G3KGOASz96M-Qu0nwmGXNg")
    public static let userByRestID = Operation(name: "UserByRestId", queryID: "tD8zKvQzwY3kdx5yz6YmOw")
    public static let userTweets = Operation(name: "UserTweets", queryID: "V7H0Ap3_Hh2FyS75OCDO3Q")
    public static let userTweetsAndReplies = Operation(name: "UserTweetsAndReplies", queryID: "E4wA5vo2sjVyvpliUffSCw")
    public static let userMedia = Operation(name: "UserMedia", queryID: "dexO_2tohK86JDudXXG3Yw")
    public static let tweetResultByRestID = Operation(name: "TweetResultByRestId", queryID: "DJS3BdhUhcaEpZ7B7irJDg")
    public static let tweetDetail = Operation(name: "TweetDetail", queryID: "xOhkmRac04YFZmOzU9PJHg")
    public static let listLatestTweetsTimeline = Operation(name: "ListLatestTweetsTimeline", queryID: "whF0_KH1fCkdLLoyNPMoEw")
}
