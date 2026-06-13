-- =====================================================================
-- Exempt idempotent upload retries from the per-user photo limit.
-- =====================================================================
-- enforce_photo_limit_per_user() is a BEFORE INSERT trigger that fires
-- before ON CONFLICT (client_upload_id) DO NOTHING can no-op a
-- duplicate. Without this guard, retrying an already-succeeded final
-- (10th) shot — app killed before the queue marked it complete, or a
-- double-fire race — is rejected with P0010 and the client falsely
-- reports the shot as "not uploaded — limit reached" (the row is
-- actually on the server). This adds an early RETURN NEW when a row
-- with the same client_upload_id already exists: the accompanying
-- upsert-ignore makes the INSERT a true no-op, so letting the trigger
-- pass is correct and the limit is still enforced for genuine new
-- uploads. Everything else is byte-identical to
-- 20260512160000_enforce_photo_limit_per_user.sql.
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
  -- Idempotent retry: a row with this client_upload_id already exists,
  -- so the accompanying ON CONFLICT (client_upload_id) DO NOTHING makes
  -- this INSERT a no-op. Allow it through rather than falsely raising
  -- the limit on a shot that already uploaded.
  IF NEW.client_upload_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.photos
    WHERE client_upload_id = NEW.client_upload_id
  ) THEN
    RETURN NEW;
  END IF;

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
