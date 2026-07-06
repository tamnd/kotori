import Foundation

/// DateFormatter is not thread-safe; this wraps one behind a lock so it can be shared.
final class LockedDateFormatter: @unchecked Sendable {
    private let lock = NSLock()
    private let formatter: DateFormatter

    init(_ format: String) {
        formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
    }

    func date(from string: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return formatter.date(from: string)
    }
}

enum WireDate {
    /// "Tue Mar 21 20:50:14 +0000 2006"
    static let twitter = LockedDateFormatter("EEE MMM dd HH:mm:ss Z yyyy")

    static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return twitter.date(from: s)
    }
}

/// Turns full_text plus entity indices into display text and styled spans.
/// All index math happens in unicode scalars, the unit Twitter counts in.
enum TextResolver {
    struct Input {
        var fullText: String
        var displayRange: [Int]?
        var entities: WireEntities?
        var extendedMedia: [WireMediaEntity]?
        /// Expanded URLs to drop entirely (media links, the trailing quote link).
        var dropURL: (String) -> Bool = { _ in false }
    }

    private enum Event {
        case url(WireURLEntity)
        case dropSpan
        case mention(String)
        case hashtag(String)
        case cashtag(String)
    }

    static func resolve(_ input: Input) -> (text: String, entities: [TextEntity]) {
        let scalars = Array(input.fullText.unicodeScalars)
        var lo = 0
        var hi = scalars.count
        if let r = input.displayRange, r.count == 2 {
            lo = max(0, min(r[0], scalars.count))
            hi = max(lo, min(r[1], scalars.count))
        }

        // Collect events keyed by start offset.
        var events: [Int: (end: Int, event: Event)] = [:]
        func add(_ indices: [Int]?, _ event: Event) {
            guard let i = indices, i.count == 2, i[0] >= 0, i[1] > i[0] else { return }
            events[i[0]] = (i[1], event)
        }
        let ents = input.entities
        for u in ents?.urls ?? [] {
            if input.dropURL(u.expanded_url ?? "") {
                add(u.indices, .dropSpan)
            } else {
                add(u.indices, .url(u))
            }
        }
        for m in (ents?.media ?? []) + (input.extendedMedia ?? []) {
            add(m.indices, .dropSpan)
        }
        for m in ents?.user_mentions ?? [] {
            if let name = m.screen_name { add(m.indices, .mention(name)) }
        }
        for h in ents?.hashtags ?? [] {
            if let t = h.text { add(h.indices, .hashtag(t)) }
        }
        for s in ents?.symbols ?? [] {
            if let t = s.text { add(s.indices, .cashtag(t)) }
        }

        var out: [Unicode.Scalar] = []
        var spans: [TextEntity] = []
        var i = lo
        while i < hi {
            if let (end, event) = events[i], end <= scalars.count {
                switch event {
                case .url(let u):
                    let display = u.display_url ?? u.expanded_url ?? String(String.UnicodeScalarView(scalars[i..<end]))
                    let target = u.expanded_url ?? display
                    let start = out.count
                    out.append(contentsOf: Array(display.unicodeScalars))
                    spans.append(TextEntity(kind: .url, display: display, target: target, range: start..<out.count))
                case .dropSpan:
                    // Swallow one space before a stripped trailing link.
                    if out.last == " ", end >= hi { out.removeLast() }
                case .mention(let name):
                    let start = out.count
                    out.append(contentsOf: scalars[i..<min(end, hi)])
                    spans.append(TextEntity(kind: .mention, display: "@\(name)", target: name, range: start..<out.count))
                case .hashtag(let tag):
                    let start = out.count
                    out.append(contentsOf: scalars[i..<min(end, hi)])
                    spans.append(TextEntity(kind: .hashtag, display: "#\(tag)", target: tag, range: start..<out.count))
                case .cashtag(let tag):
                    let start = out.count
                    out.append(contentsOf: scalars[i..<min(end, hi)])
                    spans.append(TextEntity(kind: .cashtag, display: "$\(tag)", target: tag, range: start..<out.count))
                }
                i = end
                continue
            }
            // Collapse the HTML escapes Twitter counts as literal sequences.
            if scalars[i] == "&" {
                let rest = scalars[i..<min(i + 6, scalars.count)]
                let restString = String(String.UnicodeScalarView(rest))
                var collapsed: (Unicode.Scalar, Int)? = nil
                if restString.hasPrefix("&amp;") { collapsed = ("&", 5) }
                else if restString.hasPrefix("&lt;") { collapsed = ("<", 4) }
                else if restString.hasPrefix("&gt;") { collapsed = (">", 4) }
                else if restString.hasPrefix("&quot;") { collapsed = ("\"", 6) }
                else if restString.hasPrefix("&#39;") { collapsed = ("'", 5) }
                if let (scalar, len) = collapsed {
                    out.append(scalar)
                    i += len
                    continue
                }
            }
            out.append(scalars[i])
            i += 1
        }

        // Trim whitespace left behind by stripped trailing links.
        while let last = out.last, last == " " || last == "\n" {
            out.removeLast()
        }
        spans.removeAll { $0.range.upperBound > out.count }

        return (String(String.UnicodeScalarView(out)), spans)
    }
}

