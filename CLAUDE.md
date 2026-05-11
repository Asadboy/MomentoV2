# 10shots - Claude Code Guidelines

## Product

**10shots** (formerly Momento) is an iOS app for time-bound shared photo events. Each member of an event gets exactly **10 shots** during the live window, and all photos are revealed together after the event ends.

- **Display name:** 10shots (CFBundleDisplayName)
- **Internal codebase name:** still `Momento` — folders, target, bundle, and many type names have not been renamed (intentionally deferred — internal-only, not user-facing).
- **No premium tier at launch.** The previous Momento monetisation (premium events, IAP) has been removed. Future tiered pricing is planned via `events.member_limit` (5/10/25). Do not reintroduce `is_premium`, `expires_at`, or any premium-related fields.

### Core concepts

- **Event** — a time-bound gathering. Replaces the old "momento" terminology in all user-facing copy.
- **Shot** — a photo. Each member can take up to 10 per event. Replaces "photo" in user-facing copy (internal variables/types may still say `photo`).
- **Member** — a user who has joined an event.

### Event state machine (3 states)

Defined in `Momento/Models/Event.swift`:

- `upcoming` — `now < startsAt`
- `live` — `startsAt <= now < endsAt` (members can take shots)
- `revealed` — `now >= endsAt` (covers both the gap before `releaseAt` shown as "Reveals in X" and the post-reveal gallery)

There is **no** `processing` or `readyToReveal` state — these were removed in the rebrand. Don't add them back.

### Lobby hero (the core UI)

