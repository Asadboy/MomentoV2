# User Profile & Keepsakes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the settings screen into a personal memory vault with stats and keepsakes.

**Architecture:** SwiftUI views with SupabaseManager for data fetching. New database tables for keepsakes, new Swift models, and a redesigned ProfileView replacing SettingsView.

**Tech Stack:** SwiftUI, Supabase (PostgreSQL + Swift SDK)

---

## Task 1: Database Migration - Keepsakes Tables

**Files:**
- Create: `Supabase/migrations/20260125100000_add_keepsakes.sql`

**Step 1: Write the migration SQL**

```sql
-- Keepsakes Migration
-- Adds keepsakes and user_keepsakes tables for the profile feature

-- ============================================
-- KEEPSAKES TABLE (definitions)
-- ============================================
CREATE TABLE public.keepsakes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    artwork_url TEXT NOT NULL,
    flavour_text TEXT NOT NULL,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- USER KEEPSAKES TABLE (earned keepsakes)
-- ============================================
CREATE TABLE public.user_keepsakes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    keepsake_id UUID NOT NULL REFERENCES keepsakes(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, keepsake_id)
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_user_keepsakes_user_id ON user_keepsakes(user_id);
CREATE INDEX idx_keepsakes_event_id ON keepsakes(event_id);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================
ALTER TABLE keepsakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_keepsakes ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Anyone can view keepsake definitions (needed for rarity calculation)
CREATE POLICY "Anyone can view keepsakes"
    ON keepsakes FOR SELECT
    USING (true);

-- Users can only view their own earned keepsakes
CREATE POLICY "Users can view own keepsakes"
    ON user_keepsakes FOR SELECT
    USING ((SELECT auth.uid()) = user_id);

-- Only service role can insert/manage keepsakes (admin function)
-- No INSERT policy = only service role can insert

-- ============================================
-- SEED INITIAL KEEPSAKES
-- ============================================
INSERT INTO keepsakes (name, artwork_url, flavour_text, event_id) VALUES
    ('Lakes', 'keepsakes/lakes.png', 'Some moments are worth waiting 3 years for.', NULL),
    ('Sopranos', 'keepsakes/sopranos.png', 'Made member of the first family.', NULL),
    ('Hijack x DoubleDip', 'keepsakes/hijack-doubledip.png', 'On board from the start. London.', NULL);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Keepsakes tables created successfully!';
END $$;
```

**Step 2: Verify file created**

Check that the file exists at the correct path.

**Step 3: Commit**

```bash
git add Supabase/migrations/20260125100000_add_keepsakes.sql
git commit -m "feat(db): add keepsakes tables migration"
```

---

## Task 2: Swift Models - Keepsake & UserKeepsake

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift` (add models at bottom, around line 1065)

**Step 1: Add Keepsake model**

Add after the `UserRevealProgress` struct (around line 1065):

```swift
// MARK: - Keepsake Models

/// A keepsake definition (badge/collectible)
struct Keepsake: Codable, Identifiable {
    let id: UUID
    let name: String
    let artworkUrl: String
    let flavourText: String
    let eventId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artworkUrl = "artwork_url"
        case flavourText = "flavour_text"
        case eventId = "event_id"
        case createdAt = "created_at"
    }
}

/// A user's earned keepsake
struct UserKeepsake: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let keepsakeId: UUID
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case keepsakeId = "keepsake_id"
        case earnedAt = "earned_at"
    }
}

/// Combined keepsake with earning info for display
struct EarnedKeepsake: Identifiable {
    let id: UUID
    let keepsake: Keepsake
    let earnedAt: Date
    let rarityPercentage: Double
}
```

**Step 2: Verify models compile**

Build the project in Xcode to verify no syntax errors.

**Step 3: Commit**

```bash
git add Momento/Services/SupabaseManager.swift
git commit -m "feat(models): add Keepsake and UserKeepsake models"
```

---

## Task 3: Swift Models - ProfileStats

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift` (add after Keepsake models)

