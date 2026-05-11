-- The previous migration (20260511140000) tried to fix the chicken-and-egg
-- between events.SELECT and event_members.INSERT by routing the member_limit
-- lookup through a SECURITY DEFINER helper. Postgres still rejects the
-- policy as recursive at evaluation time: event_members.INSERT references
-- events, events.SELECT references event_members, and the planner doesn't
-- credit SECURITY DEFINER as breaking the cycle for policy-recursion checks.
--
-- We drop the cap subquery from RLS entirely. The original migration's own
-- comment acknowledged the cap was best-effort ("TOCTOU between two
-- simultaneous inserts could let one extra person through") and that
-- tighter guarantees would need a SECURITY DEFINER function with row
-- locking. The Swift client pre-checks the count in joinEvent and throws
-- SupabaseError.eventFull with a friendly message — that handles the
-- single-user case which is what matters for the friends-and-family launch.
--
-- When paid tiers ship and the cap becomes a monetisation gate, replace
-- this with a BEFORE INSERT trigger that locks event_members FOR UPDATE
-- and counts under the lock. Tracked in BACKLOG.md.

DROP POLICY IF EXISTS "Users can join events" ON public.event_members;
CREATE POLICY "Users can join events" ON public.event_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Helper from the previous migration is no longer referenced.
DROP FUNCTION IF EXISTS public.event_member_limit(uuid);
