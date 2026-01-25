# Backend Optimization Design

**Date:** 2026-01-25
**Status:** Ready for implementation
**Goal:** Fix Supabase warnings, add pagination, establish stable foundation for 10k+ users

---

## Problem Statement

The beta revealed performance issues:
- 240 photos taken, 13 users downloading all at reveal = ~5GB bandwidth spike
- Reveal load time: up to 20 seconds
- 15 RLS performance warnings (auth.uid() re-evaluated per row)
- 4 function security warnings (mutable search_path)
- 2 duplicate policy warnings

---

## Success Criteria

- [ ] All Supabase performance warnings resolved
- [ ] All Supabase security warnings resolved
- [ ] Reveal loads first photo in under 2 seconds
- [ ] Pagination: 10 photos per batch, prefetch at photo 7
- [ ] No breaking changes to existing functionality

---

## Part 1: RLS Performance Fixes

### What

Wrap all `auth.uid()` calls in `(select auth.uid())` so Postgres evaluates once per query instead of per row.

### Why

With 240 photos, `auth.uid()` currently runs 240 times. With the fix, it runs once. Saves 200-500ms per query.

### Migration File

Create: `Supabase/migrations/20260125000000_fix_rls_performance.sql`

```sql
-- Fix RLS Performance: Wrap auth.uid() in (select ...) for single evaluation
-- This prevents re-evaluation of auth.uid() for each row

-- ============================================
-- PROFILES POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = (select auth.uid()));

-- ============================================
-- EVENTS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view their events" ON events;
CREATE POLICY "Users can view their events"
ON events FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can create events" ON events;
CREATE POLICY "Users can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (creator_id = (select auth.uid()));

DROP POLICY IF EXISTS "Creators can update their events" ON events;
CREATE POLICY "Creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (creator_id = (select auth.uid()));

DROP POLICY IF EXISTS "Creators can delete their events" ON events;
CREATE POLICY "Creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (creator_id = (select auth.uid()));

-- ============================================
-- EVENT MEMBERS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view own memberships" ON event_members;
DROP POLICY IF EXISTS "Users can view members of their events" ON event_members;
CREATE POLICY "Users can view members of their events"
ON event_members FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can join events" ON event_members;
CREATE POLICY "Users can join events"
ON event_members FOR INSERT
TO authenticated
WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can leave events" ON event_members;
CREATE POLICY "Users can leave events"
ON event_members FOR DELETE
TO authenticated
USING (user_id = (select auth.uid()));

-- ============================================
-- PHOTOS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view photos from their events" ON photos;
CREATE POLICY "Users can view photos from their events"
ON photos FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

-- Consolidate duplicate INSERT policies into one
DROP POLICY IF EXISTS "Users can upload photos" ON photos;
DROP POLICY IF EXISTS "photos_insert" ON photos;
CREATE POLICY "Users can upload photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (select auth.uid()) AND
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can update own photos" ON photos;
CREATE POLICY "Users can update own photos"
ON photos FOR UPDATE
TO authenticated
USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Creators can moderate photos" ON photos;
DROP POLICY IF EXISTS "photos_delete" ON photos;
CREATE POLICY "Creators can moderate photos"
ON photos FOR DELETE
TO authenticated
USING (
  event_id IN (
    SELECT id FROM events
    WHERE creator_id = (select auth.uid())
  )
  OR user_id = (select auth.uid())
);

-- ============================================
-- PHOTO_INTERACTIONS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can manage their own interactions" ON photo_interactions;
CREATE POLICY "Users can manage their own interactions"
ON photo_interactions FOR ALL
TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- USER_REVEAL_PROGRESS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can manage their own progress" ON user_reveal_progress;
CREATE POLICY "Users can manage their own progress"
ON user_reveal_progress FOR ALL
TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));
```

---

## Part 2: Function Security Fixes

### What

Add `SET search_path = ''` to all trigger functions to prevent privilege escalation.

### Migration File

Create: `Supabase/migrations/20260125000001_fix_function_security.sql`

