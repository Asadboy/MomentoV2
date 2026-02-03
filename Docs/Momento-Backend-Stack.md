# Momento Backend Stack

**Last Updated:** 2026-02-02

This document explains how Momento's backend architecture works - the tools, their responsibilities, and how they connect.

---

## Stack Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOMENTO iOS APP                           │
│                       (Swift + Claude Code)                      │
└──────────┬───────────────┬───────────────┬───────────────┬──────┘
           │               │               │               │
           ▼               ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ SUPABASE │    │ POSTHOG  │    │REVENUECAT│    │  APPLE   │
    │          │    │          │    │          │    │  (APNs)  │
    │ • Auth   │    │ • Events │    │ • Subs   │    │ • Push   │
    │ • DB     │    │ • Funnels│    │ • Paywalls│   │          │
    │ • Storage│    │ • Trends │    │ • Receipt│    │          │
    │ • Edge   │    │          │    │   valid  │    │          │
    └──────────┘    └──────────┘    └──────────┘    └──────────┘
```

---

## Supabase — The Backend Brain

### What It Handles
- **Auth** — Sign up, login, sessions, password reset
- **Database** — Core relational data (users, events, photos, memberships)
- **Storage** — Photo files in buckets with signed URLs
- **Row Level Security (RLS)** — "User can only see photos from events they're in"
- **Edge Functions** — Server-side logic (reveal scheduling, webhooks)
- **Realtime** — Live updates if needed (new photo appears instantly)

### When The App Talks To Supabase
| Action | Supabase Component |
|--------|-------------------|
| User logs in | Auth |
| User joins event | DB insert |
| User uploads photo | Storage + DB insert |
| User opens reveal | DB query for photos |
| User likes photo | DB insert |

---

## PostHog — The Growth Eyes

### What It Handles
- **Event Tracking** — Every tap, view, share, download
- **Funnels** — "What % of users who start reveal finish it?"
- **Retention** — "Do users come back for second events?"
- **Feature Flags** — Test new features with 10% of users
- **Session Replay** — Watch how users interact (optional)

### Key Events To Track
```swift
// User engagement
capture("photo_downloaded", ["photo_id", "event_id"])
capture("photo_shared", ["photo_id", "event_id", "destination"]) // ig, messages, etc
capture("photo_liked", ["photo_id", "event_id"])
capture("reveal_started", ["event_id", "photo_count"])
capture("reveal_completed", ["event_id", "duration_seconds"])

