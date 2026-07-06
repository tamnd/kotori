import Foundation

/// The one owner of session state and outbound requests.
/// Views never touch URLSession; they ask this actor for models.
public actor XClient {
    private let urlSession: URLSession
    private var guestToken: String?
    private var lastRequest: [String: ContinuousClock.Instant] = [:]
    /// Minimum spacing between calls to the same operation, so scrolling cannot burst-ban a guest token.
    private let perOperationSpacing: Duration = .milliseconds(300)

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]
        urlSession = URLSession(configuration: config)
    }

    // MARK: public reads (anonymous plane)

    public func user(handle: String) async throws -> User {
        struct Vars: Encodable {
            let screen_name: String
            let withSafetyModeUserFields = true
        }
        let data = try await graphQL(Operations.userByScreenName, variables: Vars(screen_name: handle))
        let envelope = try decodeEnvelope(data, operation: "UserByScreenName")
        guard let result = envelope.data?.user?.result else { throw KotoriError.notFound }
        return try Mapping.user(result)
    }

    public func userTweets(userID: String, count: Int = 40, cursor: String? = nil) async throws -> TimelinePage {
        struct Vars: Encodable {
            let userId: String
            let count: Int
            let cursor: String?
            let includePromotedContent = false
            let withVoice = true
        }
        let data = try await graphQL(
            Operations.userTweets,
            variables: Vars(userId: userID, count: count, cursor: cursor)
        )
        let envelope = try decodeEnvelope(data, operation: "UserTweets")
        let holder = envelope.data?.user?.result?.timeline ?? envelope.data?.user?.result?.timeline_v2
        return Mapping.timelinePage(holder)
    }

    public func tweet(id: String) async throws -> Tweet {
        struct Vars: Encodable {
            let tweetId: String
            let withCommunity = false
            let includePromotedContent = false
            let withVoice = false
        }
        do {
            let data = try await graphQL(Operations.tweetResultByRestID, variables: Vars(tweetId: id))
            let envelope = try decodeEnvelope(data, operation: "TweetResultByRestId")
            guard let result = envelope.data?.tweetResult?.result,
                  let tweet = Mapping.tweet(result)
            else { throw KotoriError.notFound }
            return tweet
        } catch KotoriError.notFound {
            throw KotoriError.notFound
        } catch {
            // The guest plane got walled; the syndication CDN is the floor that keeps working.
            Log.wire.info("tweet(\(id)) fell back to syndication")
            return try await Syndication.tweet(id: id, urlSession: urlSession)
        }
    }

    // MARK: plumbing

    func graphQL(_ operation: Operation, variables: some Encodable) async throws -> Data {
        try await throttle(operation.name)
        let token = try await ensureGuestToken()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let variablesJSON = String(decoding: try encoder.encode(variables), as: UTF8.self)

        var components = URLComponents(string: "https://api.twitter.com")!
        components.path = operation.path
        components.queryItems = [URLQueryItem(name: "variables", value: variablesJSON)]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(Operations.bearer)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "x-guest-token")
        request.setValue("yes", forHTTPHeaderField: "x-twitter-active-user")

        let (data, response) = try await send(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            return data
        case 401, 403:
            // One transparent refresh, then surface the wall.
            guestToken = nil
            let fresh = try await ensureGuestToken()
            request.setValue(fresh, forHTTPHeaderField: "x-guest-token")
            let (retryData, retryResponse) = try await send(request)
            let retryStatus = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard retryStatus == 200 else { throw KotoriError.walled(plane: .anonymous) }
            return retryData
        case 404:
            throw KotoriError.notFound
        case 429:
            throw KotoriError.rateLimited(reset: rateLimitReset(response))
        default:
            throw KotoriError.transport(underlying: "HTTP \(status) from \(operation.name)")
        }
    }

    func ensureGuestToken() async throws -> String {
        if let guestToken { return guestToken }
        var request = URLRequest(url: URL(string: "https://api.twitter.com/1.1/guest/activate.json")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Operations.bearer)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await send(request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw KotoriError.walled(plane: .anonymous)
        }
        struct Activation: Decodable { let guest_token: String }
        guard let activation = try? JSONDecoder().decode(Activation.self, from: data) else {
            throw KotoriError.decode(operation: "guest/activate", detail: "no guest_token in response")
        }
        Log.wire.info("activated guest token")
        guestToken = activation.guest_token
        return activation.guest_token
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw KotoriError.transport(underlying: error.localizedDescription)
        }
    }

    private func throttle(_ operationName: String) async throws {
        let now = ContinuousClock.now
        if let last = lastRequest[operationName] {
            let wait = perOperationSpacing - last.duration(to: now)
            if wait > .zero {
                try await Task.sleep(for: wait)
            }
        }
        lastRequest[operationName] = ContinuousClock.now
    }

    private func rateLimitReset(_ response: URLResponse) -> Date? {
        guard let http = response as? HTTPURLResponse,
              let raw = http.value(forHTTPHeaderField: "x-rate-limit-reset"),
              let epoch = TimeInterval(raw)
        else { return nil }
        return Date(timeIntervalSince1970: epoch)
    }
}

/// Shared by XClient and tests: envelope decode plus body-level error mapping.
func decodeEnvelope(_ data: Data, operation: String) throws -> WireEnvelope {
    let envelope: WireEnvelope
    do {
        envelope = try JSONDecoder().decode(WireEnvelope.self, from: data)
    } catch {
        throw KotoriError.decode(operation: operation, detail: String(describing: error))
    }
    if envelope.data == nil || (envelope.data?.user == nil && envelope.data?.tweetResult == nil && envelope.data?.list == nil) {
        if let message = envelope.errors?.first?.message {
            throw KotoriError.decode(operation: operation, detail: message)
        }
        throw KotoriError.walled(plane: .anonymous)
    }
    return envelope
}
