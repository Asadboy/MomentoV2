# Model Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update all Swift models and SupabaseManager to match the new v1 5-table schema.

**Architecture:** Models in SupabaseManager.swift get simplified to match 5 tables (profiles, events, event_members, photos, photo_likes). Local Event model in Event.swift gets updated to match. Keepsake and reveal progress models are removed entirely. `photo_interactions` replaced with `photo_likes`.

**Tech Stack:** Swift, Supabase Swift SDK

---

### Task 1: Update UserProfile model

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift:1194-1217`

**Step 1: Replace UserProfile struct**

Replace the existing `UserProfile` struct with:

```swift
struct UserProfile: Codable {
    let id: UUID
    let username: String
    var displayName: String?
    var avatarUrl: String?
    var deviceToken: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case deviceToken = "device_token"
        case createdAt = "created_at"
    }
}
```

Removed: `firstName`, `lastName`, `isPremium`, `totalEventsJoined`, `updatedAt`
Added: `deviceToken`

**Step 2: Fix UserProfile instantiation in createUserProfile()**

Find the `createUserProfile` function (around line 191) and update the instantiation to remove dropped fields. The insert should only include fields that exist in the new schema.

**Step 3: Fix any views referencing removed UserProfile fields**

Check `ProfileView.swift`, `SettingsView.swift`, `AuthenticationRootView.swift`, `CreateMomentoFlow.swift` for references to `firstName`, `lastName`, `isPremium`, `totalEventsJoined`, `updatedAt` on UserProfile and remove them.

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: simplify UserProfile model to match v1 schema"
```

---

### Task 2: Update EventModel and Event

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift:1220-1248`
- Modify: `Momento/Models/Event.swift`

**Step 1: Replace EventModel struct**

```swift
struct EventModel: Codable, Identifiable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let joinCode: String
    let startsAt: Date
    let endsAt: Date
    let releaseAt: Date
    var isPremium: Bool
    var isDeleted: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorId = "creator_id"
        case joinCode = "join_code"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case releaseAt = "release_at"
        case isPremium = "is_premium"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
    }
}
```

Removed: `title` (renamed to `name`), `isRevealed`, `memberCount`, `photoCount`
Added: `isPremium`

**Step 2: Update local Event struct in Event.swift**

```swift
struct Event: Identifiable, Hashable {
    let id: String
    var name: String
    var coverEmoji: String
    var startsAt: Date
    var endsAt: Date
    var releaseAt: Date
    var isPremium: Bool
    var joinCode: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        coverEmoji: String,
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        isPremium: Bool = false,
        joinCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coverEmoji = coverEmoji
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.releaseAt = releaseAt
        self.isPremium = isPremium
        self.joinCode = joinCode
    }

    enum State {
        case upcoming
        case live
        case processing
        case revealed
    }

    func currentState(at now: Date = .now) -> State {
        if now >= releaseAt {
            return .revealed
        } else if now >= endsAt {
            return .processing
        } else if now >= startsAt {
            return .live
        } else {
            return .upcoming
        }
    }
}
```

Removed: `title` (renamed to `name`), `memberCount`, `photosTaken`, `isRevealed`
Added: `isPremium`
Changed: `currentState` no longer checks `isRevealed`, just uses time-based logic.

**Step 3: Update Supabase bridge in Event.swift**

```swift
extension Event {
    init(fromSupabase eventModel: EventModel) {
        self.init(
            id: eventModel.id.uuidString,
            name: eventModel.name,
            coverEmoji: "\u{1F4F8}",
            startsAt: eventModel.startsAt,
            endsAt: eventModel.endsAt,
            releaseAt: eventModel.releaseAt,
            isPremium: eventModel.isPremium,
            joinCode: eventModel.joinCode
        )
    }
}
```

**Step 4: Update makeFakeEvents()**

Update all sample events to use `name:` instead of `title:`, remove `memberCount:` and `photosTaken:` params, add `isPremium:` where needed.

**Step 5: Fix all `.title` references across views**

Every file that uses `event.title` needs to change to `event.name`. Key files:
- `EventPreviewModal.swift`
- `PremiumEventCard.swift`
- `PhotoGalleryView.swift`
- `LikedGalleryView.swift`
- `InviteSheet.swift`
- `JoinEventSheet.swift`
- `EventRow.swift`
- `PhotoCaptureSheet.swift`
- `CreateMomentoFlow.swift`
- `FeedRevealView.swift`

**Step 6: Fix all `.memberCount` and `.photosTaken` references**

These are no longer stored on the Event model. They need to be fetched as computed counts from the database. For now, remove direct references and update views to fetch counts separately or remove the display.

Key files:
- `EventPreviewModal.swift`
- `EventRow.swift`
- `PremiumEventCard.swift`
- `InviteSheet.swift`
- `FeedRevealView.swift`

**Step 7: Fix all `.isRevealed` references**

Event state is now purely time-based. Remove any checks for `.isRevealed` on Event and replace with `currentState(at:) == .revealed`.

**Step 8: Commit**

```bash
git add -A && git commit -m "refactor: rename Event.title to .name, remove stored counts and isRevealed"
```

---

### Task 3: Update EventMember model

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift:1250-1266`

