-- Fixes a chicken-and-egg between two RLS policies introduced in
-- 20260507120000_member_limit_default_and_cap.sql.
--
-- The bug:
--   * events SELECT policy "Users can view their events" only allows reading
--     events whose id appears in event_members for the current user.
--   * event_members INSERT policy "Users can join events" has a WITH CHECK
--     subquery that reads events.member_limit.
--   * When a creator inserts their own event_members row right after
--     creating the event, they are not yet a member, so the events
--     subquery returns no rows. (count < NULL) evaluates to NULL, the
--     WITH CHECK fails, and the insert is silently rejected by RLS.
--
-- The fix:
--   Introduce a SECURITY DEFINER helper that returns the event's
--   member_limit while bypassing RLS, and use it in the WITH CHECK.
--   This keeps the events SELECT policy as-is (you still can't read other
--   people's events) and removes the cross-table RLS dependency.
--
--   The previous migration's own comment foreshadowed this:
--     "for tighter guarantees we'd move the join into a SECURITY DEFINER
--      function with row locking"
--   This is the lightest-touch version of that idea — only the limit
--   lookup runs as definer, not the whole join.

CREATE OR REPLACE FUNCTION public.event_member_limit(p_event_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT member_limit FROM public.events WHERE id = p_event_id;
$$;

REVOKE ALL ON FUNCTION public.event_member_limit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.event_member_limit(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can join events" ON public.event_members;
CREATE POLICY "Users can join events" ON public.event_members
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND (
      SELECT count(*)
        FROM public.event_members em
       WHERE em.event_id = event_members.event_id
    ) < public.event_member_limit(event_members.event_id)
  );
