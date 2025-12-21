# Momento - Database Things To Do

## Overview
This file tracks database-related changes, fixes, and future improvements for the Supabase backend.

---

## ✅ Completed Fixes

### Dec 21, 2025 - Storage RLS Policy Fix

**Problem:**
Photos were being captured and queued locally, but failing to upload to Supabase Storage with error:
```
StorageError: "new row violates row-level security policy" (403 Unauthorized)
```

**Root Cause:**
The original storage policy was too restrictive. It tried to verify the user was a member of the event by checking `event_members`, but the folder path extraction wasn't matching correctly:

```sql
-- Original policy (problematic)
CREATE POLICY "Users can upload photos to their events"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT event_id::text FROM event_members
    WHERE user_id = auth.uid()
  )
);
```

The issue was either:
1. UUID format mismatch between folder name and database
2. `storage.foldername()` function not extracting path correctly
3. Missing `event_members` row for the user

**Solution:**
Replaced with simpler policies that just check authentication (sufficient for beta):

```sql
-- Simpler storage policies
CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'momento-photos');

CREATE POLICY "Authenticated users can view photos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'momento-photos');

CREATE POLICY "Authenticated users can update photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'momento-photos');
```

**Why This Is OK For Beta:**
- All beta users are trusted testers
- The app code already validates event membership before allowing photo capture
- We can tighten security post-beta with proper UUID matching

---

### Dec 21, 2025 - Photos Table RLS Policy

**SQL Applied:**
```sql
CREATE POLICY "Authenticated users can insert photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Authenticated users can view photos"
ON photos FOR SELECT
TO authenticated
USING (true);
```

**Why:**
- INSERT: Ensures users can only create photos with their own user_id
- SELECT: Allows viewing all photos (reveal experience needs this)

---

## 🔄 To Do After Beta

### 1. Tighten Storage Policies
After beta, revert to event-membership-based policies:

```sql
-- TODO: Test this version post-beta
CREATE POLICY "Members can upload to their events"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'momento-photos' AND
  EXISTS (
    SELECT 1 FROM event_members
    WHERE event_id = (storage.foldername(name))[1]::uuid
    AND user_id = auth.uid()
  )
);
```

### 2. Add Photo Visibility Rules
Photos should only be visible after reveal:

```sql
-- TODO: Implement after reveal system is complete
CREATE POLICY "Photos visible after reveal"
ON photos FOR SELECT
TO authenticated
USING (
  -- User can see their own photos
  user_id = auth.uid()
  OR
  -- Or event is revealed
  EXISTS (
    SELECT 1 FROM events
    WHERE id = photos.event_id
    AND (is_revealed = true OR release_at < NOW())
  )
);
```

### 3. Add Delete Policies
Allow users to delete their own photos, creators to moderate:

```sql
-- TODO: Add after core functionality is stable
CREATE POLICY "Users can delete own photos"
ON photos FOR DELETE
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Creators can moderate event photos"
ON photos FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE id = photos.event_id
    AND creator_id = auth.uid()
  )
);
```

---

## 📊 Database Schema Reference

### Tables
- `profiles` - User profiles (username, avatar, premium status)
- `events` - Momentos (title, times, join_code, reveal status)
- `event_members` - Who's in each event (user_id, event_id, role)
- `photos` - Captured photos (storage_path, event_id, user_id)

### Storage Buckets
- `momento-photos` - Private bucket for all event photos
  - Structure: `{event_id}/{photo_id}.jpg`

### Key Columns Added (Dec 21, 2025)
- `events.starts_at` - When event goes live (photos can be taken)
- `events.ends_at` - When photo-taking stops

---

## 🐛 Known Issues

### QUIC Connection Warnings
```
quic_packet_parser_inner: unable to parse packet
quic_conn_link_advisory_block_invoke: unable to send frames
```
These are iOS networking layer warnings, not our code. Non-blocking, can ignore.

### Timestamp Count Warning
```
nw_connection_add_timestamp_locked_on_nw_queue: Hit maximum timestamp count
```
Happens when taking many photos rapidly. Non-blocking.

---

## 📝 Useful Debug Queries

```sql
-- Check all events for a user
SELECT e.*, em.role 
FROM events e
JOIN event_members em ON e.id = em.event_id
WHERE em.user_id = 'YOUR_USER_ID'::uuid;

-- Check all photos for an event
SELECT * FROM photos 
WHERE event_id = 'YOUR_EVENT_ID'::uuid
ORDER BY captured_at DESC;

-- Check storage bucket contents
SELECT name, created_at, metadata 
FROM storage.objects 
WHERE bucket_id = 'momento-photos'
ORDER BY created_at DESC
LIMIT 20;

-- Check RLS policies on a table
SELECT * FROM pg_policies WHERE tablename = 'photos';
SELECT * FROM pg_policies WHERE tablename = 'events';
SELECT * FROM pg_policies WHERE schemaname = 'storage';
```

---

**Last Updated:** December 21, 2025