**Step 1: Add ProfileStats model**

```swift
/// User profile statistics for display
struct ProfileStats {
    // Activity stats
    let momentsCaptured: Int
    let photosLoved: Int
    let revealsCompleted: Int
    let momentosShared: Int

    // Journey stats
    let firstMomentoDate: Date?
    let friendsCapturedWith: Int
    let mostActiveMomento: String?
    let mostRecentMomento: String?

    // Identity
    let userNumber: Int
}
```

**Step 2: Commit**

```bash
git add Momento/Services/SupabaseManager.swift
git commit -m "feat(models): add ProfileStats model"
```

---

## Task 4: SupabaseManager - Keepsake Queries

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift` (add new MARK section before models)

**Step 1: Add keepsake fetch methods**

Add after the Reveal Progress section (around line 916):

```swift
// MARK: - Keepsakes

/// Get all keepsakes the user has earned
func getUserKeepsakes() async throws -> [EarnedKeepsake] {
    guard let userId = currentUser?.id else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    // Get user's earned keepsakes
    let userKeepsakes: [UserKeepsake] = try await client
        .from("user_keepsakes")
        .select()
        .eq("user_id", value: userId.uuidString)
        .execute()
        .value

    if userKeepsakes.isEmpty {
        return []
    }

    // Get keepsake definitions
    let keepsakeIds = userKeepsakes.map { $0.keepsakeId.uuidString }
    let keepsakes: [Keepsake] = try await client
        .from("keepsakes")
        .select()
        .in("id", values: keepsakeIds)
        .execute()
        .value

    // Get total user count for rarity calculation
    let totalUsersResponse = try await client
        .from("profiles")
        .select("id", head: true, count: .exact)
        .execute()
    let totalUsers = max(totalUsersResponse.count ?? 1, 1)

    // Get count of users who have each keepsake
    var earnedKeepsakes: [EarnedKeepsake] = []

    for userKeepsake in userKeepsakes {
        guard let keepsake = keepsakes.first(where: { $0.id == userKeepsake.keepsakeId }) else {
            continue
        }

        // Count users with this keepsake
        let countResponse = try await client
            .from("user_keepsakes")
            .select("id", head: true, count: .exact)
            .eq("keepsake_id", value: keepsake.id.uuidString)
            .execute()
        let usersWithKeepsake = countResponse.count ?? 1

        let rarityPercentage = (Double(usersWithKeepsake) / Double(totalUsers)) * 100

        earnedKeepsakes.append(EarnedKeepsake(
            id: userKeepsake.id,
            keepsake: keepsake,
            earnedAt: userKeepsake.earnedAt,
            rarityPercentage: rarityPercentage
        ))
    }

    return earnedKeepsakes.sorted { $0.earnedAt > $1.earnedAt }
}

/// Check if user has a keepsake for a specific event
func hasKeepsakeForEvent(eventId: UUID) async throws -> EarnedKeepsake? {
    guard let userId = currentUser?.id else {
        return nil
    }

    // Find keepsake linked to this event
    let keepsakes: [Keepsake] = try await client
        .from("keepsakes")
        .select()
        .eq("event_id", value: eventId.uuidString)
        .execute()
        .value

    guard let keepsake = keepsakes.first else {
        return nil
    }

    // Check if user has earned it
    let userKeepsakes: [UserKeepsake] = try await client
        .from("user_keepsakes")
        .select()
        .eq("user_id", value: userId.uuidString)
        .eq("keepsake_id", value: keepsake.id.uuidString)
        .execute()
        .value

    guard let userKeepsake = userKeepsakes.first else {
        return nil
    }

    // Get rarity
    let totalUsersResponse = try await client
        .from("profiles")
        .select("id", head: true, count: .exact)
        .execute()
    let totalUsers = max(totalUsersResponse.count ?? 1, 1)

    let countResponse = try await client
        .from("user_keepsakes")
        .select("id", head: true, count: .exact)
        .eq("keepsake_id", value: keepsake.id.uuidString)
        .execute()
    let usersWithKeepsake = countResponse.count ?? 1

    let rarityPercentage = (Double(usersWithKeepsake) / Double(totalUsers)) * 100

    return EarnedKeepsake(
        id: userKeepsake.id,
        keepsake: keepsake,
        earnedAt: userKeepsake.earnedAt,
        rarityPercentage: rarityPercentage
    )
}
```

**Step 2: Commit**

```bash
git add Momento/Services/SupabaseManager.swift
git commit -m "feat(api): add keepsake fetch methods"
```

---

## Task 5: SupabaseManager - Profile Stats Queries

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift` (add after keepsake methods)

