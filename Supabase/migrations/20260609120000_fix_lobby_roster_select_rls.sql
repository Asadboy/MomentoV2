-- =====================================================================
-- Fix: lobby roster only shows the current user (beta-blocking bug).
-- =====================================================================
-- The live event_members SELECT policy was still the original
-- "Users can view own memberships" (user_id = auth.uid()), so
-- getEventMembersWithShots() could only ever see the caller's own
-- membership row -- each member saw a lobby containing just themselves.
--
-- The repo's 20260125000000_fix_rls_performance.sql *thought* it had
-- replaced that policy with "Users can view members of their events",
-- but (a) that replacement never reached prod, and (b) it was
-- self-referential (event_members policy subquerying event_members),
-- which Postgres rejects at query time with 42P17 infinite recursion --
-- so it's lucky it never landed.
--
-- Fix: a SECURITY DEFINER helper (same pattern as the member-limit
-- trigger; see 20260511150000 for the recursion/deadlock history) that
-- checks membership with RLS bypassed, used from a single combined
-- SELECT policy:
--   * own rows via the cheap user_id = auth.uid() disjunct (keeps the
--     events/photos policy subqueries on their current fast path), OR
--   * any row in an event the caller belongs to, via the helper.
-- Single permissive policy (not two) so the multiple-permissive-policies
-- performance advisor stays quiet.

CREATE OR REPLACE FUNCTION public.is_event_member(eid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.event_members
    WHERE event_id = eid
      AND user_id = (SELECT auth.uid())
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_event_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_event_member(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can view own memberships" ON public.event_members;
DROP POLICY IF EXISTS "Users can view members of their events" ON public.event_members;

CREATE POLICY "Users can view members of their events"
ON public.event_members FOR SELECT
TO authenticated
USING (
  user_id = (SELECT auth.uid())
  OR public.is_event_member(event_id)
);
