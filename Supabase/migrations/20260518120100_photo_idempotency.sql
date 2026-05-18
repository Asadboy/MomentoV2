-- =====================================================================
-- Idempotency key for photo uploads.
-- =====================================================================
-- The offline upload queue can re-attempt an upload that already
-- succeeded (a kill between network-success and queue-persist; a race
-- between the immediate detached upload and processQueue). Without a
-- stable key each retry inserts a duplicate row, silently burning one
-- of the user's 10 shots.
--
-- The client supplies the QueuedPhoto UUID as client_upload_id. The
-- upload uses upsert(..., ignoreDuplicates: true) on this column so a
-- duplicate insert becomes a server-side no-op. Nullable + partial
-- unique index so legacy rows (NULL) are unaffected.
-- =====================================================================

ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS client_upload_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS photos_client_upload_id_key
  ON public.photos (client_upload_id)
  WHERE client_upload_id IS NOT NULL;
