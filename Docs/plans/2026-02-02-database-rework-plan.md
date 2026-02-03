# Database Schema Rework Plan

**Date:** 2026-02-02
**Status:** SUPERSEDED - See `Docs/Momento-Backend-Stack.md` for final schema and implementation plan

## Context

Momento is an iOS app where users:
1. Join shared albums (events) via join code
2. Take photos during the event window
3. Photos upload in background
4. At reveal time, everyone sees all photos in a swipeable feed

**Current scale:** ~10 users
**Target scale:** 1000+ users

The reveal flow is the highest stress point - everyone loads photos simultaneously.

---

## Current Schema (From Supabase)

```sql
-- PROFILES: User accounts (extends auth.users)
CREATE TABLE public.profiles (
  id uuid NOT NULL,                          -- Links to auth.users.id
  username text NOT NULL UNIQUE,
  first_name text,
  last_name text,
  display_name text,
  avatar_url text,
  is_premium boolean DEFAULT false,
  total_events_joined integer DEFAULT 0,     -- Denormalized count
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- EVENTS: Shared albums / Momentos
CREATE TABLE public.events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  creator_id uuid NOT NULL,
  join_code text NOT NULL UNIQUE,
  release_at timestamp with time zone NOT NULL,  -- When photos reveal
  created_at timestamp with time zone DEFAULT now(),
  is_private boolean DEFAULT false,
  is_corporate boolean DEFAULT false,
  max_photos_per_user integer DEFAULT 9999,
  location_name text,
  location_lat double precision,
  location_lng double precision,
  description text,
  member_count integer DEFAULT 1,            -- Denormalized count
  photo_count integer DEFAULT 0,             -- Denormalized count
  is_revealed boolean DEFAULT false,
  reveal_job_scheduled boolean DEFAULT false,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  is_deleted boolean DEFAULT false,
  CONSTRAINT events_pkey PRIMARY KEY (id),
  CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES auth.users(id)
);

-- EVENT_MEMBERS: Who joined which album
CREATE TABLE public.event_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid,
  user_id uuid,
  joined_at timestamp with time zone DEFAULT now(),
  invited_by uuid,
  role text DEFAULT 'member'::text,
  CONSTRAINT event_members_pkey PRIMARY KEY (id),
  CONSTRAINT event_members_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT event_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT event_members_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id)
);

-- PHOTOS: The actual photos
CREATE TABLE public.photos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid,
  user_id uuid,
  storage_path text NOT NULL,
  file_size integer,
  captured_at timestamp with time zone DEFAULT now(),
  captured_by_username text,                 -- Denormalized from profiles
  device_type text,
  is_revealed boolean DEFAULT false,
  upload_status text DEFAULT 'pending'::text,
  width integer,
  height integer,
  reactions jsonb DEFAULT '{}'::jsonb,       -- {"user_id": "emoji"}
  CONSTRAINT photos_pkey PRIMARY KEY (id),
  CONSTRAINT photos_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT photos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- PHOTO_INTERACTIONS: Likes and archives
CREATE TABLE public.photo_interactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  photo_id uuid,
  user_id uuid,
  status text NOT NULL CHECK (status = ANY (ARRAY['liked'::text, 'archived'::text])),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT photo_interactions_pkey PRIMARY KEY (id),
  CONSTRAINT photo_interactions_photo_id_fkey FOREIGN KEY (photo_id) REFERENCES public.photos(id),
  CONSTRAINT photo_interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- USER_REVEAL_PROGRESS: Tracks swipe position in reveal feed
CREATE TABLE public.user_reveal_progress (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid,
  user_id uuid,
  last_photo_index integer NOT NULL DEFAULT 0,
  completed boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_reveal_progress_pkey PRIMARY KEY (id),
  CONSTRAINT user_reveal_progress_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT user_reveal_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- KEEPSAKES: Achievement badges
CREATE TABLE public.keepsakes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  artwork_url text NOT NULL,
  flavour_text text,
  event_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT keepsakes_pkey PRIMARY KEY (id),
  CONSTRAINT keepsakes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);

-- USER_KEEPSAKES: Who earned which badge
CREATE TABLE public.user_keepsakes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  keepsake_id uuid NOT NULL,
  earned_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_keepsakes_pkey PRIMARY KEY (id),
  CONSTRAINT user_keepsakes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_keepsakes_keepsake_id_fkey FOREIGN KEY (keepsake_id) REFERENCES public.keepsakes(id)
);
```

---

## Problems Identified

### Schema Bloat
- 8 tables for relatively simple functionality
- `photos.reactions` JSONB duplicates what `photo_interactions` could do
- `user_reveal_progress` tracks index position but photos can change order
- Multiple denormalized fields that need trigger maintenance

### Missing Indexes for Key Queries
```sql
-- Reveal feed query needs:
(event_id, captured_at)  -- For ordered photo fetch

-- Liked photos query needs:
(user_id, status) on photo_interactions

-- Progress tracking needs:
(user_id, event_id) UNIQUE on user_reveal_progress
```

### N+1 Query Problems in App Code
The app makes 13+ sequential queries for profile stats because there's no database function to aggregate. Similarly:
- `getUserKeepsakes()` - one query per keepsake for rarity count
- `getLikedPhotos()` - sequential signed URL generation
- No batch operations

### Architectural Questions
1. Is `is_revealed` on both `events` AND `photos` necessary?
2. Is `user_reveal_progress` tracking by index fragile? (What if photos deleted?)
3. Should reactions be in JSONB or separate table?
4. Is `keepsakes` system needed at MVP scale?

---

## What's Needed

### From User
A simplified schema proposal that reflects how the app actually works:
- What tables are truly needed?
- What columns per table?
- What's essential vs nice-to-have?

### Then Claude Will
1. Review and refine the proposed schema
2. Add appropriate indexes for query patterns
3. Create database functions for complex operations (e.g., `get_user_stats()`)
4. Write migration SQL to transform current → new schema
5. Update iOS app code to match

---

## App Query Patterns to Optimize For

### High Frequency (Reveal Flow)
```
1. Get paginated photos for event, ordered by captured_at
2. Get/update user's reveal progress for event
3. Like/unlike a photo
4. Get user's liked photos for event
```

### Medium Frequency
```
1. Get user's events (as member or creator)
2. Get event details by join code
3. Upload photo to event
4. Get event member list
```

### Low Frequency
```
1. Get user profile stats
2. Get user's keepsakes
3. Create/delete event
```

---

## Next Steps

1. User proposes simplified schema
2. Collaborative refinement
3. Create migration plan
4. Update iOS app code

---

## iOS Code Files That Will Need Updates

After schema changes, these files need modification:

- `Services/SupabaseManager.swift` - All database queries
- `Models/Event.swift` - If Event model changes
- `Features/Reveal/*` - If reveal progress tracking changes
- `Features/Profile/*` - If stats/keepsakes change
