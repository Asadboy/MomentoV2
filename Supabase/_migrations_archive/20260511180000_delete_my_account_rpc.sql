-- Allows a signed-in user to permanently delete their own account.
-- Required by Apple App Store Guideline 5.1.1(v) for apps that allow account
-- creation — without an in-app deletion path the app is rejected.
--
-- Deletion scope (executed in order under SECURITY DEFINER so RLS doesn't
-- block any individual row):
--   1. photo_likes the user gave
--   2. photos the user uploaded (in events they didn't create)
--   3. events the user created — CASCADE removes the event_members rows
--      AND the photos in those events via existing FK ON DELETE CASCADE,
--      which in turn cascades photo_likes via photos.id
--   4. event_members for events the user joined but didn't create
--   5. profile row
--   6. auth.users row — the actual auth record
--
-- NOT handled here: Supabase Storage objects (the actual photo bytes). The
-- client deletes those before calling this RPC because reaching the
-- storage.objects table from a SECURITY DEFINER function isn't ergonomic
-- under standard Supabase permissions — and the client already has DELETE
-- rights on its own storage objects via the existing RLS.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    uid uuid;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM public.photo_likes WHERE user_id = uid;

    -- Photos in events the user didn't create. (Photos in events they DID
    -- create get cascaded away by the events delete below.)
    DELETE FROM public.photos WHERE user_id = uid;

    -- Events the user hosted. Cascades to event_members + photos +
    -- transitively photo_likes via the existing FK chain.
    DELETE FROM public.events WHERE creator_id = uid;

    -- Memberships in events they joined but didn't create.
    DELETE FROM public.event_members WHERE user_id = uid;

    DELETE FROM public.profiles WHERE id = uid;

    -- The auth user itself. After this the JWT is invalid and the client
    -- should immediately drop the session.
    DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
