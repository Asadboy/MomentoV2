-- Drop idx_photos_pending. The advisor flagged it as unused (zero scans
-- across the full lifetime of the database) and a Swift-side audit confirmed
-- nothing queries `photos WHERE upload_status = 'pending'`. The OfflineSync
-- queue tracks pending uploads client-side, not via the database.
--
-- The other "unused" indexes flagged by the advisor (idx_events_creator,
-- idx_events_join_code, idx_events_release_at, idx_events_starts_at,
-- idx_events_ends_at) are kept on purpose: the events table currently has
-- ~7 rows so Postgres correctly seq-scans for everything, but each of those
-- indexes covers a real query path (creator filtering, join-code lookup,
-- state-machine date comparisons). They will start being used as soon as
-- the table grows.

DROP INDEX IF EXISTS public.idx_photos_pending;
