-- Add username column to photos for capture-time attribution.
-- The Swift client (PhotoModel, fetchPhotosForRevealPaginated, getLikedPhotos,
-- uploadPhoto) has been writing/reading this column, but it never existed in
-- the live schema, causing PostgREST 42703 errors and silent insert failures.

ALTER TABLE public.photos
  ADD COLUMN username TEXT;

UPDATE public.photos ph
SET username = p.username
FROM public.profiles p
WHERE p.id = ph.user_id
  AND ph.username IS NULL;

ALTER TABLE public.photos
  ALTER COLUMN username SET NOT NULL;
