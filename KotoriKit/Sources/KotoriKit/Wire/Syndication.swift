import Foundation

/// The syndication CDN: no auth, no token rotation, the floor that keeps working
/// when the guest GraphQL plane is walled. Serves single tweets and embeds.
enum Syndication {
    static func tweet(id: String, urlSession: URLSession) async throws -> Tweet {
        var components = URLComponents(string: "https://cdn.syndication.twimg.com/tweet-result")!
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "token", value: token(for: id)),
        ]
        let request = URLRequest(url: components.url!)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw KotoriError.transport(underlying: error.localizedDescription)
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 404: throw KotoriError.notFound
        default: throw KotoriError.walled(plane: .anonymous)
        }

        let wire: SyndicationTweet
        do {
            wire = try JSONDecoder().decode(SyndicationTweet.self, from: data)
        } catch {
            throw KotoriError.decode(operation: "syndication/tweet-result", detail: String(describing: error))
        }
        return map(wire)
    }

    /// The token the CDN expects, derived from the id the same way the embed JS does:
    /// ((id / 1e15) * pi) in base 36 with zero runs and the dot stripped.
    static func token(for id: String) -> String {
        guard let value = Double(id) else { return "a" }
        var x = (value / 1e15) * Double.pi
        let digits = "0123456789abcdefghijklmnopqrstuvwxyz"
        var integerPart = Int(x)
        x -= Double(integerPart)
        var whole = ""
        if integerPart == 0 {
            whole = "0"
        }
        while integerPart > 0 {
            let d = integerPart % 36
            whole = String(digits[digits.index(digits.startIndex, offsetBy: d)]) + whole
            integerPart /= 36
        }
        var fraction = ""
        for _ in 0..<20 {
            x *= 36
            let d = Int(x)
            fraction += String(digits[digits.index(digits.startIndex, offsetBy: min(max(d, 0), 35))])
            x -= Double(d)
        }
        return (whole + "." + fraction)
            .replacingOccurrences(of: "0+", with: "", options: .regularExpression)
            .replacingOccurrences(of: ".", with: "")
    }

    // MARK: wire shape

    struct SyndicationTweet: Decodable {
        struct SynUser: Decodable {
            let id_str: String?
            let name: String?
            let screen_name: String?
            let is_blue_verified: Bool?
            let profile_image_url_https: String?
        }
        struct SynPhoto: Decodable {
            let url: String?
            let width: Int?
            let height: Int?
        }
        struct SynVideo: Decodable {
            struct SynVariant: Decodable {
                let type: String?
                let src: String?
            }
            let poster: String?
            let variants: [SynVariant]?
        }

        let id_str: String?
        let text: String?
        let created_at: String?
        let favorite_count: Int?
        let conversation_count: Int?
        let lang: String?
        let user: SynUser?
        let entities: WireEntities?
        let display_text_range: [Int]?
        let photos: [SynPhoto]?
        let video: SynVideo?
        let in_reply_to_status_id_str: String?
        let in_reply_to_screen_name: String?
    }

    static func map(_ w: SyndicationTweet) -> Tweet {
        let author = User(
            id: w.user?.id_str ?? "",
            handle: w.user?.screen_name ?? "",
            displayName: w.user?.name ?? w.user?.screen_name ?? "",
            avatarURL: w.user?.profile_image_url_https.flatMap(URL.init(string:)),
            verification: w.user?.is_blue_verified == true ? .blue : .none
        )
        let resolved = TextResolver.resolve(.init(
            fullText: w.text ?? "",
            displayRange: w.display_text_range,
            entities: w.entities,
            extendedMedia: nil
        ))

        var media: [Media] = []
        for (index, photo) in (w.photos ?? []).enumerated() {
            guard let urlString = photo.url, let url = URL(string: urlString) else { continue }
            media.append(Media(
                id: "syn-photo-\(index)",
                kind: .photo,
                previewURL: url,
                width: photo.width ?? 0,
                height: photo.height ?? 0
            ))
        }
        if let video = w.video {
            let variants = (video.variants ?? []).compactMap { v -> Media.Variant? in
                guard let src = v.src, let url = URL(string: src) else { return nil }
                return Media.Variant(url: url, contentType: v.type ?? "", bitrate: nil)
            }
            media.append(Media(
                id: "syn-video",
                kind: .video,
                previewURL: video.poster.flatMap(URL.init(string:)),
                variants: variants
            ))
        }

        return Tweet(
            id: w.id_str ?? "",
            text: resolved.text,
            entities: resolved.entities,
            author: author,
            createdAt: w.created_at.flatMap { try? Date($0, strategy: .iso8601WithFractionalSeconds) },
            replyCount: w.conversation_count ?? 0,
            likeCount: w.favorite_count ?? 0,
            lang: w.lang,
            inReplyToID: w.in_reply_to_status_id_str,
            inReplyToHandle: w.in_reply_to_screen_name,
            media: media
        )
    }
}

extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    static var iso8601WithFractionalSeconds: Self { .init(includingFractionalSeconds: true) }
}
