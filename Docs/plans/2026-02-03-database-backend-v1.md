# Momento Backend & Database — V1

**Date:** 2026-02-03
**Status:** Active
**Scope:** V1 only. Anything beyond V1 is clearly labelled as "Future."

---

## Architecture Overview

Momento has no custom API layer. The iOS app talks directly to four services:

```
┌──────────────────────────────────┐
│         MOMENTO iOS APP          │
└──────┬───────┬───────┬───────┬───┘
       │       │       │       │
       ▼       ▼       ▼       ▼
   Supabase  PostHog  RevenueCat  APNs
```

| Service | Role |
|---------|------|
| **Supabase** | Auth, database, photo storage, Edge Functions, RLS |
| **PostHog** | Analytics — event tracking, funnels, retention. Fire-and-forget, zero DB load |
| **RevenueCat** | Payments — £7.99 per-event purchase, receipt validation. Implementation TBD |
| **Apple APNs** | Push notifications — "Your photos are ready to reveal!" |

### Core Principle

> **Database = State** (what IS right now)
> **PostHog = Events** (what HAPPENED over time)

The database stores relationships, content, and access control. PostHog stores counts, funnels, and trends. Never query the database for analytics. Never query PostHog for access control.

---

## Database Schema

5 tables. No more, no less. Every table that existed for keepsakes, reveal progress, or photo interactions has been cut or consolidated.

### Tables Overview

| Table | Purpose | Key |
|-------|---------|-----|
| `profiles` | User accounts | `id` (matches auth.users) |
| `events` | Momentos | `id` (uuid) |
| `event_members` | Who's in what | composite `(event_id, user_id)` |
| `photos` | The content | `id` (uuid) |
| `photo_likes` | Who liked what | composite `(photo_id, user_id)` |

### Why 5 Tables

The previous schema had 8 tables including `keepsakes`, `user_keepsakes`, `user_reveal_progress`, and `photo_interactions`. These added complexity without matching how the app actually works:

- **Keepsakes/badges** — deferred to post-v1. Not validated yet, don't build the schema for it
- **Reveal progress** — tracking swipe position by index was fragile (breaks if photos are deleted). Better handled client-side with local storage
- **Photo interactions** — had a `status` field for liked/archived. Archive is cut from v1, so a dedicated `photo_likes` table with a composite primary key is simpler and faster

Resist the urge to add tables "just in case." Every table is a migration, a set of RLS policies, and query complexity you maintain forever. Add them when you have a proven need.

---

## Full Schema

```sql
-- ============================================
-- PROFILES: Who exists
-- ============================================
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text NOT NULL UNIQUE,
  display_name text,
  avatar_url text,
  device_token text,
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
  ends_at timestamptz NOT NULL,
  release_at timestamptz NOT NULL,
  is_premium boolean DEFAULT false,
  is_deleted boolean DEFAULT false,
  expires_at timestamptz,
  premium_purchased_at timestamptz,
  premium_transaction_id text,
  member_count integer DEFAULT 1,
  photo_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_events_join_code ON events(join_code) WHERE NOT is_deleted;
CREATE INDEX idx_events_creator ON events(creator_id) WHERE NOT is_deleted;
CREATE INDEX idx_events_expires ON events(expires_at) WHERE expires_at IS NOT NULL;


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
  username text NOT NULL,
  width integer,
  height integer,
  upload_status text DEFAULT 'pending'
    CHECK (upload_status IN ('pending', 'uploaded', 'failed')),
  is_flagged boolean DEFAULT false
);

CREATE INDEX idx_photos_event_time ON photos(event_id, captured_at);
CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_pending ON photos(upload_status)
  WHERE upload_status = 'pending';


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

### Column-by-Column Decisions

A few columns worth explaining so you always remember why they're there:

| Column | Why |
|--------|-----|
| `profiles.device_token` | APNs push token. Updated on every app launch. One column beats a whole device_tokens table at your scale |
| `events.ends_at` | Auto-calculated as `starts_at + 12hrs` at creation. Stored explicitly so you can offer custom durations as a future premium perk without a migration |
| `events.expires_at` | When the event auto-deletes. `NULL` for premium events (live forever). Makes the countdown UI and cleanup job trivial |
| `events.premium_purchased_at` | Audit trail. When did the host buy? Useful for support and debugging without a separate purchases table |
| `events.premium_transaction_id` | RevenueCat transaction ID. Proves the purchase happened. Two columns now saves you building a purchases table later |
| `events.member_count` / `photo_count` | Denormalized counts maintained by DB triggers. Avoids COUNT queries on every event card load |
| `photos.username` | Denormalized from profiles. Means the reveal feed never needs to JOIN profiles just to show who took the photo |
| `photos.width` / `height` | Lets the UI show correctly-sized placeholders before the image loads. Small detail that makes the reveal feel polished |
| `photos.is_flagged` | Moderation flag. Hide from feed, deal with later. You don't need a moderation system yet, but you need the ability to hide a photo |

---

## Key Query Patterns

Every query the app makes, grouped by how often it runs. If a query isn't listed here, you probably don't need it.

### High Frequency — Reveal Flow

This is the hot path. When 50 people open the reveal at the same time, these queries all fire simultaneously. They need to be fast.

```sql
-- Get paginated photos for event (reveal feed)
SELECT * FROM photos
WHERE event_id = $1
ORDER BY captured_at
LIMIT 20 OFFSET $2;