**Step 1: Add profile stats method**

```swift
// MARK: - Profile Stats

/// Get all stats for the user's profile
func getProfileStats() async throws -> ProfileStats {
    guard let userId = currentUser?.id else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    // Get user profile for created_at (user number calculation)
    let profile = try await getUserProfile(userId: userId)

    // 1. Moments captured (photos taken)
    let photosResponse = try await client
        .from("photos")
        .select("id", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .execute()
    let momentsCaptured = photosResponse.count ?? 0

    // 2. Photos loved (liked interactions)
    let likedResponse = try await client
        .from("photo_interactions")
        .select("id", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .eq("status", value: "liked")
        .execute()
    let photosLoved = likedResponse.count ?? 0

    // 3. Reveals completed
    let revealsResponse = try await client
        .from("user_reveal_progress")
        .select("id", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .eq("completed", value: true)
        .execute()
    let revealsCompleted = revealsResponse.count ?? 0

    // 4. Momentos shared (events joined)
    let eventsResponse = try await client
        .from("event_members")
        .select("id", head: true, count: .exact)
        .eq("user_id", value: userId.uuidString)
        .execute()
    let momentosShared = eventsResponse.count ?? 0

    // 5. First Momento date
    let firstEventMembers: [EventMember] = try await client
        .from("event_members")
        .select()
        .eq("user_id", value: userId.uuidString)
        .order("joined_at", ascending: true)
        .limit(1)
        .execute()
        .value
    let firstMomentoDate = firstEventMembers.first?.joinedAt

    // 6. Friends captured with (unique co-attendees)
    let myEventMembers: [EventMember] = try await client
        .from("event_members")
        .select()
        .eq("user_id", value: userId.uuidString)
        .execute()
        .value

    let myEventIds = myEventMembers.map { $0.eventId.uuidString }
    var friendsSet = Set<String>()

    if !myEventIds.isEmpty {
        let allMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .in("event_id", values: myEventIds)
            .execute()
            .value

        for member in allMembers where member.userId != userId {
            friendsSet.insert(member.userId.uuidString)
        }
    }
    let friendsCapturedWith = friendsSet.count

    // 7. Most active Momento (event with most photos by user)
    struct PhotoCount: Decodable {
        let eventId: UUID
        let count: Int

        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case count
        }
    }

    // Get photo counts per event for this user
    let userPhotos: [PhotoModel] = try await client
        .from("photos")
        .select()
        .eq("user_id", value: userId.uuidString)
        .execute()
        .value

    var photoCountByEvent: [UUID: Int] = [:]
    for photo in userPhotos {
        photoCountByEvent[photo.eventId, default: 0] += 1
    }

    var mostActiveMomento: String? = nil
    if let topEventId = photoCountByEvent.max(by: { $0.value < $1.value })?.key {
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .eq("id", value: topEventId.uuidString)
            .execute()
            .value
        mostActiveMomento = events.first?.title
    }

    // 8. Most recent Momento
    let recentEventMembers: [EventMember] = try await client
        .from("event_members")
        .select()
        .eq("user_id", value: userId.uuidString)
        .order("joined_at", ascending: false)
        .limit(1)
        .execute()
        .value

    var mostRecentMomento: String? = nil
    if let recentMember = recentEventMembers.first {
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .eq("id", value: recentMember.eventId.uuidString)
            .execute()
            .value
        mostRecentMomento = events.first?.title
    }

    // 9. User number (count of profiles created before this user)
    let userNumberResponse = try await client
        .from("profiles")
        .select("id", head: true, count: .exact)
        .lte("created_at", value: ISO8601DateFormatter().string(from: profile.createdAt))
        .execute()
    let userNumber = userNumberResponse.count ?? 1

    return ProfileStats(
        momentsCaptured: momentsCaptured,
        photosLoved: photosLoved,
        revealsCompleted: revealsCompleted,
        momentosShared: momentosShared,
        firstMomentoDate: firstMomentoDate,
        friendsCapturedWith: friendsCapturedWith,
        mostActiveMomento: mostActiveMomento,
        mostRecentMomento: mostRecentMomento,
        userNumber: userNumber
    )
}
```

