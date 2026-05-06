-- Wires up events.member_limit so each event has a hard cap on how many
-- people can join. v1 default is 10 (matches "10 shots" branding and the
-- friends-and-family launch). Future monetisation tiers will write a different
-- value to this column per event; the cap stays in the same place.

-- 1. Backfill existing rows so the NOT NULL change is safe.
UPDATE public.events
   SET member_limit = 10
 WHERE member_limit IS NULL;

-- 2. Default + NOT NULL so new rows always have a cap.
ALTER TABLE public.events
  ALTER COLUMN member_limit SET DEFAULT 10,
  ALTER COLUMN member_limit SET NOT NULL;

-- 3. Replace the event_members INSERT policy with one that also enforces the cap.
-- This is best-effort under concurrent joins (TOCTOU between two simultaneous
-- inserts could let one extra person through). For friends-and-family scale
-- that's acceptable; for tighter guarantees we'd move the join into a
-- SECURITY DEFINER function with row locking. The Swift client also pre-checks
-- the count before calling insert and surfaces a friendly error.
DROP POLICY IF EXISTS "Users can join events" ON public.event_members;
CREATE POLICY "Users can join events" ON public.event_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND (
      SELECT count(*)
        FROM public.event_members em
       WHERE em.event_id = event_members.event_id
    ) < (
      SELECT e.member_limit
        FROM public.events e
       WHERE e.id = event_members.event_id
    )
  );