// Business metrics
capture("event_created", ["is_premium": true/false])
capture("premium_purchased", ["event_id", "price"])
capture("user_joined_event", ["event_id", "via": "join_code"])
```

### Why PostHog For Metrics (Not Database)
PostHog calls are **fire-and-forget**:
- Events queue locally on device
- Batch and sync in background (every 30s)
- Zero database load
- App stays snappy

During reveal (100 users downloading photos simultaneously):
- **Database approach**: 1000 UPDATE queries = slow, locks, timeouts
- **PostHog approach**: 1000 events batched async = zero impact

---

## RevenueCat — The Money Layer

### What It Handles
- **Paywalls** — Show purchase UI
- **Subscription Management** — Who's paying, what tier
- **Receipt Validation** — Verify with Apple (never DIY this)
- **Entitlements** — "Does this user have premium access?"
- **Webhooks** — Notify backend when someone subscribes/cancels

### Momento's Model: Host Pays
```swift
// When creating event
if selectedTier == .premium {
    let offerings = try await Purchases.shared.offerings()
    // Present paywall
    // On success, create event with is_premium = true
}
```

Premium benefits (host pays, all members benefit):
- Event persists beyond 7 days
- Higher photo limits
- Priority support

---

## Apple Push Notifications (APNs)

### What It Handles
- "Your photos are ready to reveal!"
- "Someone joined your Momento"
- "New photos added"

### How It Connects
1. Store device tokens in Supabase (on app launch)
2. Supabase Edge Function triggers at `release_at` time
3. Edge Function calls APNs with stored tokens
4. Users get notified even if app is closed

---

## Data Architecture: Database vs Analytics

### The Core Principle
> **Database = State** (what IS right now)
> **PostHog = Events** (what HAPPENED over time)

### Decision Guide
| Question | Where To Look |
|----------|---------------|
| "Does this user have access to this event?" | Database |
| "How many times did users access this event?" | PostHog |
| "Show me photos I liked" | Database |
| "What's the most downloaded photo?" | PostHog |
| "Is this event premium?" | Database |
| "How many premium events were created this month?" | PostHog |

### What Lives Where

**Database (Supabase)**
- Relationships: who's in what event
- Content: photos, storage paths
- State: is_premium, is_deleted
- Access control: RLS policies

**Analytics (PostHog)**
- Counts: downloads, shares, views
- Funnels: signup → create event → invite friends
- Retention: weekly/monthly active users
- Trends: photo uploads over time

---

## Database Schema

### Tables Overview (5 tables)

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `profiles` | User accounts | username, display_name, avatar_url, device_token |
| `events` | Momentos | name, join_code, creator_id, starts_at, release_at, is_premium |
| `event_members` | Who's in what | event_id, user_id, joined_at |
| `photos` | The content | event_id, user_id, storage_path, width, height, upload_status, is_flagged |
| `photo_likes` | Who liked what | photo_id, user_id |

### Full Schema

```sql
-- ============================================
-- PROFILES: Who exists
-- ============================================
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text NOT NULL UNIQUE,
  display_name text,
  avatar_url text,
  device_token text,              -- APNs token for push notifications
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_profiles_username ON profiles(username);


-- ============================================
-- EVENTS: The Momentos
-- ============================================
CREATE TABLE public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  join_code text NOT NULL UNIQUE,
  creator_id uuid NOT NULL REFERENCES auth.users(id),
  starts_at timestamptz NOT NULL,
  release_at timestamptz NOT NULL,
  is_premium boolean DEFAULT false,
  is_deleted boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_events_join_code ON events(join_code) WHERE NOT is_deleted;
CREATE INDEX idx_events_creator ON events(creator_id) WHERE NOT is_deleted;


-- ============================================
-- EVENT_MEMBERS: Who's in what
-- ============================================
CREATE TABLE public.event_members (
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  joined_at timestamptz DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX idx_event_members_user ON event_members(user_id);


-- ============================================
-- PHOTOS: The content
-- ============================================
CREATE TABLE public.photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  storage_path text NOT NULL,
  captured_at timestamptz DEFAULT now(),
  username text NOT NULL,         -- Denormalized for display
  width integer,                  -- For UI placeholder sizing
  height integer,                 -- For UI placeholder sizing
  upload_status text DEFAULT 'pending' CHECK (upload_status IN ('pending', 'uploaded', 'failed')),
  is_flagged boolean DEFAULT false  -- Moderation flag
);

CREATE INDEX idx_photos_event_time ON photos(event_id, captured_at);
CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_pending ON photos(upload_status) WHERE upload_status = 'pending';


-- ============================================
-- PHOTO_LIKES: Who liked what
-- ============================================
CREATE TABLE public.photo_likes (
  photo_id uuid NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (photo_id, user_id)
);

CREATE INDEX idx_photo_likes_user ON photo_likes(user_id);
```

### Column Reference

| Table | Column | Purpose |
|-------|--------|---------|
| profiles | `device_token` | APNs push notification token, updated on app launch |
| photos | `width`, `height` | Lets UI show correctly-sized placeholder before image loads |
| photos | `upload_status` | Track background upload progress: pending → uploaded (or failed) |
| photos | `is_flagged` | Moderation: hide flagged photos from feed, review later |

### Computing Stats (Not Stored)

These are computed on demand, not stored:

```sql
-- User number ("You're user #47!")
SELECT COUNT(*) FROM profiles WHERE created_at <= $user_created_at;