**Step 2: Commit**

```bash
git add Momento/Services/SupabaseManager.swift
git commit -m "feat(api): add getProfileStats method"
```

---

## Task 6: StatCardView Component

**Files:**
- Create: `Momento/Profile/StatCardView.swift`

**Step 1: Create the stat card component**

```swift
//
//  StatCardView.swift
//  Momento
//
//  Individual stat card for profile display
//

import SwiftUI

struct StatCardView: View {
    let value: String
    let label: String

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(royalPurple.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            StatCardView(value: "42", label: "Moments captured")
            StatCardView(value: "18", label: "Photos loved")
        }
        .padding()
    }
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/StatCardView.swift
git commit -m "feat(ui): add StatCardView component"
```

---

## Task 7: StatsGridView Component

**Files:**
- Create: `Momento/Profile/StatsGridView.swift`

**Step 1: Create the stats grid component**

```swift
//
//  StatsGridView.swift
//  Momento
//
//  2-column grid of stat cards for profile
//

import SwiftUI

struct StatsGridView: View {
    let stats: ProfileStats

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Activity stats (Core 4)
            StatCardView(
                value: "\(stats.momentsCaptured)",
                label: "Moments captured"
            )

            StatCardView(
                value: "\(stats.photosLoved)",
                label: "Photos loved"
            )

            StatCardView(
                value: "\(stats.revealsCompleted)",
                label: "Reveals completed"
            )

            StatCardView(
                value: "\(stats.momentosShared)",
                label: "Momentos shared"
            )

            // Journey stats (4)
            StatCardView(
                value: stats.firstMomentoDate.map { dateFormatter.string(from: $0) } ?? "—",
                label: "First Momento"
            )

            StatCardView(
                value: "\(stats.friendsCapturedWith)",
                label: "Friends captured with"
            )

            StatCardView(
                value: stats.mostActiveMomento ?? "—",
                label: "Most active Momento"
            )

            StatCardView(
                value: stats.mostRecentMomento ?? "—",
                label: "Most recent Momento"
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            StatsGridView(stats: ProfileStats(
                momentsCaptured: 42,
                photosLoved: 18,
                revealsCompleted: 6,
                momentosShared: 8,
                firstMomentoDate: Date().addingTimeInterval(-90 * 24 * 3600),
                friendsCapturedWith: 23,
                mostActiveMomento: "Sopranos",
                mostRecentMomento: "NYE 2026",
                userNumber: 47
            ))
            .padding()
        }
    }
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/StatsGridView.swift
git commit -m "feat(ui): add StatsGridView component"
```

---

## Task 8: KeepsakeGridView Component

**Files:**
- Create: `Momento/Profile/KeepsakeGridView.swift`

**Step 1: Create the keepsake grid component**