The active event dominates the screen as a single **`EventHeroView`** (not a grid). Each member is one equal-weight row — avatar + 10 dots representing shots taken. Names were dropped in favour of bigger dots; the current user is pinned to the top with no other distinction. `EventCard` and `PremiumEventCard` are gone (the former still exists for legacy previews but isn't used by ContentView).

Member shot counts are fetched via `SupabaseManager.getEventMembersWithShots()` and refreshed by 10s polling during live events. When nothing is live, polling drops to every 30s (skip-2/3-ticks throttle) to save battery.

## Architecture

The home screen was extracted from a 892-line god-class `ContentView` into a layered architecture:

```
App/
  ContentView.swift             ~200 lines — composes store + router + section views
Features/Home/
  HomeHeader.swift              top bar (wordmark + QR + profile)
  EmptyHomeView.swift           "Start your first event" landing
  ActiveEventsSection.swift     CURRENT EVENTS section header + ForEach
  PastEventsSection.swift       PAST EVENTS section header + ForEach
  UploadFailureBanner.swift     slim banner shown when sync.failedCount > 0
Services/
  EventStore.swift              @MainActor ObservableObject — owns data + side effects
  HomeRouter.swift              @MainActor ObservableObject — owns presentation state
  MomentoAPI.swift              protocol the EventStore depends on (instead of SupabaseManager directly)
  SupabaseManager.swift         core: client, session, auth
  SupabaseManager+Profile.swift profile CRUD + getProfileStats
  SupabaseManager+Events.swift  create/join/lookup/CRUD
  SupabaseManager+Members.swift member count + people-dots roster
  SupabaseManager+Photos.swift  upload/fetch/count/moderate
  SupabaseManager+Likes.swift   like/unlike + counts
  SupabaseDTOs.swift            wire DTOs (UserProfile, EventModel, EventMember, PhotoModel, PhotoLike)
  CrashReporter.swift           Sentry wrapper — start() in MomentoApp.init
  NotificationManager.swift     local notifications for "your reveal is ready"
  OfflineSyncManager.swift      photo upload queue + retry + auto-retry on network restore
  AnalyticsManager.swift        PostHog wrapper, includes trackError(kind:error:context:)
Models/
  Event.swift                   domain event + state machine
  HydratedEvent.swift           Event + members + counts + reveal state, replaces 7 dicts
  MemberWithShots.swift         lobby roster row model
  PhotoData.swift               reveal-UI photo model
  ProfileStats.swift            profile-screen aggregates
```

### Key abstractions

- **`MomentoAPI` protocol** — the only data dependency EventStore knows about. `SupabaseManager` conforms via extension. Tests pass a `MockMomentoAPI`. Adding a new API surface means: add to the protocol, conform from `SupabaseManager+<Domain>.swift`.
- **`HydratedEvent`** — bundles an Event with all its per-event state in one struct. Replaces the previous "seven parallel dicts keyed by event id" pattern. Mutate via `EventStore.updateHydrated(id) { h in ... }`.
- **`HomeRouter`** — two enums (`HomeSheet`, `HomeCover`) for presentation state, plus `handleEventTap` for routing. ContentView's sheet/cover plumbing is a single `HomePresentations` ViewModifier driven from the router.

## Testing

- **Unit tests live in `MomentoTests/`.** Run on every PR via GitHub Actions (`.github/workflows/tests.yml`).
- `MockMomentoAPI` is the standard test fixture for `EventStore` — configure responses, drive scenarios, assert state. See `MomentoTests/EventStoreTests.swift` for the pattern.
- **CI uses `-only-testing:MomentoTests/EventStoreTests`** to skip the scaffold class and the UI test target (UI tests time out on macos-15 runners — AX initialization fails).
- DerivedData is cached on `Package.resolved + project.pbxproj` hash. Cold runs are slow (~10 min); cache hits finish in 3–5 min.

### Adding tests

1. New file under `MomentoTests/` (register in `project.pbxproj` under the `MomentoTests` group and the `MomentoTests` build phase).
2. `@testable import Momento` to reach internal types.
3. For anything async, mark the class or method `@MainActor` (EventStore is `@MainActor`).
4. Time-coupled behaviour (the 2-second join glow, the 3-second post-upload reconciliation) is not yet testable cleanly — would need a scheduler injection. Skip for now.

## Build & Compile Verification

- **`xcodebuild build` against the iOS simulator is allowed and encouraged** after non-trivial Swift changes — catch errors before the developer's next device build. Filter output aggressively (`grep -E "error:|BUILD"`) to avoid burning context on the verbose default output.
- **Do not run the app in the simulator unless explicitly asked.** Don't use it as a substitute for device testing. The developer builds and runs on a physical iPhone for actual feature verification (multi-device flows, camera, auth, push, performance). For UI changes, describe what to test on device rather than claiming it works.
- **CI test runs cost 3–5 min per push.** If a change is build-verified locally, opening the PR and letting CI run the tests is fine — don't burn 5 minutes locally first.

## Backend (Supabase)

- Project: **Momento** (`thnbjfcmawwaxvihggjm`, eu-west-1)
- Schema in `Supabase/migrations/`. The `events` table columns are: `id, name, creator_id, join_code, release_at, created_at, starts_at, ends_at, is_deleted, member_limit`.
- `member_count` / `photo_count` are **not** columns — they're hydrated client-side via `getEventMemberCount` / `getEventPhotoCount` and stored on the `Event` struct only.
- When changing the schema, prefer creating a new file under `Supabase/migrations/` and apply it via the Supabase MCP (`apply_migration`).
- RLS gotcha: cross-table subqueries in policies can deadlock when chained (events ↔ event_members). See `20260511150000_drop_cross_table_cap_from_rls.sql` for the history. Prefer SECURITY DEFINER functions or BEFORE INSERT triggers for cap enforcement.

## Error handling

- **User-facing errors surface via `EventStore.errorMessage` or `SupabaseManager.lastAuthError`** — both are `@Published`, both feed into ContentView's alert binding.
- **Operationally important errors also fire `AnalyticsManager.shared.trackError(kind:error:context:)`** so we can see error rates in PostHog without waiting for user reports.
- **Crashes and uncaught exceptions go to Sentry** via `CrashReporter`. Init in `MomentoApp.init`; no-op if `SENTRY_DSN` is missing (dev/CI builds).
- **Upload failures surface via `UploadFailureBanner`** at the top of home when `OfflineSyncManager.failedCount > 0`. Banner has a Retry button (rate-limited to 15s).

## File Organization

### Folder Structure
- `App/` — Entry point and root navigation (`MomentoApp.swift`, `ContentView.swift`)
- `Features/<FeatureName>/` — Feature-specific views organized by domain:
  - `Auth/` — Authentication and user setup
  - `Camera/` — Camera and shot capture (includes `Filters/` subfolder)
  - `Events/` — Event listing, creation, joining (includes `CreateMomento/` subfolder — name preserved)
  - `Gallery/` — Liked / past-event galleries
  - `Home/` — Home screen section views (HomeHeader, EmptyHomeView, ActiveEventsSection, PastEventsSection, UploadFailureBanner)
  - `Profile/` — User profile and settings
  - `Reveal/` — Reveal experience
- `Services/` — All manager classes (`*Manager.swift`), protocol definitions, Supabase domain extensions, CrashReporter, NotificationManager
- `Models/` — Domain models (Event, HydratedEvent, MemberWithShots, PhotoData, ProfileStats) and utilities
- `Components/` — Reusable UI components
- `Config/` — Configuration files (SupabaseConfig, PostHogConfig, SentryConfig, PhotoLimitConfig)

### Adding New Files
When creating new Swift files:
1. Place the file in the appropriate folder on disk following the structure above
2. **Always update the Xcode project** by editing `Momento.xcodeproj/project.pbxproj`:
   - Add a PBXFileReference entry for the file
   - Add the file to the appropriate PBXGroup
   - Add the file to the PBXSourcesBuildPhase
3. New features get their own folder under `Features/`
4. Reusable UI goes in `Components/`, business logic in `Services/`
5. Test files go under `MomentoTests/` (registered in the `MomentoTests` group + build phase, not the main one)

### Adding a new Swift Package dependency

The project uses SPM via the Xcode project (not a `Package.swift`). To add a dependency:
1. Add `XCRemoteSwiftPackageReference` entry to `project.pbxproj`
2. Add `XCSwiftPackageProductDependency` for each product you want to use
3. Reference the product in the target's `packageProductDependencies` array
4. Reference the build file in the `Frameworks` build phase
5. The first build downloads the SDK and writes `Package.resolved`

The Sentry SDK addition (PR #19) and the original PostHog addition are good references for the exact byte pattern.

## Secrets

`Secrets.xcconfig` (gitignored) holds:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `POSTHOG_API_KEY`, `POSTHOG_HOST`
- `SENTRY_DSN`

CI generates a stub `Secrets.xcconfig` with placeholder values so the build succeeds without exposing real secrets. The `Config/*.swift` files all degrade gracefully if their corresponding value isn't set (Sentry returns empty DSN → CrashReporter no-ops; PostHog returns empty key → analytics no-ops).

`Secrets.example.xcconfig` should exist as the documented template but is currently missing (see `SupabaseConfig.swift` which references it in its fatalError).

## Terminology in code

- User-facing strings: use **event**, **shot**, **10shots**. Never "momento" or "photo" in copy.
- Internal identifiers (types, variables, file names, debug logs that aren't user-visible): existing `Momento`/`photo` names are kept to avoid churn. Don't rename them as part of unrelated work.

## Launch state

See `BACKLOG.md` for the live list. Today's high-priority unblocked items:
- In-app account deletion (Apple 5.1.1(v))
- Privacy policy + terms URLs
- App icon
- Sentry DSN paste-in
- Beta data wipe
- App Store submission materials (drafts in `Docs/launch/`)
