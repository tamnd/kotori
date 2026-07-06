import Foundation

// The raw shapes X sends, decoded tolerantly: nearly everything optional,
// unknown typenames degrade instead of failing the page.
// Nothing in this file leaves the kit; Mapping.swift turns these into models.

struct WireEnvelope: Decodable {
    struct WireDataError: Decodable {
        let message: String?
        let code: Int?
    }

    struct DataField: Decodable {
        let user: WireUserResponse?
        let tweetResult: WireTweetResponse?
        let list: WireListResponse?
    }

    let data: DataField?
    let errors: [WireDataError]?
}

struct WireUserResponse: Decodable {
    let result: WireUserResult?
}

struct WireTweetResponse: Decodable {
    let result: WireTweetResult?
}

struct WireListResponse: Decodable {
    let tweets_timeline: WireTimelineHolder?
}

struct WireUserResult: Decodable {
    let __typename: String?
    let rest_id: String?
    let is_blue_verified: Bool?
    let legacy: WireUserLegacy?
    let timeline: WireTimelineHolder?
    let timeline_v2: WireTimelineHolder?
    let reason: String?
}

struct WireUserLegacy: Decodable {
    let screen_name: String?
    let name: String?
    let description: String?
    let location: String?
    let url: String?
    let created_at: String?
    let followers_count: Int?
    let friends_count: Int?
    let statuses_count: Int?
    let media_count: Int?
    let favourites_count: Int?
    let profile_image_url_https: String?
    let profile_banner_url: String?
    let verified: Bool?
    let verified_type: String?
    let protected: Bool?
    let pinned_tweet_ids_str: [String]?
    let entities: WireUserEntities?

    struct WireUserEntities: Decodable {
        struct URLHolder: Decodable {
            let urls: [WireURLEntity]?
        }
        let url: URLHolder?
    }
}

struct WireTweetResult: Decodable {
    let __typename: String?
    let rest_id: String?
    let core: WireCore?
    let legacy: WireTweetLegacy?
    let views: WireViews?
    let source: String?
    let note_tweet: WireNoteTweetHolder?
    let quoted_status_result: WireQuotedHolder?
    let card: WireCard?
    let tweet: WireTweetResultBox?
    let tombstone: WireTombstone?

    struct WireCore: Decodable {
        let user_results: WireUserResponse?
    }

    struct WireViews: Decodable {
        let count: String?
    }

    struct WireQuotedHolder: Decodable {
        let result: WireTweetResultBox?
    }
}

// Breaks the recursive value cycle (a class so the struct stays finite).
final class WireTweetResultBox: Decodable {
    let value: WireTweetResult

    init(from decoder: Decoder) throws {
        value = try WireTweetResult(from: decoder)
    }
}

struct WireTombstone: Decodable {
    struct TombText: Decodable {
        let text: String?
    }
    let text: TombText?
}

struct WireNoteTweetHolder: Decodable {
    struct Results: Decodable {
        struct NoteResult: Decodable {
            let text: String?
            let entity_set: WireEntities?
        }
        let result: NoteResult?
    }
    let note_tweet_results: Results?
}

struct WireTweetLegacy: Decodable {
    let id_str: String?
    let full_text: String?
    let display_text_range: [Int]?
    let created_at: String?
    let favorite_count: Int?
    let retweet_count: Int?
    let reply_count: Int?
    let quote_count: Int?
    let bookmark_count: Int?
    let lang: String?
    let conversation_id_str: String?
    let in_reply_to_status_id_str: String?
    let in_reply_to_screen_name: String?
    let entities: WireEntities?
    let extended_entities: WireExtendedEntities?
    let retweeted_status_result: WireTweetResult.WireQuotedHolder?
    let is_quote_status: Bool?
}

struct WireEntities: Decodable {
    let urls: [WireURLEntity]?
    let user_mentions: [WireMentionEntity]?
    let hashtags: [WireTagEntity]?
    let symbols: [WireTagEntity]?
    let media: [WireMediaEntity]?
}

struct WireExtendedEntities: Decodable {
    let media: [WireMediaEntity]?
}

struct WireURLEntity: Decodable {
    let url: String?
    let expanded_url: String?
    let display_url: String?
    let indices: [Int]?
}

struct WireMentionEntity: Decodable {
    let screen_name: String?
    let indices: [Int]?
}

struct WireTagEntity: Decodable {
    let text: String?
    let indices: [Int]?
}

struct WireMediaEntity: Decodable {
    let id_str: String?
    let media_key: String?
    let type: String?
    let url: String?
    let media_url_https: String?
    let ext_alt_text: String?
    let indices: [Int]?
    let original_info: OriginalInfo?
    let video_info: VideoInfo?

    struct OriginalInfo: Decodable {
        let width: Int?
        let height: Int?
    }

    struct VideoInfo: Decodable {
        let duration_millis: Int?
        let variants: [Variant]?

        struct Variant: Decodable {
            let bitrate: Int?
            let content_type: String?
            let url: String?
        }
    }
}

struct WireCard: Decodable {
    struct CardLegacy: Decodable {
        let name: String?
        let binding_values: [Binding]?

        struct Binding: Decodable {
            let key: String?
            let value: Value?

            struct Value: Decodable {
                let string_value: String?
                let boolean_value: Bool?
                let image_value: ImageValue?

                struct ImageValue: Decodable {
                    let url: String?
                }
            }
        }
    }
    let legacy: CardLegacy?
}

// Timeline plumbing: instructions -> entries -> item content.

struct WireTimelineHolder: Decodable {
    struct Inner: Decodable {
        let instructions: [WireInstruction]?
    }
    let timeline: Inner?
}

struct WireInstruction: Decodable {
    let type: String?
    let entries: [WireEntry]?
    let entry: WireEntry?
}

struct WireEntry: Decodable {
    let entryId: String?
    let content: WireEntryContent?
}

struct WireEntryContent: Decodable {
    let entryType: String?
    let itemContent: WireItemContent?
    let items: [WireModuleItem]?
    let cursorType: String?
    let value: String?
}

struct WireModuleItem: Decodable {
    struct ItemHolder: Decodable {
        let itemContent: WireItemContent?
    }
    let entryId: String?
    let item: ItemHolder?
}

struct WireItemContent: Decodable {
    let itemType: String?
    let tweet_results: WireTweetResponse?
    let user_results: WireUserResponse?
}
