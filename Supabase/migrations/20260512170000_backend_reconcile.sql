-- =====================================================================
-- Backend reconcile: missing photo_likes baseline, dead column drop,
-- storage bucket MIME + size constraints.
-- =====================================================================
-- The local Supabase/migrations/ folder is missing a CREATE for the
-- photo_likes table -- it was applied directly via MCP a while back and
-- never captured locally. This migration is idempotent on live (the
-- table already exists; everything uses IF NOT EXISTS / OR REPLACE)
-- but means a fresh `supabase db reset` produces a working schema.
--
-- Also:
--   - profiles.device_token is unused (push not wired in) and was a
--     review-flagged privacy leak via the permissive profiles SELECT
--     policy. Drop it now; reintroduce properly when push lands.
--   - momento-photos bucket gets a MIME allowlist + 8 MiB cap, avatars
--     gets a 2 MiB cap. Both restrict to image/jpeg (the only thing
--     the app uploads).
-- =====================================================================

-- 1. photo_likes table baseline (idempotent).
CREATE TABLE IF NOT EXISTS public.photo_likes (
  photo_id UUID NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (photo_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_photo_likes_user ON public.photo_likes(user_id);

ALTER TABLE public.photo_likes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='photo_likes' AND policyname='Users can view likes') THEN
    CREATE POLICY "Users can view likes" ON public.photo_likes
      FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='photo_likes' AND policyname='Users can like photos') THEN
    CREATE POLICY "Users can like photos" ON public.photo_likes
      FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='photo_likes' AND policyname='Users can unlike photos') THEN
    CREATE POLICY "Users can unlike photos" ON public.photo_likes
      FOR DELETE USING ((SELECT auth.uid()) = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='photo_likes' AND policyname='Users can update own likes') THEN
    CREATE POLICY "Users can update own likes" ON public.photo_likes
      FOR UPDATE USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;
END $$;

-- 2. Drop the dead device_token column. Push notifications aren't wired
-- in (BACKLOG: v1.1) and the column was readable by every authenticated
-- user via the permissive profiles SELECT policy. Cleaner to drop now
-- and add back inside a properly-isolated table when push lands.
ALTER TABLE public.profiles DROP COLUMN IF EXISTS device_token;

-- 3. Storage bucket constraints. The app only ever uploads JPEG; refuse
-- everything else at the bucket level so a hacked client can't park
-- arbitrary 50 MiB blobs in our storage.
UPDATE storage.buckets
SET file_size_limit = 8 * 1024 * 1024,
    allowed_mime_types = ARRAY['image/jpeg']::text[]
WHERE id = 'momento-photos';

UPDATE storage.buckets
SET file_size_limit = 2 * 1024 * 1024,
    allowed_mime_types = ARRAY['image/jpeg']::text[]
WHERE id = 'avatars';
