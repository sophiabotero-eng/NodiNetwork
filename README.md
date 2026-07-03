# Nodi

A creative networking platform where people share portfolios and connect through an interactive visual graph instead of a feed.

> ⚠️ **This codebase was written in a Linux container with no Xcode or Swift toolchain.** Every file here was hand-written to be correct, but **none of it has been compiled, run, or tested**. Treat the first build on your Mac as the real integration step — expect to fix compiler errors, Xcode project quirks, and Firebase SDK version drift. See [Known Limitations](#known-limitations) below.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 1 | Auth + Profile Foundation | ✅ Source written |
| 2 | Portfolio System | ✅ Source written |
| 3 | Networking (NFC + Connections) | ✅ Source written |
| 4 | Interactive Network Graph | ✅ Source written |
| 5 | Community + AI + Polish | ✅ Source written |

## Getting started

### 1. Prerequisites

- macOS with Xcode 15.4+ (targets iOS 17)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Node 20+ and the Firebase CLI — `npm install -g firebase-tools` (for Cloud Functions + deploying rules)
- A physical iPhone for testing NFC, camera, location, and voice recording (the Simulator can't do NFC at all, and does location/camera/microphone poorly or not at all)

### 2. Generate the Xcode project

This repo does **not** commit an `.xcodeproj` — it's generated from [`project.yml`](./project.yml) so the project structure stays in sync with the file tree without hand-edited `.pbxproj` merge conflicts.

```bash
xcodegen generate
open Nodi.xcodeproj
```

Xcode will resolve the Swift Package dependencies (Firebase iOS SDK, Google Sign-In) on first open — this can take a few minutes.

### 3. Firebase setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an iOS app with bundle ID `com.nodinetwork.Nodi` (or update `project.yml` to match whatever you choose).
3. Download the real `GoogleService-Info.plist` and replace the **placeholder** at `Nodi/Resources/GoogleService-Info.plist` — it's clearly marked as fake and the app will fail to authenticate until you do this.
4. In the Firebase console, enable:
   - **Authentication** → Sign in with Apple, Google, Email/Password
   - **Firestore** (start in production mode — rules are provided)
   - **Storage**
   - **Cloud Messaging**
   - **Cloud Functions** (requires the Blaze plan)
5. Deploy security rules, indexes, and functions:
   ```bash
   firebase login
   firebase use --add        # pick your project
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```
6. For Sign in with Apple, add the **Sign in with Apple** capability in Xcode (Signing & Capabilities) and configure your Services ID / key in the Firebase Authentication provider settings.
7. For Google Sign-In, add your **REVERSED_CLIENT_ID** (from the real `GoogleService-Info.plist`) as a URL scheme — XcodeGen doesn't know this value ahead of time since it's project-specific, so add it manually in Xcode: Target → Info → URL Types.

### 4. Push notifications

- Enable **Push Notifications** and **Background Modes → Remote notifications** capabilities in Xcode (the entitlements file already requests `aps-environment`).
- Upload your APNs auth key (or certificates) to Firebase Cloud Messaging → Project Settings → Cloud Messaging.

### 5. Run it

Build and run on a physical device for full functionality (NFC, precise location, and voice messages all need one). The Simulator works for everything else — auth, portfolios, messaging text, the graph, events.

## What's built, by phase

**Phase 1 — Auth + Profile Foundation.** Sign in with Apple/Google/email (`AuthService`), a multi-step onboarding flow with live username availability checking, full profile editing, dark/light/system theming (`ThemeManager`), and the design system every later screen builds on (`DesignSystem/`).

**Phase 2 — Portfolio System.** Projects with image/video/PDF media (uploaded immediately on add, with on-device thumbnail generation for video/PDF), a lazy-loading grid gallery, a full-screen paging viewer, and draft/publish states.

**Phase 3 — Networking.** Connection requests with 8 relationship types, a follow system, NFC tag writing/reading, QR code generation/scanning, shareable links, nearby-creatives discovery via a hand-rolled geohash implementation, search + filters, and in-app notifications. See `NFCConnectionService.swift` for an important, explicitly-flagged constraint on what "NFC tap-to-connect" can actually mean on iOS.

**Phase 4 — Interactive Network Graph.** The signature feature: a force-directed, pinch-to-zoom, four-level graph of your network rendered in a SwiftUI `Canvas`, with clustering so it scales past what any UI could usefully force-simulate at once. See the doc comment at the top of `GraphViewModel.swift`.

**Phase 5 — Community + AI + Polish.** Direct messaging with voice messages, read receipts, and typing indicators; a real (non-LLM) connection-recommendation heuristic running in Cloud Functions; profile and portfolio view analytics with a native Swift Charts bar chart; studio/team accounts with member rosters; an events system with nearby discovery; offline Firestore persistence; a VoiceOver-accessible list fallback for the graph; and a privacy manifest for App Store submission.

## Architecture

- **MVVM throughout.** Views are dumb; `ObservableObject` view models own state and talk to `Services/`.
- **Services** wrap every external dependency (Firebase Auth, Firestore, Storage, CoreNFC, CoreLocation, AVFoundation) behind a small async/await surface so view models never import `FirebaseFirestore` directly.
- **DesignSystem/** holds the token system (`Theme.swift`) and every reusable visual primitive (buttons, text fields, avatars, cards). No view should hardcode a `Color` or `Font` value — always go through `NodiColor`/`NodiFont`.
- **Models/** are the Firestore document shapes, `Codable` via `FirebaseFirestoreSwift`. Relationship documents (`Connection`, `Follow`, `Conversation`) use deterministic, sorted-pair document IDs (e.g. `Connection.documentId(for:_:)`) instead of auto-generated IDs, so a duplicate relationship between the same two people is structurally impossible rather than something application code or rules have to police.
- **functions/** is a separate Node/TypeScript project (Cloud Functions) — it has its own `package.json` and is deployed independently of the iOS app. It's where every server-computed counter (`followerCount`, `connectionCount`, unread message counts) and every push notification originate — the client never computes these itself.

See inline documentation at the top of `GraphViewModel.swift`, `NFCConnectionService.swift`, and `MessageRepository.swift` for the trickier subsystems.

## Deep linking

`nodi://` custom scheme and `https://nodi.app` universal links share one parser (`DeepLinkRouter.swift` → `NodiDeepLink`):

- `.../profile/{username}` — open a profile
- `.../graph/{username}` — open someone's network graph
- `.../connect/{uid}` — resolve to the connect-confirm sheet (this is also what a QR code encodes and what an NFC tag stores — see `QRCodeService.connectURL(for:)`)
- `.../project/{userId}/{projectId}` — open a specific portfolio project
- `.../event/{eventId}` — open an event

For universal links to work, you need to host an `apple-app-site-association` file at `https://nodi.app/.well-known/apple-app-site-association` (a template is at `apple-app-site-association.json` in the repo root — fill in your real Team ID) and update `project.yml`'s `associated-domains` entitlement to your real domain.

`ConnectViewModel`'s resolve-and-confirm flow is owned centrally by `MainTabView` (not by `ConnectView`) specifically so a link or NFC scan resolves correctly no matter which tab is active when it arrives — see the doc comment there.

## Firebase security rules

`firestore.rules` and `storage.rules` are commented inline, organized by the phase that introduced each section. The short version:

- Profiles (`users/{uid}`) and published portfolio projects are **publicly readable** (Nodi profiles double as public portfolio pages) but only writable by their owner.
- **Accepted** connections are also readable by any signed-in user — not just the two participants — because the Phase 4 graph needs to traverse "friends of friends," which means reading *other people's* connections. This is the same visibility model as a public following list. Pending/declined connection requests stay private to their two participants.
- Server-computed fields (follower/following/connection counts, profile/project view counts via `viewCount`/`profileViewCount`, verification badges, recommendations) are locked out of general client writes — most are exclusively written by Cloud Functions (Admin SDK, which bypasses rules); view counts are the one exception where any signed-in user may bump the counter for the specific document they're viewing, without gaining write access to anything else on it.
- Conversations and messages are private to their two participants, always.
- Account deletion cascades via a Cloud Function (`cleanupDeletedUser`) triggered on Firebase Auth user deletion, since Auth and Firestore/Storage are otherwise unaware of each other.

## Cloud Functions

All in `functions/src/`, deployed via `firebase deploy --only functions`:

| File | Responsibility |
|---|---|
| `auth.ts` | `cleanupDeletedUser` — cascades Firebase Auth account deletion into Firestore/Storage cleanup |
| `social.ts` | Follow/connection counters and their associated notifications |
| `messaging.ts` | Unread message counter increments + push on new message |
| `notifications.ts` | Shared `writeNotification`/`sendPushToUser` helpers (stale FCM token cleanup included) |
| `recommendations.ts` | The connection-recommendation scoring heuristic — see its doc comment for why this isn't an LLM call |

## Testing

- `NodiTests/` — unit tests for pure logic (username/geohash validation, model document-ID helpers, graph node/zoom-level behavior, search keyword building, discovery filter state). View models that talk to Firestore directly aren't unit tested here — that would need a mocking layer or the Firebase emulator wired into the test target, which is a reasonable next step once this builds.
- `NodiUITests/` — smoke tests for the signed-out launch flow.
- Run both from Xcode (`Cmd+U`) or `xcodebuild test -scheme Nodi` once the project builds.

## Known Limitations

Because this was built without access to a Mac/Xcode/Swift toolchain:

- **Nothing has been compiled.** There will almost certainly be small errors (a typo, an API that changed between Firebase SDK versions, an `@MainActor` isolation issue) that only show up when Xcode actually type-checks the project. Budget time for a first-build cleanup pass.
- **No App Icon image** is included — `Assets.xcassets/AppIcon.appiconset` has the `Contents.json` but no actual 1024×1024 PNG. Add one before archiving.
- **The force-directed graph (Phase 4)** uses SwiftUI `Canvas` + a hand-rolled physics loop rather than a Metal/SceneKit renderer. This is the pragmatic SwiftUI-native choice and should comfortably hit 60fps at the node counts it actually keeps resident (capped and clustered — see `GraphViewModel.swift`), but has not been profiled on-device.
- **The graph is not usable with VoiceOver in its canvas form** — `Canvas` has no accessibility tree. A list-equivalent view (`GraphAccessibleListView`) is offered automatically when VoiceOver is on, and via a toolbar button otherwise, as an explicit, documented alternative rather than a silent gap.
- **AI recommendations (Phase 5)** use a real, documented scoring heuristic (shared tags/software/location/mutual connections) implemented in Cloud Functions — not a call to a hosted LLM. Swapping in a model-based recommender is a reasonable follow-up once you have real usage data to rank against.
- **Discovery's profession/location/school/company/software filters** run client-side over a bounded, recently-active user pool rather than a real search index. Fine at launch scale; replace with Algolia/Typesense/similar once the user base outgrows a few hundred active profiles being pulled per search.
- **"NFC tap-to-connect" cannot mean two iPhones tapped together.** Apple does not expose a public CoreNFC API for phone-to-phone data exchange to third-party apps — that's true for third-party apps generally, not a Nodi-specific gap. What's actually implemented (`NFCConnectionService.swift`) is writing your connect link to a physical NFC tag/card you own, which anyone (with or without Nodi installed) can then tap to open your profile via the universal link. QR code and the shareable link are the real phone-to-phone mechanisms and are treated as first-class in the UI, not fallbacks. See the doc comment at the top of `NFCConnectionService.swift` for the full explanation.
- **Voice messages and profile/cover photos are not compressed/transcoded server-side** — the client resizes images before upload (`StorageService`) but videos and voice notes upload as recorded. A Cloud Function-based transcoding pipeline (e.g. via a Storage-triggered function calling a media processing service) would be the production-grade follow-up for large media libraries.