```sql
-- Fix Function Security: Set immutable search_path

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user' || floor(random() * 10000)::text),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '';

CREATE OR REPLACE FUNCTION public.update_event_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.events
    SET member_count = member_count + 1
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.events
    SET member_count = member_count - 1
    WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION public.update_event_photo_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.events
    SET photo_count = photo_count + 1
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.events
    SET photo_count = photo_count - 1
    WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
SET search_path = '';
```

---

## Part 3: Duplicate Policy Consolidation

### What

The `events` table has two SELECT policies that both run on every query. Consolidate into one.

### Migration File

Create: `Supabase/migrations/20260125000002_fix_duplicate_policies.sql`

```sql
-- Consolidate duplicate SELECT policies on events table

DROP POLICY IF EXISTS "Anyone can find events to join" ON events;
DROP POLICY IF EXISTS "Users can view their events" ON events;

-- Single policy: members can view their events, anyone can find by join_code
CREATE POLICY "Users can view events"
ON events FOR SELECT
TO authenticated
USING (
  -- User is a member of the event
  id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
  OR
  -- Public lookup by join_code (for joining)
  join_code IS NOT NULL
);
```

**Note:** The photos INSERT duplicate was already handled in Part 1.

---

## Part 4: iOS Pagination Implementation

### 4.1 Add Paginated Photo Fetch to SupabaseManager

Location: `Momento/Services/SupabaseManager.swift`

Add new function:

```swift
/// Fetch photos for reveal with pagination
/// - Parameters:
///   - eventId: The event UUID
///   - offset: Starting index (0-based)
///   - limit: Number of photos to fetch (default 10)
/// - Returns: Tuple of (photos, hasMore)
func fetchPhotosForRevealPaginated(
    eventId: UUID,
    offset: Int = 0,
    limit: Int = 10
) async throws -> (photos: [PhotoData], hasMore: Bool) {

    struct PhotoWithProfile: Decodable {
        let id: UUID
        let eventId: UUID
        let userId: UUID
        let storagePath: String
        let capturedAt: Date
        let capturedByUsername: String?

        enum CodingKeys: String, CodingKey {
            case id
            case eventId = "event_id"
            case userId = "user_id"
            case storagePath = "storage_path"
            case capturedAt = "captured_at"
            case capturedByUsername = "captured_by_username"
        }
    }

    // Fetch one extra to know if there are more
    let photos: [PhotoWithProfile] = try await client
        .from("photos")
        .select()
        .eq("event_id", value: eventId.uuidString)
        .order("captured_at", ascending: true)
        .range(from: offset, to: offset + limit) // Supabase range is inclusive
        .execute()
        .value

    let hasMore = photos.count > limit
    let photosToProcess = hasMore ? Array(photos.prefix(limit)) : photos

    // Generate signed URLs in parallel
    let photoDataArray = await withTaskGroup(of: PhotoData?.self) { group in
        for photo in photosToProcess {
            group.addTask {
                let signedURL = try? await self.client.storage
                    .from("momento-photos")
                    .createSignedURL(path: photo.storagePath, expiresIn: 604800)

                return PhotoData(
                    id: photo.id.uuidString,
                    url: signedURL,
                    capturedAt: photo.capturedAt,
                    capturedByUsername: photo.capturedByUsername ?? "Unknown"
                )
            }
        }

        var results: [PhotoData] = []
        for await result in group {
            if let photoData = result {
                results.append(photoData)
            }
        }
        return results
    }

    // Sort by captured_at to maintain order (parallel execution shuffles)
    let sortedPhotos = photoDataArray.sorted { $0.capturedAt < $1.capturedAt }

    return (photos: sortedPhotos, hasMore: hasMore)
}
```

### 4.2 Update Reveal View with Pagination

Location: `Momento/FeedRevealView.swift` (or equivalent reveal view)

Add state management:

```swift
// MARK: - Pagination State

@State private var photos: [PhotoData] = []
@State private var currentIndex: Int = 0
@State private var isLoadingMore: Bool = false
@State private var hasMorePhotos: Bool = true
@State private var currentOffset: Int = 0

private let pageSize = 10
private let prefetchThreshold = 7 // Load more when 3 photos from end
```

