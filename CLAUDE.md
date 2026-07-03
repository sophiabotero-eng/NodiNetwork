# Nodi — Claude Code Build Prompt

## Project Setup Instructions (do this first, before writing any app code)

1. Confirm Xcode and Swift toolchain versions available in this environment.
2. Initialize a new SwiftUI iOS app project named `Nodi` using the standard Xcode project structure (or Swift Package structure if no Xcode GUI is available in this environment — ask me which applies before proceeding).
3. Set up a git repository, commit after every phase completes, and use clear commit messages (`Phase 1: Auth + Profile Foundation`, etc.).
4. Set up Firebase config (Auth, Firestore, Storage, FCM, Cloud Functions) with placeholder `GoogleService-Info.plist` and flag clearly where I need to drop in my real Firebase project credentials.
5. Before starting each phase, briefly restate the phase's deliverable and ask me to confirm before writing code, unless I've told you to run through all phases autonomously.

> **Note on this build:** This project was generated in a Linux container with no Xcode/Swift toolchain available. All source was written by hand and has **not been compiled or run**. See `README.md` → "Known Limitations" before opening in Xcode. The user explicitly approved: (1) writing full source without build verification, (2) running all 5 phases autonomously in one pass, (3) removing the prior placeholder web content in this repo.

---

## Role

You are acting as a senior team of iOS engineers, backend engineers, and product designers building a production-ready iOS application.

## Product

**Nodi** is a creative networking platform where users share portfolios and connect through an interactive visual network instead of a traditional feed. It should feel like a high-end Apple product: minimal, fast, elegant, and highly animated.

## Tech Stack

**Frontend:** SwiftUI, Swift Concurrency, MVVM architecture, CoreNFC, CoreLocation, Combine (only if necessary)

**Backend:** Firebase Authentication (Apple, Google, Email), Firestore, Firebase Storage, Firebase Cloud Messaging, Cloud Functions

## Core Product Principle

Every user has:
1. A portfolio profile
2. A network of connections
3. A visual graph representation of their relationships

Networking is not a feed. It is spatial, visual, and explorable.

## Phased Build Requirement

Build in 5 phases, in order. Do not skip phases, do not implement future phases early, and do not use placeholder logic in place of real implementations. Each phase must be fully functional, buildable, and (where applicable) testable before moving to the next. After each phase, summarize what was built and any decisions you made that I should know about.

---

### Phase 1 — Auth + Profile Foundation

- Sign in with Apple, Google Sign-In, email authentication
- User profile fields: name, username, profile photo, cover image, bio, profession, location, website, Instagram, LinkedIn, Behance
- Onboarding flow
- Edit profile screen
- Settings screen
- Dark mode and light mode support
- Firestore user model
- Firebase Storage uploads

**Deliverable:** users can create accounts, log in, and fully edit and save their profile.

### Phase 2 — Portfolio System

- Project creation with image, video, and PDF uploads
- Title, description, tags, software used, year, collaborators, cover image
- Grid gallery view and full-screen project viewer
- Edit, delete, and draft-save projects
- Lazy-loaded images, smooth scrolling, optimized media storage

**Deliverable:** users can build a full creative portfolio.

### Phase 3 — Networking (NFC + Connections)

- Connection methods: NFC tap-to-connect, QR code fallback, shareable link
- Follow system, connection requests (accept/decline), auto-connect on NFC tap
- Store timestamp and connection type (friend, collaborator, school, work, mentor, client, studio, event)
- Discovery: nearby creatives via CoreLocation, user search, filters (profession, location, school, company, software, availability)
- Notifications: new connection, new follow, connection request

**Deliverable:** users can meet, tap phones, and instantly connect.

### Phase 4 — Interactive Network Graph (signature feature)

- Pinch-outward gesture from profile transitions into graph view with smooth spring animation; profile collapses into a node
- Force-directed layout, GPU-accelerated rendering, support for 10,000+ nodes, node clustering, lazy loading of distant nodes
- Nodes display: profile image, name, profession, online indicator, verification badge
- Edges represent relationship type: worked together, school, mentor, friend, client, studio, event; mutual connections glow
- Zoom levels: 1) single profile, 2) direct connections, 3) friends of friends, 4) full ecosystem
- Tap node to open profile, search inside graph, filter graph by attributes

**Deliverable:** a living, explorable creative universe.

### Phase 5 — Community + AI + Polish

- Messaging: direct messages, voice messages, read receipts, typing indicators
- Growth: AI collaborator recommendations, suggested connections, portfolio analytics, profile analytics
- Community: studio accounts, team profiles, events system, nearby events discovery
- Polish: push notifications, deep linking, public portfolio pages, offline caching, image optimization, accessibility support, App Store readiness
- Engineering: refactor architecture as needed, remove duplication, add unit tests and UI tests, write full documentation and a README

**Deliverable:** production-ready application.

---

## Design System

- Minimal, Apple-inspired UI, dark mode first
- Soft spacing and typography, rounded cards, subtle depth
- High-performance animations, 60fps minimum, spring physics transitions, smooth navigation

## Ground Rules

- Build incrementally, phase by phase; no skipped steps
- No placeholder data unless explicitly required for testing, and flag it clearly when you use it
- All features must be real and functional
- Use clean MVVM architecture throughout
- Prioritize performance and scalability
- Implement proper Firebase security rules, and explain them when you add them
- If you hit a decision point that materially affects product direction (e.g., data model tradeoffs, third-party library choices), stop and ask me rather than guessing