/// Wire shapes in, clean models out.
enum Mapping {
    // MARK: users

    static func user(_ w: WireUserResult) throws(KotoriError) -> User {
        if w.__typename == "UserUnavailable" {
            throw (w.reason?.localizedCaseInsensitiveContains("suspend") == true) ? .suspended : .notFound
        }
        guard let id = w.rest_id, let legacy = w.legacy, let handle = legacy.screen_name else {
            throw .decode(operation: "user", detail: "missing rest_id or legacy")
        }

        let verification: User.Verification = switch legacy.verified_type {
        case "Business": .gold
        case "Government": .gray
        default: (w.is_blue_verified == true) ? .blue : .none
        }

        return User(
            id: id,
            handle: handle,
            displayName: legacy.name ?? handle,
            bio: legacy.description ?? "",
            location: legacy.location ?? "",
            website: legacy.entities?.url?.urls?.first?.expanded_url.flatMap(URL.init(string:)),
            joinedAt: WireDate.parse(legacy.created_at),
            followersCount: legacy.followers_count ?? 0,
            followingCount: legacy.friends_count ?? 0,
            tweetCount: legacy.statuses_count ?? 0,
            mediaCount: legacy.media_count ?? 0,
            likesCount: legacy.favourites_count ?? 0,
            avatarURL: legacy.profile_image_url_https.flatMap(URL.init(string:)),
            bannerURL: legacy.profile_banner_url.flatMap(URL.init(string:)),
            verification: verification,
            isProtected: legacy.protected ?? false,
            pinnedTweetID: legacy.pinned_tweet_ids_str?.first
        )
    }

    // MARK: tweets

    /// nil when the result is a tombstone; the caller decides how to surface it.
    static func tweet(_ w: WireTweetResult, pinned: Bool = false) -> Tweet? {
        var result = w
        if w.__typename == "TweetWithVisibilityResults", let inner = w.tweet {
            result = inner.value
        }
        if result.__typename == "TweetTombstone" { return nil }
        guard let legacy = result.legacy,
              let id = result.rest_id ?? legacy.id_str,
              let userResult = result.core?.user_results?.result,
              let author = try? user(userResult)
        else { return nil }

        let quoted = result.quoted_status_result?.result.flatMap { tweet($0.value) }

        // Prefer the note tweet (long form) text when present.
        let noteResult = result.note_tweet?.note_tweet_results?.result
        let resolved: (text: String, entities: [TextEntity])
        if let note = noteResult, let noteText = note.text {
            resolved = TextResolver.resolve(.init(
                fullText: noteText,
                displayRange: nil,
                entities: note.entity_set,
                extendedMedia: result.legacy?.extended_entities?.media
            ))
        } else {
            resolved = TextResolver.resolve(.init(
                fullText: legacy.full_text ?? "",
                displayRange: legacy.display_text_range,
                entities: legacy.entities,
                extendedMedia: legacy.extended_entities?.media,
                dropURL: { expanded in
                    // X hides the trailing link that points at the quoted tweet.
                    if let quoted, expanded.hasSuffix("/status/\(quoted.id)") { return true }
                    return false
                }
            ))
        }

        let mediaEntities = legacy.extended_entities?.media ?? legacy.entities?.media ?? []
        let retweeted = legacy.retweeted_status_result?.result.flatMap { tweet($0.value) }
        let (poll, card) = cardAndPoll(result.card)

        return Tweet(
            id: id,
            text: resolved.text,
            entities: resolved.entities,
            author: author,
            createdAt: WireDate.parse(legacy.created_at),
            replyCount: legacy.reply_count ?? 0,
            retweetCount: legacy.retweet_count ?? 0,
            likeCount: legacy.favorite_count ?? 0,
            quoteCount: legacy.quote_count ?? 0,
            bookmarkCount: legacy.bookmark_count,
            viewCount: result.views?.count.flatMap(Int.init),
            lang: legacy.lang,
            source: sourceName(result.source),
            conversationID: legacy.conversation_id_str,
            inReplyToID: legacy.in_reply_to_status_id_str,
            inReplyToHandle: legacy.in_reply_to_screen_name,
            media: mediaEntities.compactMap(media),
            poll: poll,
            card: card,
            quoted: quoted.map(Tweet.Quoted.init),
            retweeted: retweeted.map(Tweet.Quoted.init),
            isPinned: pinned
        )
    }

