-- Secure Event Lookup: Replace permissive policy with RPC function
-- This ensures users can only see events they have the exact join code for
-- The join code acts as a secret/password for event access

-- ============================================
-- REMOVE PERMISSIVE POLICY
-- ============================================

-- Drop the overly permissive policy that exposed all events
DROP POLICY IF EXISTS "Anyone can find events to join" ON events;

-- ============================================
-- CREATE SECURE LOOKUP FUNCTION
-- ============================================

-- This function allows looking up an event by join code without being a member
-- It's SECURITY DEFINER so it bypasses RLS, but only returns the specific event
-- matching the exact join code provided
CREATE OR REPLACE FUNCTION public.lookup_event_by_code(lookup_code TEXT)
RETURNS TABLE (
  id UUID,
  title TEXT,
  creator_id UUID,
  join_code TEXT,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  release_at TIMESTAMPTZ,
  is_revealed BOOLEAN,
  member_count INT,
  photo_count INT,
  created_at TIMESTAMPTZ,
  is_deleted BOOLEAN
)
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only return events that match the exact code and are not deleted
  RETURN QUERY
  SELECT
    e.id,
    e.title,
    e.creator_id,
    e.join_code,
    e.starts_at,
    e.ends_at,
    e.release_at,
    e.is_revealed,
    e.member_count,
    e.photo_count,
    e.created_at,
    e.is_deleted
  FROM public.events e
  WHERE e.join_code = UPPER(lookup_code)
    AND e.is_deleted = false
  LIMIT 1;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.lookup_event_by_code(TEXT) TO authenticated;

-- ============================================
-- NOTES
-- ============================================
--
-- Security model:
-- 1. Users can only see events they're members of (via RLS on events table)
-- 2. To join an event, users must have the exact join code
-- 3. The RPC function allows looking up event details with the code
-- 4. Once joined, users become members and can see the event normally
--
-- This prevents:
-- - Enumerating all events in the system
-- - Seeing event details without the join code
-- - Brute-forcing event discovery
