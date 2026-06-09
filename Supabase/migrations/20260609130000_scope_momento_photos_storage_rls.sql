-- =====================================================================
-- Scope momento-photos storage policies back to event membership.
-- =====================================================================
-- The live bucket had three bucket-wide policies (INSERT / SELECT /
-- UPDATE gated only on bucket_id = 'momento-photos'), created out-of-band
-- and captured in no migration: any authenticated user could read,
-- upload, or overwrite ANY photo object given its path. Privacy rested
-- entirely on event UUIDs being unguessable.
--
-- Why they existed: the original membership-scoped policies in
-- 20241109000002_storage.sql compared (storage.foldername(name))[1]
-- (uppercase — Swift UUID.uuidString) against event_id::text (lowercase),
-- so every legitimate upload was rejected and the policies were opened
-- wide instead of fixed. Same bug class as the avatars fix in
-- 20260512200000_avatar_policies_case_insensitive.sql.
--
-- Fix: case-insensitive membership scoping. The app's storage surface is
--   * upload:  upsert to <EVENT_ID>/<PHOTO_ID>.jpg (uppercase) — needs
--              INSERT and, for idempotent retries, UPDATE on own path
--   * read:    createSignedURL — needs SELECT as the requesting user
--   * delete:  creators only — existing "Creators can delete photos"
--              policy is correct and untouched.

DROP POLICY IF EXISTS "Authenticated users can upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update photos" ON storage.objects;
-- Repo-final names from 20241109000002 (not live, but make this replayable):
DROP POLICY IF EXISTS "Users can upload photos to their events" ON storage.objects;
DROP POLICY IF EXISTS "Users can view photos from their events" ON storage.objects;

CREATE POLICY "Members can upload photos to their events"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'momento-photos'
  AND lower((storage.foldername(name))[1]) IN (
    SELECT lower(event_id::text) FROM public.event_members
    WHERE user_id = (SELECT auth.uid())
  )
);

CREATE POLICY "Members can view photos from their events"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'momento-photos'
  AND lower((storage.foldername(name))[1]) IN (
    SELECT lower(event_id::text) FROM public.event_members
    WHERE user_id = (SELECT auth.uid())
  )
);

-- Upsert retries rewrite the same <EVENT_ID>/<PHOTO_ID>.jpg path, so
-- UPDATE stays — scoped to the uploader's own objects in their events.
CREATE POLICY "Members can update their own photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'momento-photos'
  AND owner = (SELECT auth.uid())
  AND lower((storage.foldername(name))[1]) IN (
    SELECT lower(event_id::text) FROM public.event_members
    WHERE user_id = (SELECT auth.uid())
  )
);