**Step 1: Replace EventMember struct**

```swift
struct EventMember: Codable {
    let eventId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}
```

Removed: `id` (composite PK now), `invitedBy`, `role`
Removed: `Identifiable` conformance (no single `id` field)

**Step 2: Fix any code that references `EventMember.id`, `.invitedBy`, or `.role`**

**Step 3: Commit**

```bash
git add -A && git commit -m "refactor: simplify EventMember model to composite key"
```

---

### Task 4: Update PhotoModel

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift:1268-1288`

**Step 1: Replace PhotoModel struct**

```swift
struct PhotoModel: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    let capturedAt: Date
    var username: String
    var width: Int?
    var height: Int?
    var uploadStatus: String
    var isFlagged: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case username
        case width
        case height
        case uploadStatus = "upload_status"
        case isFlagged = "is_flagged"
    }
}
```

Removed: `capturedByUsername` (renamed to `username`), `isRevealed`
Added: `width`, `height`, `isFlagged`

**Step 2: Fix all `.capturedByUsername` references**

Change to `.username` in SupabaseManager queries and any view code.

**Step 3: Fix all `.isRevealed` references on PhotoModel**

Remove these - photos don't track reveal state individually anymore.

**Step 4: Update photo upload code to include width/height**

In the `uploadPhoto` function, pass image dimensions when creating the PhotoModel.

**Step 5: Commit**

```bash
git add -A && git commit -m "refactor: update PhotoModel with username rename, dimensions, flagging"
```

---

### Task 5: Replace PhotoInteraction with PhotoLike

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift`

**Step 1: Remove InteractionStatus enum, PhotoInteraction struct**

Delete lines 1299-1319.

**Step 2: Add PhotoLike struct**

```swift
struct PhotoLike: Codable {
    let photoId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
```

**Step 3: Update setPhotoInteraction → likePhoto/unlikePhoto**

Replace the single `setPhotoInteraction(photoId:status:)` with two functions:

```swift
func likePhoto(photoId: UUID) async throws {
    guard let userId = currentUserId else { return }
    try await supabase
        .from("photo_likes")
        .insert(["photo_id": photoId.uuidString, "user_id": userId.uuidString])
        .execute()
}

func unlikePhoto(photoId: UUID) async throws {
    guard let userId = currentUserId else { return }
    try await supabase
        .from("photo_likes")
        .delete()
        .eq("photo_id", value: photoId.uuidString)
        .eq("user_id", value: userId.uuidString)
        .execute()
}
```

**Step 4: Update getLikedPhotos()**

Change from querying `photo_interactions` with `status = 'liked'` to querying `photo_likes` table.

**Step 5: Update getLikedPhotoCount()**

Same - query `photo_likes` instead of `photo_interactions`.

**Step 6: Remove getArchivedPhotos()**

Archive feature is removed in v1.

**Step 7: Update callers**

- `LikedGalleryView.swift` - change `setPhotoInteraction(photoId:status:.liked)` to `likePhoto(photoId:)`
- `FeedRevealView.swift` - same change
- Remove any archive tab/toggle in gallery views

**Step 8: Commit**

```bash
git add -A && git commit -m "refactor: replace photo_interactions with photo_likes"
```

---

