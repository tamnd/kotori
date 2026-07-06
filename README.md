# kotori (小鳥)

The X/Twitter experience as a native iOS app, written in modern Swift.

kotori reimplements the X client screen by screen in SwiftUI on a clean Swift 6 core.
It reads X without an account through the public guest plane, with the syndication CDN as a fallback floor, and will read and write with your own account once the session plane lands.
Sibling of [tori](https://github.com/tamnd/tori): tori archives the bird, kotori puts it in your pocket.

## Status

Early. The wire core works against live X today (profiles, user timelines, single tweets, all anonymous), the app shell is up, and screens land milestone by milestone.

| Surface | Anonymous | Signed in |
| --- | --- | --- |
| Profiles and user timelines | works | planned |
| Single tweets | works (guest + syndication fallback) | planned |
| Home feed, search, notifications, DMs, compose | shell only | planned |

## Build

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
make gen      # generate Kotori.xcodeproj
make build    # build for the simulator
make test     # run the KotoriKit test suite
```

Open `Kotori.xcodeproj` and run the Kotori scheme in the simulator.

The kit has a scratch CLI so you can poke the wire layer without the simulator:

```sh
cd KotoriKit
swift run kotori-probe user jack
swift run kotori-probe tweets jack
swift run kotori-probe tweet 20
```

## Layout

- `KotoriKit/` is a SwiftPM package holding models, the GraphQL decoder, and the `XClient` actor. It has zero dependencies, no UIKit, and builds on macOS so tests run with plain `swift test`.
- `Kotori/` is the app: a thin SwiftUI layer over the kit.
- `project.yml` generates the Xcode project; the `.xcodeproj` is never committed.

Query ids and feature switches for X's GraphQL live in one file (`Operations.swift`), so upstream churn is a one-file fix.

## Disclaimer

kotori is an unofficial client and is not affiliated with X Corp.
It talks to X directly from your device, respects rate limits, and stores credentials only in your Keychain.
There is no App Store distribution; build and sideload it yourself.

## License

MIT