-- Check if user liked a photo (for heart icon state)
SELECT 1 FROM photo_likes
WHERE photo_id = $1 AND user_id = $2;

-- Like a photo (idempotent — won't duplicate)
INSERT INTO photo_likes (photo_id, user_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- Unlike a photo
DELETE FROM photo_likes
WHERE photo_id = $1 AND user_id = $2;

-- Get user's liked photos for an event
SELECT p.* FROM photos p
JOIN photo_likes pl ON p.id = pl.photo_id
WHERE p.event_id = $1 AND pl.user_id = $2
ORDER BY pl.created_at DESC;
```

Every one of these hits an index. The composite primary keys on `photo_likes` and the `idx_photos_event_time` index do the heavy lifting. You shouldn't need to think about performance here until you're well past 1000 users.

### Medium Frequency — Event Loading

```sql
-- Get user's events (home screen)
SELECT e.* FROM events e
JOIN event_members em ON e.id = em.event_id
WHERE em.user_id = $1 AND NOT e.is_deleted
ORDER BY e.created_at DESC;

-- Join event by code
INSERT INTO event_members (event_id, user_id)
SELECT id, $2 FROM events
WHERE join_code = $1 AND NOT is_deleted
ON CONFLICT DO NOTHING;

-- Get event by join code (for preview before joining)
SELECT * FROM events
WHERE join_code = $1 AND NOT is_deleted;
```

The `ON CONFLICT DO NOTHING` on the join query is important — it means tapping "Join" twice doesn't break anything. Idempotent operations save you from writing defensive code in Swift.

### Low Frequency — Stats & Profile

```sql
-- Total likes for an event (for event card + premium prompt)
SELECT COUNT(*) FROM photo_likes pl
JOIN photos p ON pl.photo_id = p.id
WHERE p.event_id = $1;

-- User's profile stats
SELECT
  (SELECT COUNT(*) FROM event_members WHERE user_id = $1) as events_joined,
  (SELECT COUNT(*) FROM photos WHERE user_id = $1) as photos_taken,
  (SELECT COUNT(*) FROM photo_likes WHERE user_id = $1) as photos_liked;

-- User number ("You're user #47!")
SELECT COUNT(*) FROM profiles
WHERE created_at <= (SELECT created_at FROM profiles WHERE id = $1);
```

The total likes query joins `photo_likes` to `photos` to filter by event. At your scale this is fast. If it ever gets slow, that's when you'd add a `like_count` column to events — but don't prematurely optimise.

### Cleanup — Edge Function

```sql
-- Find expired free events (daily cleanup job)
SELECT id FROM events
WHERE expires_at IS NOT NULL
  AND expires_at < now()
  AND NOT is_deleted;

-- Soft delete expired events
UPDATE events SET is_deleted = true
WHERE expires_at IS NOT NULL
  AND expires_at < now()
  AND NOT is_deleted;
```

Soft delete first (`is_deleted = true`), hard delete + storage cleanup as a separate job. Two-step gives you a safety net if something goes wrong.

---

## Row Level Security (RLS)

RLS is your backend. Since there's no API layer between the app and Supabase, these policies are the only thing stopping a user from reading someone else's photos or deleting someone else's event. Get these right.

### Profiles

| Action | Policy |
|--------|--------|
| Read | Any authenticated user can read any profile (needed to display usernames) |
| Update | Users can only update their own profile |
| Insert | Users can only insert their own profile (on signup) |

### Events

| Action | Policy |
|--------|--------|
| Read | Members can read events they belong to |
| Insert | Any authenticated user can create an event |
| Update | Only the creator can update (premium flag, soft delete) |

The creator check on update is critical — this is what stops a guest from marking an event as premium or deleting it.

### Event Members

| Action | Policy |
|--------|--------|
| Read | Members can see who else is in the event |
| Insert | Any authenticated user can join (the join code is the access control, not RLS) |
| Delete | Only the user themselves can leave an event |

### Photos

| Action | Policy |
|--------|--------|
| Read | Members of the event can read photos |
| Insert | Members of the event can upload photos |
| Delete | Only the photo owner can delete their photo |

The read policy on photos is where the "reveal" is enforced server-side. A user who isn't in the event can't query photos for it, even if they guess the event ID.

### Photo Likes

| Action | Policy |
|--------|--------|
| Read | Members of the event can read likes (for counts and "did I like this?") |
| Insert | Users can only insert their own likes |
| Delete | Users can only delete their own likes |

### Advice on RLS

Test every policy by hand before shipping. Log into Supabase, switch to a test user's context, and try to do things you shouldn't be able to. Read another event's photos. Delete someone else's event. Like a photo as a different user. If any of these work, your RLS has a hole. This is your entire security layer — there's no API to fall back on.

---

## Edge Functions

Server-side logic that can't live in the app. V1 needs three Edge Functions.

### 1. Event Cleanup (Daily)

Runs on a cron schedule (daily). Handles the free tier auto-delete.

**Logic:**
1. Find events where `expires_at < now()` and `is_deleted = false`
2. Set `is_deleted = true` on those events
3. Separate job: for events that have been `is_deleted = true` for 24+ hours, hard delete the rows and remove photos from storage

The 24-hour buffer between soft and hard delete is your safety net. If a user complains "my event disappeared," you have a window to recover it.

### 2. RevenueCat Webhook

Receives purchase confirmation from RevenueCat when a host buys premium.

**Logic:**
1. Verify the webhook signature (RevenueCat docs cover this)
2. Extract the event ID and transaction ID from the payload
3. Update the event: `is_premium = true`, `premium_purchased_at = now()`, `premium_transaction_id = transaction_id`, `expires_at = NULL`
4. Return 200

The client does not self-report premium status. The app can show an optimistic UI after purchase, but the database only gets updated by the webhook. This prevents someone from faking a purchase.

### 3. Push Notifications (Reveal Ready)

Triggers when an event hits its `release_at` time.

**Logic:**
1. Cron job checks for events where `release_at <= now()` and notification hasn't been sent
2. Fetch `device_token` for all members of the event via `event_members` → `profiles`
3. Send APNs push: "Your photos are ready to reveal!"

This is the least critical Edge Function for launch. Your first events will be with friends — you can literally text them "photos are ready." Build this after cleanup and RevenueCat are solid.

---

## Photo Storage

Photos live in Supabase Storage, not the database. The database stores the path, Storage holds the file.

### Bucket Structure

```
photos/
  {event_id}/
    {photo_id}.jpg
```

Simple flat structure per event. No user subfolders — you don't need them and they complicate cleanup.

### Signed URLs

Photos are never publicly accessible. The app requests a signed URL from Supabase when it needs to display a photo. Signed URLs expire after a set period.

- **App:** Short-lived signed URLs (1 hour)
- **Web album:** Longer-lived signed URLs (7 days) generated by the API route

### Upload Flow

1. User takes photo in app
2. Photo saved locally first (offline support)
3. Background upload to Supabase Storage
4. On success: insert row into `photos` table with `upload_status = 'uploaded'`
5. On failure: row stays as `upload_status = 'pending'`, retry on next app launch

The `idx_photos_pending` index exists specifically so you can quickly find failed uploads to retry. This is one of those small things that makes the app feel reliable.

### Cleanup

When an event is hard deleted, its photos need to be removed from Storage too. The cleanup Edge Function handles this — delete the `photos/{event_id}/` folder from Storage after hard deleting the database rows.

---

## Data Architecture: What Lives Where

Every time you think "where should I store this?" — check this table.

| Question | Answer | Where |
|----------|--------|-------|
| Does this user have access to this event? | Database | `event_members` |
| How many times did users open the reveal? | Analytics | PostHog |
| Show me photos I liked | Database | `photo_likes` |
| What's the most downloaded photo? | Analytics | PostHog |
| Is this event premium? | Database | `events.is_premium` |
| How many premium events this month? | Analytics | PostHog |
| How many members in this event? | Database | `events.member_count` |
| What's our conversion rate? | Analytics | PostHog |
| Did this user join this event? | Database | `event_members` |
| Where do users drop off in the reveal? | Analytics | PostHog |

**The rule of thumb:** If the app needs it to function (access control, displaying content, gating features), it's database. If you need it to make business decisions, it's PostHog.

### Why This Matters

The previous schema had denormalized counters for things like download counts and view counts on database rows. That's the path to a slow, bloated database. PostHog calls are fire-and-forget — they queue locally on the device, batch every 30 seconds, and sync in the background. Zero database load.

During reveal, when 50 people are loading photos simultaneously:
- **Database approach to tracking:** 500 UPDATE queries fighting for row locks
- **PostHog approach:** 500 events batched async, database doesn't even know it's happening

### PostHog Events To Track in V1

```swift
// Engagement (for future smart triggers + business decisions)
capture("photo_downloaded", ["photo_id", "event_id"])
capture("photo_shared", ["photo_id", "event_id", "destination"])
capture("photo_liked", ["photo_id", "event_id"])
capture("reveal_started", ["event_id", "photo_count"])
capture("reveal_completed", ["event_id", "duration_seconds"])

// Business
capture("event_created", ["event_id"])
capture("premium_prompt_shown", ["event_id"])
capture("premium_prompt_dismissed", ["event_id"])
capture("premium_purchased", ["event_id", "price"])

// Growth
capture("web_album_opened", ["event_id"])
capture("web_album_photo_downloaded", ["event_id"])
capture("web_album_cta_shown", ["event_id"])
capture("web_album_cta_tapped", ["event_id"])
```

You don't need to build dashboards on day one. Just fire the events. The data accumulates in PostHog and you can slice it whenever you're ready. Getting the tracking in early means you'll have data from your very first users — that's gold when you're making decisions later.

---

## Security Checklist

No API layer means your security surface is: RLS policies, signed URLs, and Edge Function webhook verification. That's it. Keep it tight.

### V1 Non-Negotiables

- [ ] **Every table has RLS enabled** — Supabase lets you create tables without RLS. If you forget to enable it, that table is publicly readable. Check this for every table.
- [ ] **Test RLS from a different user's context** — Log into Supabase, impersonate a test user, try to read photos from an event they're not in. If it works, fix it before shipping.
- [ ] **RevenueCat webhook verifies signature** — Don't just accept any POST request that says "this event is premium." Verify it came from RevenueCat.
- [ ] **Signed URLs for all photo access** — No public bucket URLs. Ever. Even if it's "just for testing."
- [ ] **Service role key stays server-side only** — The Next.js web album uses the service role key in API routes. This key must never appear in client-side code or be committed to git.

### Things You Don't Need To Worry About Yet

- Rate limiting — your scale doesn't warrant it
- IP blocking — not a concern at friends-and-family stage
- DDOS protection — Supabase and Vercel handle this at the infrastructure level
- Audit logging — the `premium_purchased_at` and PostHog events cover your needs

Security at your stage is about getting the basics bulletproof, not building a fortress. RLS and signed URLs are your two walls. Make sure they have no holes. Everything else can wait.

---

## What's NOT In V1

Explicitly out of scope. If any of these come up in future sessions, they should be treated as new scope with their own design docs.

### Database
- **Keepsakes/badges tables** — deferred until the concept is validated
- **Reveal progress tracking** — handled client-side, not in the database
- **Reactions (emoji) on photos** — cut from v1, the JSONB `reactions` column is gone
- **Location data on events** — removed, add back only if UX requires it
- **Event descriptions** — removed, the event name is enough for v1
- **Photo file_size / device_type columns** — removed, not used anywhere

### Backend
- **Realtime subscriptions** — Supabase supports live updates but v1 doesn't need them. Users refresh manually.
- **Database functions (RPC)** — complex aggregation queries can be wrapped in Postgres functions for performance. Not needed at current scale.
- **CDN for photos** — Supabase Storage with signed URLs is enough. CDN optimisation is a scale problem.
- **Multi-region** — single region is fine until you have international users
- **Admin dashboard** — manage directly in Supabase console for now
- **Data warehouse** — PostHog handles all analytics needs at this stage