```swift
//
//  KeepsakeGridView.swift
//  Momento
//
//  Grid of keepsake artwork thumbnails
//

import SwiftUI

struct KeepsakeGridView: View {
    let keepsakes: [EarnedKeepsake]
    @Binding var selectedKeepsake: EarnedKeepsake?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(keepsakes) { keepsake in
                KeepsakeThumbnailView(keepsake: keepsake)
                    .onTapGesture {
                        selectedKeepsake = keepsake
                    }
            }
        }
    }
}

struct KeepsakeThumbnailView: View {
    let keepsake: EarnedKeepsake

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        ZStack {
            // Background with glow
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))

            // Keepsake artwork (placeholder for now - will use AsyncImage with artwork_url)
            VStack(spacing: 8) {
                // Placeholder icon based on keepsake name
                keepsakeIcon
                    .font(.system(size: 40))
                    .foregroundColor(.white)

                Text(keepsake.keepsake.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(royalPurple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: royalPurple.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var keepsakeIcon: some View {
        // Temporary placeholder icons based on name
        switch keepsake.keepsake.name.lowercased() {
        case let name where name.contains("lakes"):
            Image(systemName: "mountain.2.fill")
        case let name where name.contains("sopranos"):
            Image(systemName: "crown.fill")
        case let name where name.contains("hijack"):
            Image(systemName: "ferry.fill")
        default:
            Image(systemName: "star.fill")
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        KeepsakeGridView(
            keepsakes: [
                EarnedKeepsake(
                    id: UUID(),
                    keepsake: Keepsake(
                        id: UUID(),
                        name: "Lakes",
                        artworkUrl: "",
                        flavourText: "Some moments are worth waiting 3 years for.",
                        eventId: nil,
                        createdAt: Date()
                    ),
                    earnedAt: Date(),
                    rarityPercentage: 0.3
                ),
                EarnedKeepsake(
                    id: UUID(),
                    keepsake: Keepsake(
                        id: UUID(),
                        name: "Sopranos",
                        artworkUrl: "",
                        flavourText: "Made member of the first family.",
                        eventId: nil,
                        createdAt: Date()
                    ),
                    earnedAt: Date(),
                    rarityPercentage: 0.5
                )
            ],
            selectedKeepsake: .constant(nil)
        )
        .padding()
    }
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/KeepsakeGridView.swift
git commit -m "feat(ui): add KeepsakeGridView component"
```

---

## Task 9: KeepsakeDetailModal Component

**Files:**
- Create: `Momento/Profile/KeepsakeDetailModal.swift`

**Step 1: Create the keepsake detail modal**

```swift
//
//  KeepsakeDetailModal.swift
//  Momento
//
//  Full keepsake details shown when tapping a keepsake
//

import SwiftUI

struct KeepsakeDetailModal: View {
    let keepsake: EarnedKeepsake
    @Environment(\.dismiss) private var dismiss

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Keepsake artwork (large)
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(royalPurple)
                        .blur(radius: 40)
                        .opacity(0.3)
                        .frame(width: 200, height: 200)

                    // Artwork container
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        .frame(width: 160, height: 160)
                        .overlay(
                            keepsakeIcon
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(royalPurple.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: royalPurple.opacity(0.3), radius: 20, x: 0, y: 10)
                }

                // Name
                Text(keepsake.keepsake.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // Flavour text
                Text(keepsake.keepsake.flavourText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Rarity
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(royalPurple)

                    Text(String(format: "%.1f%% of users have this", keepsake.rarityPercentage))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)

                // Earned date
                Text("Earned \(dateFormatter.string(from: keepsake.earnedAt))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var keepsakeIcon: some View {
        switch keepsake.keepsake.name.lowercased() {
        case let name where name.contains("lakes"):
            Image(systemName: "mountain.2.fill")
        case let name where name.contains("sopranos"):
            Image(systemName: "crown.fill")
        case let name where name.contains("hijack"):
            Image(systemName: "ferry.fill")
        default:
            Image(systemName: "star.fill")
        }
    }
}

#Preview {
    KeepsakeDetailModal(keepsake: EarnedKeepsake(
        id: UUID(),
        keepsake: Keepsake(
            id: UUID(),
            name: "Sopranos",
            artworkUrl: "",
            flavourText: "Made member of the first family.",
            eventId: nil,
            createdAt: Date()
        ),
        earnedAt: Date().addingTimeInterval(-30 * 24 * 3600),
        rarityPercentage: 0.5
    ))
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/KeepsakeDetailModal.swift
git commit -m "feat(ui): add KeepsakeDetailModal component"
```