-- Event member count
SELECT COUNT(*) FROM event_members WHERE event_id = $event_id;

-- Event photo count
SELECT COUNT(*) FROM photos WHERE event_id = $event_id;

-- Photo like count
SELECT COUNT(*) FROM photo_likes WHERE photo_id = $photo_id;

-- User's total events
SELECT COUNT(*) FROM event_members WHERE user_id = $user_id;
```

---

## Cleanup Policy

### Free Events
- Auto-delete after 7 days post-reveal
- Edge Function runs daily, sets `is_deleted = true` for expired events
- Separate job hard-deletes `is_deleted` events and their photos from storage

### Premium Events
- Persist until manually deleted by creator
- Or based on premium tier duration

---

## Key Query Patterns

### High Frequency (Reveal Flow)
```sql
-- Get paginated photos for event
SELECT * FROM photos
WHERE event_id = $1
ORDER BY captured_at
LIMIT 20 OFFSET $2;

-- Check if user liked photo
SELECT 1 FROM photo_likes
WHERE photo_id = $1 AND user_id = $2;

-- Like a photo (upsert)
INSERT INTO photo_likes (photo_id, user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- Get user's liked photos for event
SELECT p.* FROM photos p
JOIN photo_likes pl ON p.id = pl.photo_id
WHERE p.event_id = $1 AND pl.user_id = $2
ORDER BY pl.created_at DESC;
```

### Medium Frequency
```sql
-- Get user's events
SELECT e.* FROM events e
JOIN event_members em ON e.id = em.event_id
WHERE em.user_id = $1 AND NOT e.is_deleted
ORDER BY e.created_at DESC;

-- Join event by code
INSERT INTO event_members (event_id, user_id)
SELECT id, $2 FROM events WHERE join_code = $1 AND NOT is_deleted
ON CONFLICT DO NOTHING;
```

---

## Security: Row Level Security (RLS)

### Profiles
- Users can read any profile (for displaying usernames)
- Users can only update their own profile

### Events
- Members can read events they belong to
- Only creator can update/delete

### Photos
- Members of the event can read photos
- Only photo owner can delete their photo

### Photo Likes
- Users can only insert/delete their own likes
- Users can read like counts (but not who liked)

---

## Future Considerations

### When To Revisit
- **1000+ users**: Consider caching hot data (event member counts)
- **Heavy analytics needs**: PostHog handles most, but might want a data warehouse
- **Real-time features**: Supabase Realtime for live photo updates
- **International scale**: CDN optimization for photo delivery

### Deferred Features
- Keepsakes/badges system (add when understood better)
- Profile first_name/last_name (add when needed)
- Event descriptions/locations (add when UX requires it)

---

## Implementation Plan

**Status:** Parked - Ready to execute when needed

### Phase 1: Database Migration (Supabase)

#### 1.1 Create New Tables
Run in Supabase SQL editor - creates new schema alongside existing:

```sql
-- New photo_likes table (replaces photo_interactions for likes only)
CREATE TABLE public.photo_likes (
  photo_id uuid NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (photo_id, user_id)
);
CREATE INDEX idx_photo_likes_user ON photo_likes(user_id);
```

#### 1.2 Migrate Existing Data
```sql
-- Copy likes from photo_interactions to photo_likes
INSERT INTO photo_likes (photo_id, user_id, created_at)
SELECT photo_id, user_id, created_at
FROM photo_interactions
WHERE status = 'liked'
ON CONFLICT DO NOTHING;
```

#### 1.3 Add New Columns to Existing Tables
```sql
-- Profiles: add device_token
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS device_token text;

-- Photos: add missing columns
ALTER TABLE photos ADD COLUMN IF NOT EXISTS width integer;
ALTER TABLE photos ADD COLUMN IF NOT EXISTS height integer;
ALTER TABLE photos ADD COLUMN IF NOT EXISTS is_flagged boolean DEFAULT false;

-- Photos: add constraint to upload_status if not exists
ALTER TABLE photos DROP CONSTRAINT IF EXISTS photos_upload_status_check;
ALTER TABLE photos ADD CONSTRAINT photos_upload_status_check
  CHECK (upload_status IN ('pending', 'uploaded', 'failed'));
```

#### 1.4 Add Missing Indexes
```sql
-- These indexes optimize the key query patterns
CREATE INDEX IF NOT EXISTS idx_photos_event_time ON photos(event_id, captured_at);
CREATE INDEX IF NOT EXISTS idx_photos_pending ON photos(upload_status) WHERE upload_status = 'pending';
CREATE INDEX IF NOT EXISTS idx_events_join_code ON events(join_code) WHERE NOT is_deleted;
```

#### 1.5 Drop Unused Columns
```sql
-- Profiles: drop unused columns
ALTER TABLE profiles DROP COLUMN IF EXISTS first_name;
ALTER TABLE profiles DROP COLUMN IF EXISTS last_name;
ALTER TABLE profiles DROP COLUMN IF EXISTS is_premium;
ALTER TABLE profiles DROP COLUMN IF EXISTS total_events_joined;
ALTER TABLE profiles DROP COLUMN IF EXISTS updated_at;

-- Events: drop unused columns
ALTER TABLE events DROP COLUMN IF EXISTS is_private;
ALTER TABLE events DROP COLUMN IF EXISTS is_corporate;
ALTER TABLE events DROP COLUMN IF EXISTS max_photos_per_user;
ALTER TABLE events DROP COLUMN IF EXISTS location_name;
ALTER TABLE events DROP COLUMN IF EXISTS location_lat;
ALTER TABLE events DROP COLUMN IF EXISTS location_lng;
ALTER TABLE events DROP COLUMN IF EXISTS description;
ALTER TABLE events DROP COLUMN IF EXISTS member_count;
ALTER TABLE events DROP COLUMN IF EXISTS photo_count;
ALTER TABLE events DROP COLUMN IF EXISTS is_revealed;
ALTER TABLE events DROP COLUMN IF EXISTS reveal_job_scheduled;
ALTER TABLE events DROP COLUMN IF EXISTS ends_at;

-- Rename 'title' to 'name' for clarity
ALTER TABLE events RENAME COLUMN title TO name;

-- Photos: drop unused columns
ALTER TABLE photos DROP COLUMN IF EXISTS device_type;
ALTER TABLE photos DROP COLUMN IF EXISTS file_size;
ALTER TABLE photos DROP COLUMN IF EXISTS is_revealed;
ALTER TABLE photos DROP COLUMN IF EXISTS reactions;

-- Rename for consistency
ALTER TABLE photos RENAME COLUMN captured_by_username TO username;

-- Event members: drop unused columns
ALTER TABLE event_members DROP COLUMN IF EXISTS id;  -- Using composite PK now
ALTER TABLE event_members DROP COLUMN IF EXISTS invited_by;
ALTER TABLE event_members DROP COLUMN IF EXISTS role;
```

#### 1.6 Drop Unused Tables
```sql
-- Only after confirming app works without them
DROP TABLE IF EXISTS user_keepsakes;
DROP TABLE IF EXISTS keepsakes;
DROP TABLE IF EXISTS user_reveal_progress;
DROP TABLE IF EXISTS photo_interactions;  -- After migrating likes
```

---

### Phase 2: iOS Code Updates

#### 2.1 Update Models

**Event.swift** - Remove unused fields:
- Remove: `isPrivate`, `isCorporate`, `maxPhotosPerUser`, `locationName`, `locationLat`, `locationLng`, `description`, `memberCount`, `photoCount`, `isRevealed`, `revealJobScheduled`, `endsAt`
- Rename: `title` → `name`

**Profile.swift** - Simplify:
- Remove: `firstName`, `lastName`, `isPremium`, `totalEventsJoined`, `updatedAt`
- Add: `deviceToken`

**Photo.swift** - Update:
- Remove: `deviceType`, `fileSize`, `isRevealed`, `reactions`
- Add: `width`, `height`, `isFlagged`
- Rename: `capturedByUsername` → `username`

#### 2.2 Update SupabaseManager.swift

Key changes:
1. Replace `photo_interactions` queries with `photo_likes`
2. Remove keepsake-related functions
3. Remove reveal progress functions (store locally instead)
4. Update all `select()` calls to only fetch needed columns
5. Add `device_token` update on app launch

#### 2.3 Update Views

- Remove any keepsake UI
- Update reveal progress to use local storage (UserDefaults/SwiftData)
- Update photo upload to include width/height

---

### Phase 3: PostHog Integration

#### 3.1 Add Tracking Events

Replace database metrics with PostHog events:

```swift
// In photo download action
PostHogSDK.shared.capture("photo_downloaded", properties: [
    "photo_id": photo.id,
    "event_id": photo.eventId
])

// In photo share action
PostHogSDK.shared.capture("photo_shared", properties: [
    "photo_id": photo.id,
    "event_id": photo.eventId,
    "destination": destination  // "instagram", "messages", etc
])

// In reveal flow
PostHogSDK.shared.capture("reveal_started", properties: [
    "event_id": eventId,
    "photo_count": photoCount
])

PostHogSDK.shared.capture("reveal_completed", properties: [
    "event_id": eventId,
    "duration_seconds": duration
])
```

#### 3.2 Create PostHog Dashboards

Set up dashboards for:
- Photo engagement (downloads, shares, likes per event)
- Reveal completion funnel
- User retention (events joined over time)
- Premium conversion rate

---

### Phase 4: Cleanup & Verification

#### 4.1 Verify Everything Works
- [ ] User can sign up and create profile
- [ ] User can create event
- [ ] User can join event via code
- [ ] User can upload photos (with dimensions)
- [ ] User can view reveal feed
- [ ] User can like/unlike photos
- [ ] User can download/share photos
- [ ] Push notifications work
- [ ] Failed uploads show in pending state

#### 4.2 Monitor for Issues
- Check Supabase logs for query errors
- Check PostHog for event tracking
- Test with existing users on new schema

#### 4.3 Final Cleanup
Once verified stable:
- Remove old table backups if created
- Update RLS policies for new schema
- Document any edge cases found

---

### Migration Checklist

```
[ ] Phase 1.1 - Create photo_likes table
[ ] Phase 1.2 - Migrate likes data
[ ] Phase 1.3 - Add new columns
[ ] Phase 1.4 - Add indexes
[ ] Phase 1.5 - Drop unused columns
[ ] Phase 1.6 - Drop unused tables
[ ] Phase 2.1 - Update Swift models
[ ] Phase 2.2 - Update SupabaseManager
[ ] Phase 2.3 - Update Views
[ ] Phase 3.1 - Add PostHog events
[ ] Phase 3.2 - Create dashboards
[ ] Phase 4.1 - Verify functionality
[ ] Phase 4.2 - Monitor
[ ] Phase 4.3 - Final cleanup
```

---

### Rollback Plan

If issues arise:
1. Old tables remain until Phase 1.6 - can revert queries
2. Keep `photo_interactions` until `photo_likes` is verified
3. Column drops are one-way - take Supabase backup before Phase 1.5

**Backup command (run before migration):**
```sql
-- Create backup of current state
CREATE TABLE profiles_backup AS SELECT * FROM profiles;
CREATE TABLE events_backup AS SELECT * FROM events;
CREATE TABLE photos_backup AS SELECT * FROM photos;
CREATE TABLE photo_interactions_backup AS SELECT * FROM photo_interactions;
```
