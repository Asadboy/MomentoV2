-- One-off data cleanup before launch:
--   - Soft-delete (is_deleted = true) the 5 events with sentimental data
--     so they stay queryable but disappear from the UI.
--   - Hard-delete the 7 leftover test events (cascades to event_members,
--     photos, photo_likes via FK ON DELETE CASCADE).
--
-- Storage objects in the momento-photos bucket are NOT deleted here —
-- Supabase blocks direct DELETE on storage.objects (protect_delete
-- trigger). The orphan storage objects for the deleted events should be
-- cleaned up via the Supabase Dashboard or Storage REST API. For ~7
-- events × ~50 photos × ~250KB that's ~9MB of orphan data, acceptable
-- short-term and will be swept at launch.

DO $$
DECLARE
  to_delete UUID[];
  deleted_count INT;
BEGIN
  SELECT array_agg(id) INTO to_delete
  FROM public.events
  WHERE name NOT IN (
    'Lakes',
    'Sopranos Party',
    'Hijack x DoubleDip',
    'Beffy x Mall Grab',
    'Milano'
  );

  DELETE FROM public.events
  WHERE id = ANY(to_delete);

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Hard-deleted % events plus cascaded rows', deleted_count;

  UPDATE public.events
  SET is_deleted = true
  WHERE name IN (
    'Lakes',
    'Sopranos Party',
    'Hijack x DoubleDip',
    'Beffy x Mall Grab',
    'Milano'
  );
END $$;