---

## Task 10: ProfileView - Main Screen

**Files:**
- Create: `Momento/Profile/ProfileView.swift`

**Step 1: Create the main profile view**

```swift
//
//  ProfileView.swift
//  Momento
//
//  User profile screen with stats and keepsakes
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared

    @State private var username: String?
    @State private var userNumber: Int?
    @State private var stats: ProfileStats?
    @State private var keepsakes: [EarnedKeepsake] = []
    @State private var selectedKeepsake: EarnedKeepsake?
    @State private var isLoading = true
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header section
                            headerSection

                            // Stats section
                            if let stats = stats {
                                statsSection(stats: stats)
                            }

                            // Keepsakes section (hidden if empty)
                            if !keepsakes.isEmpty {
                                keepsakesSection
                            }

                            Spacer(minLength: 40)

                            // Sign out button
                            signOutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    performLogout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $selectedKeepsake) { keepsake in
                KeepsakeDetailModal(keepsake: keepsake)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 20) {
            // Profile icon with glow
            ZStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(royalPurple)
                    .blur(radius: 15)
                    .opacity(0.5)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
            }

            VStack(spacing: 8) {
                // Username
                if let username = username {
                    Text("@\(username)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // User number
                if let userNumber = userNumber {
                    Text("User #\(userNumber)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Stats Section

    private func statsSection(stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STATS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            StatsGridView(stats: stats)
        }
    }

    // MARK: - Keepsakes Section

    private var keepsakesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KEEPSAKES")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            KeepsakeGridView(
                keepsakes: keepsakes,
                selectedKeepsake: $selectedKeepsake
            )
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 12) {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isLoggingOut ? "Signing Out..." : "Sign Out")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(isLoggingOut)
    }

    // MARK: - Data Loading

    private func loadProfileData() async {
        isLoading = true

        guard let userId = supabaseManager.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            // Load profile
            let profile = try await supabaseManager.getUserProfile(userId: userId)

            // Load stats
            let profileStats = try await supabaseManager.getProfileStats()

            // Load keepsakes
            let earnedKeepsakes = try await supabaseManager.getUserKeepsakes()

            await MainActor.run {
                self.username = profile.username
                self.userNumber = profileStats.userNumber
                self.stats = profileStats
                self.keepsakes = earnedKeepsakes
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load profile: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func performLogout() {
        isLoggingOut = true

        Task {
            do {
                try await supabaseManager.signOut()
                await MainActor.run {
                    isLoggingOut = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoggingOut = false
                    errorMessage = "Failed to sign out: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/ProfileView.swift
git commit -m "feat(ui): add ProfileView main screen"
```

---

## Task 11: Update ContentView to Use ProfileView

**Files:**
- Modify: `Momento/ContentView.swift`

**Step 1: Find and replace SettingsView reference**

Search for `SettingsView` in ContentView and replace with `ProfileView`.

The change should be in the `.sheet` modifier - change:

```swift
.sheet(isPresented: $showSettings) {
    SettingsView()
}
```

To:

```swift
.sheet(isPresented: $showSettings) {
    ProfileView()
}
```

**Step 2: Commit**

```bash
git add Momento/ContentView.swift
git commit -m "feat: replace SettingsView with ProfileView in ContentView"
```

---

## Task 12: KeepsakeRevealView Component

**Files:**
- Create: `Momento/Profile/KeepsakeRevealView.swift`

**Step 1: Create the keepsake reveal animation view**