### Task 6: Remove keepsake and reveal progress models

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift`
- Modify: `Momento/Features/Profile/ProfileView.swift`

**Step 1: Delete model structs**

Remove from SupabaseManager.swift:
- `UserRevealProgress` struct
- `Keepsake` struct
- `UserKeepsake` struct
- `EarnedKeepsake` struct

**Step 2: Delete keepsake functions from SupabaseManager**

Remove:
- `getUserKeepsakes()`
- `hasKeepsakeForEvent()`
- Any reveal progress functions (`getRevealProgress`, `updateRevealProgress`)

**Step 3: Remove keepsake references from ProfileView**

Remove `keepsakes` state, `selectedKeepsake` state, keepsake grid section, and keepsake fetch calls.

**Step 4: Do NOT delete keepsake view files yet**

Leave `KeepsakeRevealView.swift`, `KeepsakeGridView.swift`, `KeepsakeDetailModal.swift` in place for now - they'll be dead code but removing them requires pbxproj changes. Note them for cleanup later.

**Step 5: Commit**

```bash
git add -A && git commit -m "refactor: remove keepsake and reveal progress models (deferred to post-v1)"
```

---

### Task 7: Update ProfileStats and getProfileStats()

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift`

**Step 1: Simplify ProfileStats**

```swift
struct ProfileStats {
    let eventsJoined: Int
    let photosTaken: Int
    let photosLiked: Int
    let userNumber: Int
}
```

**Step 2: Rewrite getProfileStats()**

Replace the current 13+ sequential queries with simpler counts:

```swift
func getProfileStats() async throws -> ProfileStats {
    guard let userId = currentUserId else {
        throw NSError(domain: "MomentoError", code: 401)
    }

    let eventsJoined = try await supabase
        .from("event_members")
        .select("*", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .execute()
        .count ?? 0

    let photosTaken = try await supabase
        .from("photos")
        .select("*", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .execute()
        .count ?? 0

    let photosLiked = try await supabase
        .from("photo_likes")
        .select("*", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .execute()
        .count ?? 0

    let userCreatedAt = try await supabase
        .from("profiles")
        .select("created_at")
        .eq("id", value: userId.uuidString)
        .single()
        .execute()
    // decode and count profiles with created_at <= this user's

    return ProfileStats(
        eventsJoined: eventsJoined,
        photosTaken: photosTaken,
        photosLiked: photosLiked,
        userNumber: userNumber
    )
}
```

**Step 3: Update StatsGridView.swift and ProfileView.swift**

Update to use new ProfileStats fields (`eventsJoined`, `photosTaken`, `photosLiked`, `userNumber`).

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: simplify ProfileStats to use count queries"
```

---

### Task 8: Update SupabaseManager query functions

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift`

**Step 1: Update createEvent()**

- Change parameter `title` to `name`
- Add `ends_at` to the insert (auto-calculated: starts_at + 12hrs)
- Add `release_at` auto-calculation (ends_at + 12hrs)
- Remove `member_count`, `photo_count`, `is_revealed` from insert
- Add `is_premium` to insert (default false)

**Step 2: Update all EventModel select queries**

Remove selecting `is_revealed`, `member_count`, `photo_count` columns. The Supabase SDK will error if these columns don't exist in the database.

**Step 3: Update uploadPhoto()**

- Change `captured_by_username` to `username` in insert
- Add `width` and `height` to insert
- Add `is_flagged` default to insert
- Remove `is_revealed` from insert

**Step 4: Add helper functions for computed counts**

```swift
func getEventMemberCount(eventId: UUID) async throws -> Int {
    try await supabase
        .from("event_members")
        .select("*", head: true, count: .exact)
        .eq("event_id", value: eventId.uuidString)
        .execute()
        .count ?? 0
}

func getEventPhotoCount(eventId: UUID) async throws -> Int {
    try await supabase
        .from("photos")
        .select("*", head: true, count: .exact)
        .eq("event_id", value: eventId.uuidString)
        .execute()
        .count ?? 0
}
```

**Step 5: Commit**

```bash
git add -A && git commit -m "refactor: update SupabaseManager queries for v1 schema"
```

---

### Task 9: Update local photo models in Event.swift

**Files:**
- Modify: `Momento/Models/Event.swift`

**Step 1: Update PhotoMetadata**

Remove `isRevealed` field.

```swift
struct PhotoMetadata: Codable {
    let photoID: String
    let eventID: String
    let capturedAt: Date
    var capturedBy: String?
}
```

**Step 2: Update EventPhoto**

Remove `isRevealed` field.

```swift
struct EventPhoto: Identifiable {
    let id: String
    let eventID: String
    let fileURL: URL
    let capturedAt: Date
    var capturedBy: String?
    var image: UIImage?
}
```

**Step 3: Fix PhotoStorageManager references**

Update any code that reads/writes `isRevealed` on PhotoMetadata or EventPhoto.

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: remove isRevealed from local photo models"
```
