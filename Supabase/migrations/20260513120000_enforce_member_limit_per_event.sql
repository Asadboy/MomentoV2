-- =====================================================================
-- Server-side enforcement of events.member_limit on event_members INSERT.
-- =====================================================================
-- The RLS-based cap was dropped in 20260511150000_drop_cross_table_cap_from_rls.sql
-- because Postgres flagged the events <-> event_members cross-table subquery
-- as recursive even with a SECURITY DEFINER helper. The Swift client still
-- pre-checks the count and surfaces "This event is full" but that path is
-- bypassable and has a TOCTOU window two simultaneous joins could exploit.
--
-- This trigger fires BEFORE INSERT on event_members, takes a per-event
-- advisory lock, reads events.member_limit, counts existing members, and
-- rejects if the count is already at or above the cap. Mirrors the pattern
-- shipped in 20260512160000_enforce_photo_limit_per_user.sql — the only
-- differences are the lock key (per-event, not per-(event,user)) and the
-- limit being read from the events row rather than a constant.
--
-- Errors raise SQLSTATE 'P0011' with message 'member_limit_reached' so
-- the Swift client can distinguish this from generic insert failures.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.enforce_member_limit_per_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  cap INTEGER;
  lock_key BIGINT;
  current_count INTEGER;
BEGIN
  -- Per-event advisory lock. Serialises concurrent joins to the same event
  -- so the count is atomic; releases on COMMIT or ROLLBACK.
  lock_key := hashtextextended(NEW.event_id::text, 0);
  PERFORM pg_advisory_xact_lock(lock_key);

  SELECT member_limit INTO cap
  FROM public.events
  WHERE id = NEW.event_id;

  -- If the event doesn't exist, fall through and let the FK constraint
  -- raise the canonical error rather than masking it with our custom one.
  IF cap IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO current_count
  FROM public.event_members
  WHERE event_id = NEW.event_id;

  IF current_count >= cap THEN
    RAISE EXCEPTION 'member_limit_reached'
      USING ERRCODE = 'P0011',
            HINT = 'This event is full.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_member_limit_per_event ON public.event_members;
CREATE TRIGGER enforce_member_limit_per_event
  BEFORE INSERT ON public.event_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_member_limit_per_event();
