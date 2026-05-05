# 10shots - Claude Code Guidelines

## Product

**10shots** (formerly Momento) is an iOS app for time-bound shared photo events. Each member of an event gets exactly **10 shots** during the live window, and all photos are revealed together after the event ends.

- **Display name:** 10shots (CFBundleDisplayName)
- **Internal codebase name:** still `Momento` — folders, target, bundle, and many type names have not been renamed (intentionally deferred — internal-only, not user-facing).
- **No premium tier.** The previous Momento monetisation (premium events, IAP) has been removed. Do not reintroduce `is_premium`, `expires_at`, or any premium-related fields.

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

### People-dots card (the core UI)

The active event dominates the screen as a single `EventCard` (not a grid). It shows each member as a row with avatar + name + 10 dots representing shots taken. `PremiumEventCard` has been removed — `EventCard` is the only event card.

Member shot counts are fetched via `SupabaseManager.getEventMembersWithShots()` and refreshed by 10s polling during live events.

## Backend (Supabase)

- Project: **Momento** (`thnbjfcmawwaxvihggjm`, eu-west-1)
- Schema in `Supabase/migrations/`. The `events` table columns are: `id, name, creator_id, join_code, release_at, created_at, starts_at, ends_at, is_deleted, member_limit`.
- `member_count` / `photo_count` are **not** columns — they're hydrated client-side via `getEventMemberCount` / `getEventPhotoCount` and stored on the `Event` struct only.
- When changing the schema, prefer creating a new file under `Supabase/migrations/` and apply it via the Supabase MCP (`apply_migration`).

## Build & Testing

- **Never run xcodebuild, simulators, or automated builds.** The developer builds locally on a physical iPhone. Do not suggest or attempt simulator-based verification.
- For UI changes, describe what to test on device rather than claiming it works.

## File Organization

### Folder Structure
- `App/` — Entry point and root navigation (`MomentoApp.swift`, `ContentView.swift`)
- `Features/<FeatureName>/` — Feature-specific views organized by domain:
  - `Auth/` — Authentication and user setup
  - `Camera/` — Camera and shot capture (includes `Filters/` subfolder)
  - `Events/` — Event listing, creation, joining (includes `CreateMomento/` subfolder — name preserved)
  - `Gallery/` — Liked / past-event galleries
  - `Profile/` — User profile and settings
  - `Reveal/` — Reveal experience
- `Services/` — All manager classes (`*Manager.swift`)
- `Models/` — Data models and utilities
- `Components/` — Reusable UI components
- `Config/` — Configuration files

### Adding New Files
When creating new Swift files:
1. Place the file in the appropriate folder on disk following the structure above
2. **Always update the Xcode project** by editing `Momento.xcodeproj/project.pbxproj`:
   - Add a PBXFileReference entry for the file
   - Add the file to the appropriate PBXGroup
   - Add the file to the PBXSourcesBuildPhase
3. New features get their own folder under `Features/`
4. Reusable UI goes in `Components/`, business logic in `Services/`

## Terminology in code

- User-facing strings: use **event**, **shot**, **10shots**. Never "momento" or "photo" in copy.
- Internal identifiers (types, variables, file names, debug logs that aren't user-visible): existing `Momento`/`photo` names are kept to avoid churn. Don't rename them as part of unrelated work.
