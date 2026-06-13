-- =====================================================================
-- No member cap at launch: member_limit = 0 means "unlimited".
-- =====================================================================
-- Decision (2026-05-17): events must NOT cap how many people can join at
-- launch. The member_limit column is kept as the hook for future
-- monetisation tiers (5/10/25), but until those ship the launch value is
-- the sentinel 0 = unlimited.
--
-- Three changes, all backward-safe:
--   1. Column default flips 10 -> 0 so new events created by any path are
--      uncapped by default.
--   2. Existing rows are backfilled to 0. Their only future meaning is a
--      monetisation tier, which will overwrite per-event at purchase time.
--   3. enforce_member_limit_per_event() is taught that cap <= 0 (and the
--      pre-existing NULL case) means "no cap" -> RETURN NEW. Without this
--      the trigger's `current_count >= cap` test would reject the very
--      first join (0 >= 0), including the event creator.
--
-- The trigger itself stays bound; only the function body changes. When
-- monetisation lands, writing a positive member_limit re-arms enforcement
-- with no further migration needed.
-- =====================================================================

ALTER TABLE public.events ALTER COLUMN member_limit SET DEFAULT 0;

UPDATE public.events SET member_limit = 0;

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

  -- cap IS NULL: event row not found -> fall through, let the FK constraint
  -- raise the canonical error rather than masking it.
  -- cap <= 0: the launch "unlimited" sentinel -> no cap, allow the join.
  IF cap IS NULL OR cap <= 0 THEN
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