```swift
//
//  KeepsakeRevealView.swift
//  Momento
//
//  Full-screen keepsake reveal animation after completing a reveal
//

import SwiftUI

struct KeepsakeRevealView: View {
    let keepsake: EarnedKeepsake
    let onDismiss: () -> Void
    let onViewProfile: () -> Void

    @State private var showCard = false
    @State private var showName = false
    @State private var showFlavourText = false
    @State private var showRarity = false
    @State private var showButton = false
    @State private var cardRotation: Double = 180

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                Spacer()

                // Title
                Text("You earned a keepsake!")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showCard ? 1 : 0)

                // Keepsake card with flip animation
                ZStack {
                    // Glow
                    Circle()
                        .fill(royalPurple)
                        .blur(radius: 60)
                        .opacity(showCard ? 0.4 : 0)
                        .frame(width: 250, height: 250)

                    // Card back (shown first)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [royalPurple, Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .rotation3DEffect(.degrees(cardRotation - 180), axis: (x: 0, y: 1, z: 0))
                        .opacity(cardRotation > 90 ? 1 : 0)

                    // Card front (revealed)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        .frame(width: 180, height: 180)
                        .overlay(
                            keepsakeIcon
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(royalPurple.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: royalPurple.opacity(0.4), radius: 20, x: 0, y: 10)
                        .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
                        .opacity(cardRotation <= 90 ? 1 : 0)
                }
                .scaleEffect(showCard ? 1 : 0.5)
                .opacity(showCard ? 1 : 0)

                // Name
                Text(keepsake.keepsake.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showName ? 1 : 0)
                    .offset(y: showName ? 0 : 20)

                // Flavour text
                Text(keepsake.keepsake.flavourText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showFlavourText ? 1 : 0)
                    .offset(y: showFlavourText ? 0 : 20)

                // Rarity
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(royalPurple)

                    Text(String(format: "%.1f%% of users have this", keepsake.rarityPercentage))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(showRarity ? 1 : 0)
                .offset(y: showRarity ? 0 : 20)

                Spacer()

                // View on profile button
                Button {
                    onViewProfile()
                } label: {
                    Text("View on Profile")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [royalPurple, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)

                // Tap to dismiss
                Text("Tap anywhere to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(showButton ? 1 : 0)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            runRevealAnimation()
        }
    }

    @ViewBuilder
    private var keepsakeIcon: some View {
        switch keepsake.keepsake.name.lowercased() {
        case let name where name.contains("lakes"):
            Image(systemName: "mountain.2.fill")
        case let name where name.contains("sopranos"):
            Image(systemName: "crown.fill")
        case let name where name.contains("hijack"):
            Image(systemName: "ferry.fill")
        default:
            Image(systemName: "star.fill")
        }
    }

    private func runRevealAnimation() {
        // Show card
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showCard = true
        }

        // Flip card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                cardRotation = 0
            }
        }

        // Show name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showName = true
            }
        }

        // Show flavour text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFlavourText = true
            }
        }

        // Show rarity
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRarity = true
            }
        }

        // Show button
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showButton = true
            }
        }
    }
}

#Preview {
    KeepsakeRevealView(
        keepsake: EarnedKeepsake(
            id: UUID(),
            keepsake: Keepsake(
                id: UUID(),
                name: "Sopranos",
                artworkUrl: "",
                flavourText: "Made member of the first family.",
                eventId: nil,
                createdAt: Date()
            ),
            earnedAt: Date(),
            rarityPercentage: 0.5
        ),
        onDismiss: {},
        onViewProfile: {}
    )
}
```

**Step 2: Commit**

```bash
git add Momento/Profile/KeepsakeRevealView.swift
git commit -m "feat(ui): add KeepsakeRevealView animation component"
```

---

## Task 13: Integrate Keepsake Reveal into RevealView

**Files:**
- Modify: `Momento/RevealView.swift`

**Step 1: Add state variables for keepsake reveal**

Add after the existing `@State` declarations (around line 24):

```swift
@State private var earnedKeepsake: EarnedKeepsake?
@State private var showKeepsakeReveal = false
@State private var showProfile = false
```

**Step 2: Add keepsake check in completeReveal function**

Replace the `completeReveal()` function (around line 434) with:

