-- =====================================================================
-- Remove user-visible username requirement; display_name becomes primary
-- =====================================================================
-- Rationale: handles are out of the product. Display names are the only
-- identity surface. `username` stays as a dormant column in case we ever
-- reintroduce handles post-launch.
--
-- Pre-state (live, verified via list_tables 2026-05-12):
--   profiles.username        NOT NULL UNIQUE   ->  NULLABLE UNIQUE (dormant)
--   profiles.display_name    NULLABLE          ->  NOT NULL
--   profiles.updated_at (NEW)                  ->  TIMESTAMPTZ NOT NULL DEFAULT now()
--   profiles.profile_setup_complete (NEW)      ->  BOOLEAN NOT NULL DEFAULT FALSE
--   photos.captured_by (NEW)                   ->  TEXT NOT NULL
--   photos.username          NOT NULL          ->  NULLABLE (dormant)
--
-- Touches 13 profile rows + 560 photo rows.
-- =====================================================================

-- 0. Fix the existing broken update_updated_at_column() trigger on
--    profiles. The trigger has been live but its target column was never
--    actually added -- every profile UPDATE would have failed. Adding
--    the column now also gives us a cache-buster for avatar URLs.
ALTER TABLE public.profiles
  ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- 1. profile_setup_complete column. Routes auto-generated users through
--    ProfileSetupView; real users skip it.
ALTER TABLE public.profiles
  ADD COLUMN profile_setup_complete BOOLEAN NOT NULL DEFAULT FALSE;

-- Mark existing users with non-auto-generated handles as set-up so they
-- don't get re-prompted. The createProfile flow appends a random 4-digit
-- suffix (1000..9999) to OAuth emails, so that pattern == "never customised".
UPDATE public.profiles
SET profile_setup_complete = TRUE
WHERE username !~ '\d{4}$';

-- 2. display_name: backfill from username for any NULL rows, then NOT NULL.
UPDATE public.profiles
SET display_name = username
WHERE display_name IS NULL OR display_name = '';

ALTER TABLE public.profiles
  ALTER COLUMN display_name SET NOT NULL;

-- 3. username: drop NOT NULL. Keep UNIQUE so the column remains
--    reservable if we ever bring handles back.
ALTER TABLE public.profiles
  ALTER COLUMN username DROP NOT NULL;

COMMENT ON COLUMN public.profiles.username IS
  'Dormant. Kept as a handle slot in case @-handles are reintroduced.';

-- 4. photos.captured_by: new attribution column for reveal display.
ALTER TABLE public.photos
  ADD COLUMN captured_by TEXT;

UPDATE public.photos ph
SET captured_by = COALESCE(
  (SELECT display_name FROM public.profiles WHERE id = ph.user_id),
  ph.username
);

ALTER TABLE public.photos
  ALTER COLUMN captured_by SET NOT NULL;

-- 5. photos.username: drop NOT NULL (kept for legacy rows only).
ALTER TABLE public.photos
  ALTER COLUMN username DROP NOT NULL;

COMMENT ON COLUMN public.photos.username IS
  'Dormant legacy column. New reads/writes use captured_by.';

-- 6. handle_new_user: replace email fallback with a random handle and
--    explicit profile_setup_complete = FALSE. Fixes review H8 (any
--    authenticated user could read other users' emails via display_name)
--    in the same migration.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  random_handle TEXT;
BEGIN
  random_handle := 'user_' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO public.profiles (id, username, display_name, profile_setup_complete)
  VALUES (NEW.id, random_handle, random_handle, FALSE);
  RETURN NEW;
END;
$$;

-- 7. avatars storage bucket -- public-read via URL (no SELECT policy
--    needed; see follow-up migration), owner-write.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', TRUE)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "avatars_owner_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_owner_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_owner_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
