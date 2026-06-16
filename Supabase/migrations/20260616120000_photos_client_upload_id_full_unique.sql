-- =====================================================================
-- Make photos.client_upload_id's unique index FULL (was partial).
-- =====================================================================
-- The app upserts photo rows with PostgREST `?on_conflict=client_upload_id`
-- (ignoreDuplicates -> ON CONFLICT (client_upload_id) DO NOTHING) for
-- idempotent upload retries. The idempotency migration
-- (_migrations_archive/20260518120100_photo_idempotency.sql) created a
-- PARTIAL unique index (WHERE client_upload_id IS NOT NULL).
--
-- Postgres refuses to use a partial unique index as an ON CONFLICT arbiter
-- unless the statement repeats the index predicate, which PostgREST cannot
-- emit. So every idempotent upsert failed with SQLSTATE 42P10 ("there is no
-- unique or exclusion constraint matching the ON CONFLICT specification")
-- -> HTTP 400. The storage object uploaded but the photos row never
-- inserted (then got orphan-cleaned), surfacing as "shots couldn't upload".
-- This regressed when the client switched .insert -> .upsert in PR #58.
--
-- A FULL unique index on a nullable column still allows unlimited NULLs
-- (NULLS DISTINCT is the default, so legacy NULL rows are unaffected) AND
-- is a valid ON CONFLICT arbiter. Uniqueness of real client_upload_id
-- values is preserved exactly as before.
-- =====================================================================

DROP INDEX IF EXISTS public.photos_client_upload_id_key;

CREATE UNIQUE INDEX photos_client_upload_id_key
  ON public.photos (client_upload_id);
