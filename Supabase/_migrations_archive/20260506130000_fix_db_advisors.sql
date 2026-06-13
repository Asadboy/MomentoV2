-- Fixes raised by Supabase advisors:
-- 1. Revoke public REST access to SECURITY DEFINER functions (still callable by triggers/internal RPC)
-- 2. Drop duplicate `photos_select` policy that bypassed event membership check (SECURITY)
-- 3. Wrap auth.uid() in (SELECT ...) for photo_likes policies (PERFORMANCE)

-- 1. Revoke EXECUTE on SECURITY DEFINER functions from public roles
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.lookup_event_by_code(text) FROM anon, authenticated, public;

-- 2. Remove the permissive `photos_select` policy.
-- It had USING (true), letting any authenticated user read any photo regardless of event membership.
-- The "Users can view photos from their events" policy enforces the correct check.
DROP POLICY IF EXISTS photos_select ON public.photos;

-- 3. Rewrite photo_likes policies to evaluate auth.uid() once per query, not per row.
DROP POLICY IF EXISTS "Users can like photos" ON public.photo_likes;
CREATE POLICY "Users can like photos" ON public.photo_likes
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can unlike photos" ON public.photo_likes;
CREATE POLICY "Users can unlike photos" ON public.photo_likes
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own likes" ON public.photo_likes;
CREATE POLICY "Users can update own likes" ON public.photo_likes
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view likes" ON public.photo_likes;
CREATE POLICY "Users can view likes" ON public.photo_likes
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);
