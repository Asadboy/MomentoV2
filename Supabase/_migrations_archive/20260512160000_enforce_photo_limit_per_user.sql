-- =====================================================================
-- Server-side enforcement of the 10-shot-per-user-per-event limit.
-- =====================================================================
-- Until now the limit was client-side only (CameraView + a getPhotoCount
-- pre-check in OfflineSyncManager). Both checks have TOCTOU windows --
-- a hacked client or a fast-tapping race can fire N concurrent uploads
-- that all observe count=0 and all succeed.
--
-- This trigger fires BEFORE INSERT on photos, takes a transaction-scoped
-- advisory lock keyed on (event_id, user_id), counts existing rows, and
-- rejects if the count is already at or above PHOTO_LIMIT. The lock
-- serialises concurrent inserts from the same user-in-event so the
-- count is genuinely atomic.
--
-- Errors raise SQLSTATE 'P0010' with message 'photo_limit_reached' so
-- the Swift client can distinguish this from generic insert failures.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.enforce_photo_limit_per_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  photo_limit CONSTANT INTEGER := 10;
  lock_key BIGINT;
  current_count INTEGER;
BEGIN
  -- Per-(event,user) advisory lock. Hash both into a single bigint so we
  -- can use the single-arg form (the two-int form requires a 32-bit
  -- key + a class id and uuid->int32 collisions are likelier).
  -- pg_advisory_xact_lock releases on COMMIT or ROLLBACK automatically.
  lock_key := hashtextextended(NEW.event_id::text || ':' || NEW.user_id::text, 0);
  PERFORM pg_advisory_xact_lock(lock_key);

  SELECT count(*) INTO current_count
  FROM public.photos
  WHERE event_id = NEW.event_id
    AND user_id = NEW.user_id;

  IF current_count >= photo_limit THEN
    RAISE EXCEPTION 'photo_limit_reached'
      USING ERRCODE = 'P0010',
            HINT = 'Each member can take at most 10 shots per event.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_photo_limit_per_user ON public.photos;
CREATE TRIGGER enforce_photo_limit_per_user
  BEFORE INSERT ON public.photos
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_photo_limit_per_user();