    static func media(_ w: WireMediaEntity) -> Media? {
        guard let id = w.id_str ?? w.media_key else { return nil }
        let kind: Media.Kind = switch w.type {
        case "video": .video
        case "animated_gif": .animatedGif
        default: .photo
        }
        let variants = (w.video_info?.variants ?? []).compactMap { v -> Media.Variant? in
            guard let urlString = v.url, let url = URL(string: urlString) else { return nil }
            return Media.Variant(url: url, contentType: v.content_type ?? "", bitrate: v.bitrate)
        }
        return Media(
            id: id,
            kind: kind,
            previewURL: w.media_url_https.flatMap(URL.init(string:)),
            variants: variants,
            width: w.original_info?.width ?? 0,
            height: w.original_info?.height ?? 0,
            altText: w.ext_alt_text,
            durationMs: w.video_info?.duration_millis
        )
    }

    /// "<a href=...>Twitter Web Client</a>" -> "Twitter Web Client"
    static func sourceName(_ html: String?) -> String? {
        guard let html else { return nil }
        guard let open = html.firstIndex(of: ">"), let close = html.lastIndex(of: "<"), open < close else {
            return html.isEmpty ? nil : html
        }
        let name = String(html[html.index(after: open)..<close])
        return name.isEmpty ? nil : name
    }

    static func cardAndPoll(_ w: WireCard?) -> (Poll?, Card?) {
        guard let legacy = w?.legacy, let name = legacy.name else { return (nil, nil) }
        var values: [String: WireCard.CardLegacy.Binding.Value] = [:]
        for binding in legacy.binding_values ?? [] {
            if let key = binding.key, let value = binding.value {
                values[key] = value
            }
        }

        if name.hasPrefix("poll") {
            var choices: [Poll.Choice] = []
            for n in 1...4 {
                guard let label = values["choice\(n)_label"]?.string_value else { break }
                let count = values["choice\(n)_count"]?.string_value.flatMap(Int.init) ?? 0
                choices.append(Poll.Choice(label: label, count: count))
            }
            guard !choices.isEmpty else { return (nil, nil) }
            let endsAt = values["end_datetime_utc"]?.string_value.flatMap {
                try? Date($0, strategy: .iso8601)
            }
            let final = values["counts_are_final"]?.boolean_value ?? false
            return (Poll(choices: choices, endsAt: endsAt, isOpen: !final), nil)
        }

        let image = values["photo_image_full_size_large"]?.image_value?.url
            ?? values["summary_photo_image_large"]?.image_value?.url
            ?? values["thumbnail_image_large"]?.image_value?.url
        let card = Card(
            name: name,
            url: values["card_url"]?.string_value.flatMap(URL.init(string:)),
            title: values["title"]?.string_value,
            summary: values["description"]?.string_value,
            imageURL: image.flatMap(URL.init(string:))
        )
        return (nil, card)
    }

    // MARK: timelines

    static func timelinePage(_ holder: WireTimelineHolder?, servedBy: Plane = .anonymous) -> TimelinePage {
        var items: [TimelineItem] = []
        var pinnedItems: [TimelineItem] = []
        var topCursor: String?
        var bottomCursor: String?

        for instruction in holder?.timeline?.instructions ?? [] {
            switch instruction.type {
            case "TimelinePinEntry":
                if let entry = instruction.entry, let item = timelineItem(entry, pinned: true) {
                    pinnedItems.append(item)
                }
            case "TimelineAddEntries", "TimelineReplaceEntry":
                for entry in instruction.entries ?? [] {
                    guard let content = entry.content else { continue }
                    if content.entryType == "TimelineTimelineCursor" {
                        switch content.cursorType {
                        case "Top": topCursor = content.value
                        case "Bottom": bottomCursor = content.value
                        default: break
                        }
                        continue
                    }
                    if let item = timelineItem(entry, pinned: false) {
                        items.append(item)
                    }
                }
            default:
                break
            }
        }

        return TimelinePage(
            items: pinnedItems + items,
            topCursor: topCursor,
            bottomCursor: bottomCursor,
            servedBy: servedBy
        )
    }

    static func timelineItem(_ entry: WireEntry, pinned: Bool) -> TimelineItem? {
        guard let content = entry.content else { return nil }
        let entryID = entry.entryId ?? ""
        // Promoted entries never render.
        if entryID.localizedCaseInsensitiveContains("promoted") { return nil }

        switch content.entryType {
        case "TimelineTimelineItem":
            guard let result = content.itemContent?.tweet_results?.result else { return nil }
            if let tweet = Mapping.tweet(result, pinned: pinned) {
                return .tweet(tweet)
            }
            let text = result.tombstone?.text?.text ?? "This post is unavailable."
            return .tombstone(id: entryID, text: text)
        case "TimelineTimelineModule":
            let tweets = (content.items ?? []).compactMap { moduleItem -> Tweet? in
                guard let result = moduleItem.item?.itemContent?.tweet_results?.result else { return nil }
                return Mapping.tweet(result)
            }
            return tweets.isEmpty ? nil : .conversation(tweets)
        default:
            return nil
        }
    }
}