```swift
private func completeReveal() {
    // Play celebration haptic
    HapticsManager.shared.celebration()

    // Show confetti
    withAnimation {
        showConfetti = true
    }

    // Check for keepsake
    Task {
        if let eventUUID = UUID(uuidString: event.id) {
            earnedKeepsake = try? await supabaseManager.hasKeepsakeForEvent(eventId: eventUUID)
        }

        await MainActor.run {
            // Show completion overlay after confetti starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    // If there's a keepsake, show that instead of completion
                    if earnedKeepsake != nil {
                        showKeepsakeReveal = true
                    } else {
                        allRevealed = true
                    }
                }
            }
        }
    }

    // Hide confetti after a bit
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        withAnimation {
            showConfetti = false
        }
    }
}
```

**Step 3: Add keepsake reveal overlay**

Add this after the completion overlay (around line 131):

```swift
// Keepsake reveal overlay
if showKeepsakeReveal, let keepsake = earnedKeepsake {
    KeepsakeRevealView(
        keepsake: keepsake,
        onDismiss: {
            showKeepsakeReveal = false
            allRevealed = true
        },
        onViewProfile: {
            showKeepsakeReveal = false
            showProfile = true
        }
    )
}
```

**Step 4: Add profile sheet**

Add after the `.fullScreenCover(isPresented: $showGallery)` modifier (around line 138):

```swift
.sheet(isPresented: $showProfile) {
    ProfileView()
}
```

**Step 5: Commit**

```bash
git add Momento/RevealView.swift
git commit -m "feat: integrate keepsake reveal into RevealView"
```

---

## Task 14: Create Profile Folder in Xcode Project

**Files:**
- Verify folder structure exists

**Step 1: Ensure Profile folder exists**

The Profile folder should be created when adding the first file. Verify all Profile files are in the correct location:

```
Momento/Profile/
├── StatCardView.swift
├── StatsGridView.swift
├── KeepsakeGridView.swift
├── KeepsakeDetailModal.swift
├── KeepsakeRevealView.swift
└── ProfileView.swift
```

**Step 2: Commit all profile files**

```bash
git add Momento/Profile/
git commit -m "feat: organize profile components in Profile folder"
```

---

## Task 15: Final Integration Test & Cleanup

**Files:**
- All files from previous tasks

**Step 1: Verify all imports and references**

Ensure all Swift files have proper imports and no missing references.

**Step 2: Remove old SettingsView (optional)**

If keeping SettingsView for debug purposes, leave it. Otherwise, can be removed later.

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: complete user profile and keepsakes feature

- Add keepsakes and user_keepsakes database tables
- Add Keepsake, UserKeepsake, EarnedKeepsake, ProfileStats models
- Add keepsake and stats fetch methods to SupabaseManager
- Create ProfileView with stats grid and keepsake grid
- Create KeepsakeRevealView with flip animation
- Integrate keepsake reveal into RevealView completion flow
- Replace SettingsView with ProfileView in ContentView"
```

---

## Summary

**Database:**
- New `keepsakes` table for keepsake definitions
- New `user_keepsakes` table for earned keepsakes
- RLS policies for secure access
- Seeded 3 initial keepsakes (Lakes, Sopranos, Hijack x DoubleDip)

**Swift Models:**
- `Keepsake` - keepsake definition
- `UserKeepsake` - user-keepsake relationship
- `EarnedKeepsake` - combined model with rarity
- `ProfileStats` - all 8 stats

**API Methods:**
- `getUserKeepsakes()` - fetch user's earned keepsakes with rarity
- `hasKeepsakeForEvent()` - check if event has keepsake user earned
- `getProfileStats()` - fetch all 8 profile stats

**UI Components:**
- `ProfileView` - main profile screen
- `StatsGridView` - 2-column stats grid
- `StatCardView` - individual stat card
- `KeepsakeGridView` - keepsake thumbnails
- `KeepsakeDetailModal` - full keepsake details
- `KeepsakeRevealView` - reveal animation

**Integration:**
- ProfileView replaces SettingsView in ContentView
- Keepsake reveal triggers after completing event reveal
