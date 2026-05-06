-- Two-part fix for join-by-code, which is currently broken in the live app.
--
-- 1. Recreate lookup_event_by_code without the dropped columns.
--    The previous body still selected `is_premium`, `member_count`, and
--    `photo_count` — all dropped during the rebrand and the count-trigger
--    cleanup. Calls error with `column e.is_premium does not exist`.
--
-- 2. Restore EXECUTE for the `authenticated` role.
--    Migration 20260506130000_fix_db_advisors revoked EXECUTE on this function
--    from anon/authenticated as a blanket response to the
--    `anon_security_definer_function_executable` advisor. That was correct for
--    `handle_new_user` (a trigger function, not for REST) but wrong here:
--    `lookup_event_by_code` is the only path the iOS client has to find an
--    event by join code, and the iOS client runs as `authenticated` after
--    sign-in. Keeping `anon` revoked still prevents logged-out enumeration.
--
-- Why exposing this RPC to authenticated users is safe: the function returns
-- at most one row, only on an exact join_code match, and only for non-deleted
-- events. There's no surface for enumerating events the caller doesn't already
-- know the code for.

DROP FUNCTION IF EXISTS public.lookup_event_by_code(text);

CREATE FUNCTION public.lookup_event_by_code(lookup_code text)
RETURNS TABLE (
  id uuid,
  name text,
  creator_id uuid,
  join_code text,
  starts_at timestamptz,
  ends_at timestamptz,
  release_at timestamptz,
  is_deleted boolean,
  created_at timestamptz,
  member_limit integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id, e.name, e.creator_id, e.join_code,
    e.starts_at, e.ends_at, e.release_at,
    e.is_deleted, e.created_at, e.member_limit
  FROM public.events e
  WHERE e.join_code = UPPER(lookup_code)
    AND e.is_deleted = false
  LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.lookup_event_by_code(text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.lookup_event_by_code(text) TO authenticated;
