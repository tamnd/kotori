import Foundation

/// One GraphQL operation as X currently serves it.
/// Query ids churn upstream; when one dies, this file is the whole fix.
public struct Operation: Sendable {
    public let name: String
    public let queryID: String

    var path: String { "/graphql/\(queryID)/\(name)" }
}

/// The operation table.
/// These three are verified against live guest responses (2026-07-06), and none
/// of them need a features param. Ids for the other read operations all 404 on
/// the guest plane right now; they get added here as their milestones land,
/// with fresh ids captured from the web client.
public enum Operations {
    /// The public web bearer, used for guest activation and guest GraphQL.
    public static let bearer = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    public static let userByScreenName = Operation(name: "UserByScreenName", queryID: "G3KGOASz96M-Qu0nwmGXNg")
    public static let userTweets = Operation(name: "UserTweets", queryID: "V7H0Ap3_Hh2FyS75OCDO3Q")
    public static let tweetResultByRestID = Operation(name: "TweetResultByRestId", queryID: "DJS3BdhUhcaEpZ7B7irJDg")
}
