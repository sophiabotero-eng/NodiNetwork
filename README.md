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
- A physical iPhone for testing NFC, camera, and location features (the Simulator can't do NFC at all, and does location/camera poorly)

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

Build and run on a physical device for full functionality (NFC requires it). The Simulator works for everything except NFC tap-to-connect.

## Architecture

- **MVVM throughout.** Views are dumb; `ObservableObject` view models own state and talk to `Services/`.
- **Services** wrap every external dependency (Firebase Auth, Firestore, Storage, CoreNFC, CoreLocation, StoreKit-adjacent stuff) behind a small async/await surface so view models never import `FirebaseFirestore` directly.
- **DesignSystem/** holds the token system (`Theme.swift`) and every reusable visual primitive (buttons, text fields, avatars, cards). No view should hardcode a `Color` or `Font` value — always go through `NodiColor`/`NodiFont`.
- **Models/** are the Firestore document shapes, `Codable` via `FirebaseFirestoreSwift`.
- **functions/** is a separate Node/TypeScript project (Cloud Functions) — it has its own `package.json` and is deployed independently of the iOS app.

See inline documentation at the top of `GraphViewModel.swift`, `NFCConnectionService.swift`, and `MessagingService.swift` for the trickier subsystems.

## Firebase security rules

`firestore.rules` and `storage.rules` are commented inline, organized by the phase that introduced each section. The short version:

- Profiles (`users/{uid}`) and portfolio projects are **publicly readable** (Nodi profiles double as public portfolio pages) but only writable by their owner.
- Server-computed fields (follower/connection counts, verification badges, analytics) are locked out of client writes entirely — only Cloud Functions (Admin SDK, which bypasses rules) can touch them.
- Connections, messages, and notifications are only readable by their participants.
- Account deletion cascades via a Cloud Function (`cleanupDeletedUser`) triggered on Firebase Auth user deletion, since Auth and Firestore/Storage are otherwise unaware of each other.

## Known Limitations

Because this was built without access to a Mac/Xcode/Swift toolchain:

- **Nothing has been compiled.** There will almost certainly be small errors (a typo, an API that changed between Firebase SDK versions, an `@MainActor` isolation issue) that only show up when Xcode actually type-checks the project. Budget time for a first-build cleanup pass.
- **No App Icon image** is included — `Assets.xcassets/AppIcon.appiconset` has the `Contents.json` but no actual 1024×1024 PNG. Add one before archiving.
- **The force-directed graph (Phase 4)** uses SwiftUI `Canvas` + a hand-rolled physics loop rather than a Metal/SceneKit renderer. This is the pragmatic SwiftUI-native choice and should comfortably hit 60fps into the low thousands of visible nodes with the clustering/LOD system in place, but has not been profiled on-device — if you're targeting the full 10,000+ node target with organic movement at every zoom level, consider a Metal-backed renderer as a follow-up.
- **AI recommendations (Phase 5)** use a real, documented scoring heuristic (shared tags/software/location/mutual connections) implemented in Cloud Functions — not a call to a hosted LLM. Swapping in a model-based recommender is a reasonable follow-up once you have real usage data to rank against.
- **Universal Links** require hosting an `apple-app-site-association` file at `https://nodi.app/.well-known/apple-app-site-association` and updating `project.yml`'s associated domains to your real domain — a template is at `apple-app-site-association.json` in the repo root.