Add load functions:

```swift
// MARK: - Data Loading

private func loadInitialPhotos() async {
    do {
        let result = try await SupabaseManager.shared.fetchPhotosForRevealPaginated(
            eventId: eventId,
            offset: 0,
            limit: pageSize
        )
        photos = result.photos
        hasMorePhotos = result.hasMore
        currentOffset = photos.count
    } catch {
        print("Failed to load photos: \(error)")
    }
}

private func loadMorePhotosIfNeeded(currentPhoto: PhotoData) {
    // Find index of current photo
    guard let index = photos.firstIndex(where: { $0.id == currentPhoto.id }) else { return }

    // Check if we should prefetch
    let remainingPhotos = photos.count - index - 1
    guard remainingPhotos <= (pageSize - prefetchThreshold) else { return }
    guard hasMorePhotos && !isLoadingMore else { return }

    Task {
        await loadMorePhotos()
    }
}

private func loadMorePhotos() async {
    isLoadingMore = true
    defer { isLoadingMore = false }

    do {
        let result = try await SupabaseManager.shared.fetchPhotosForRevealPaginated(
            eventId: eventId,
            offset: currentOffset,
            limit: pageSize
        )
        photos.append(contentsOf: result.photos)
        hasMorePhotos = result.hasMore
        currentOffset = photos.count
    } catch {
        print("Failed to load more photos: \(error)")
    }
}
```

Update the view to trigger prefetch:

```swift
// In your ScrollView or List, add onChange:
.onChange(of: currentIndex) { newIndex in
    if newIndex < photos.count {
        loadMorePhotosIfNeeded(currentPhoto: photos[newIndex])
    }
}

// Or if using ForEach with onAppear:
ForEach(photos) { photo in
    PhotoView(photo: photo)
        .onAppear {
            loadMorePhotosIfNeeded(currentPhoto: photo)
        }
}
```

### 4.3 Add Loading Indicator

Show a subtle loader when fetching more:

```swift
// At the bottom of the photo list
if isLoadingMore {
    ProgressView()
        .padding()
}
```

---

## Part 5: Testing Checklist

Before deploying, verify:

### Backend
- [ ] Run all 3 migration files in Supabase SQL Editor (in order)
- [ ] Check Supabase Performance Advisor - all warnings should be gone
- [ ] Check Supabase Security Advisor - function warnings should be gone
- [ ] Test: Can still create events
- [ ] Test: Can still join events
- [ ] Test: Can still upload photos
- [ ] Test: Can still view photos (member only)

### iOS Pagination
- [ ] Reveal loads first 10 photos quickly (~1-2 seconds)
- [ ] Scrolling past photo 7 triggers prefetch
- [ ] Photos continue loading seamlessly
- [ ] Reaching end of photos stops fetching
- [ ] Error states handled gracefully

---

## Part 6: Future Roadmap

### Month 3-4
- [ ] Add Sentry for error tracking
- [ ] Cache signed URLs in-app for session duration

### Month 4-6
- [ ] Build Option B edge function for batch URL generation
- [ ] Add rate limiting (60 req/user/min)

### Month 6-9
- [ ] Add CDN (Cloudflare/Bunny) for image delivery
- [ ] Implement server-side URL caching (Redis or edge cache)

### Month 9-12
- [ ] Add composite index: `idx_photos_event_captured ON photos(event_id, captured_at)`
- [ ] Review and optimize hot queries
- [ ] Consider read replicas if needed

---

## Implementation Order

1. **Backend first** (migrations) - no app changes needed
2. **Test backend** - verify no regressions
3. **iOS pagination** - update SupabaseManager, then views
4. **Test iOS** - verify performance improvement
5. **Deploy** - backend already live, push app update

---

## Expected Results

| Metric | Before | After |
|--------|--------|-------|
| Supabase warnings | 22 | 0 |
| Time to first photo | ~20s | ~1-2s |
| Initial download | 360MB | 15MB |
| RLS overhead per query | 800-1200ms | 100-200ms |
| User experience | "App is frozen" | "Instant, smooth scroll" |

---

**Ready for implementation.**
