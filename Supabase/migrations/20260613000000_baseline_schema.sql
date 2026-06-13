-- =====================================================================
-- BASELINE SCHEMA — 10shots (Momento) production, 2026-06-13
-- =====================================================================
-- This single migration reproduces the COMPLETE live schema of the
-- production database (project thnbjfcmawwaxvihggjm, eu-west-1) as of
-- 2026-06-13. It REPLACES the 26 historical migrations now archived in
-- `Supabase/migrations/archive/`.
--
-- WHY THIS EXISTS
-- The historical migration chain had drifted badly from production: a
-- large amount of the Momento -> 10shots rebrand DDL (events.title->name,
-- ~15 dropped columns, photos.is_flagged, the upload_status CHECK, the
-- is_event_member helper, the scoped storage policies) was applied
-- out-of-band via the dashboard / MCP and never captured as files. The
-- chain was NOT replayable — a fresh `supabase db reset` hard-failed
-- partway through (e.g. an UPDATE on events.member_limit before any file
-- created that column). This baseline restores the core invariant:
--
--     a fresh database built from migrations == production.
--
-- HOW IT WAS BUILT
-- Reconstructed by querying the live catalog (pg_class, pg_constraint,
-- pg_policies, pg_proc, pg_trigger, pg_indexes, information_schema,
-- storage.buckets) — not hand-written from the old files. See the
-- accompanying PR for the verification diff.
--
-- IDEMPOTENT / DEFENSIVE
-- Every statement is guarded (IF NOT EXISTS / OR REPLACE / DROP ... IF
-- EXISTS first) so that running this against an already-populated
-- database (i.e. production) is a safe no-op, and an accidental replay
-- cannot hard-error.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Extensions (Supabase pre-provisions these in the `extensions`
--    schema; declared defensively so a bare `db reset` has them).
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

-- profiles — one row per auth user (created by the on_auth_user_created
-- trigger below). `username` is legacy/nullable (display name replaced it
-- in the onboarding redesign); kept unique for the few legacy rows.
CREATE TABLE IF NOT EXISTS public.profiles (
  id                     uuid PRIMARY KEY REFERENCES auth.users(id),
  username               text UNIQUE,
  display_name           text NOT NULL,
  avatar_url             text,
  created_at             timestamptz DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  profile_setup_complete boolean NOT NULL DEFAULT false
);

-- events — a time-bound shared photo event. member_limit = 0 is the
-- launch "unlimited" sentinel (see enforce_member_limit_per_event).
CREATE TABLE IF NOT EXISTS public.events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  creator_id   uuid NOT NULL REFERENCES auth.users(id),
  join_code    text NOT NULL UNIQUE,
  release_at   timestamptz NOT NULL,
  created_at   timestamptz DEFAULT now(),
  starts_at    timestamptz,
  ends_at      timestamptz,
  is_deleted   boolean DEFAULT false,
  member_limit integer NOT NULL DEFAULT 0
);

-- event_members — membership join table. UNIQUE(event_id, user_id)
-- prevents double-joins.
CREATE TABLE IF NOT EXISTS public.event_members (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id  uuid REFERENCES public.events(id) ON DELETE CASCADE,
  user_id   uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  UNIQUE (event_id, user_id)
);

-- photos — one shot. client_upload_id powers idempotent upload retries
-- (partial unique index below). hidden_at is set by the auto-hide-on-
-- report trigger; is_flagged is the moderation flag path.
CREATE TABLE IF NOT EXISTS public.photos (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         uuid REFERENCES public.events(id) ON DELETE CASCADE,
  user_id          uuid REFERENCES auth.users(id),
  storage_path     text NOT NULL,
  captured_at      timestamptz DEFAULT now(),
  upload_status    text DEFAULT 'pending'
                     CHECK (upload_status = ANY (ARRAY['pending'::text, 'uploaded'::text, 'failed'::text])),
  width            integer,
  height           integer,
  is_flagged       boolean DEFAULT false,
  username         text,
  captured_by      text NOT NULL,
  hidden_at        timestamptz,
  client_upload_id uuid
);

-- photo_likes — like join table. PK(photo_id, user_id) = one like per
-- user per shot.
CREATE TABLE IF NOT EXISTS public.photo_likes (
  photo_id   uuid NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (photo_id, user_id)
);

-- photo_reports — Apple 1.2 content reporting. First distinct report
-- auto-hides the photo (hide_photo_on_report trigger). UNIQUE prevents a
-- user reporting the same shot twice.
CREATE TABLE IF NOT EXISTS public.photo_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id    uuid NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL DEFAULT auth.uid(),
  reason      text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (photo_id, reporter_id)
);

-- ---------------------------------------------------------------------
-- 2. Indexes (PK/UNIQUE indexes are created implicitly above)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_event_members_event ON public.event_members USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_event_members_user  ON public.event_members USING btree (user_id);

CREATE INDEX IF NOT EXISTS idx_events_creator    ON public.events USING btree (creator_id);
CREATE INDEX IF NOT EXISTS idx_events_ends_at    ON public.events USING btree (ends_at);
CREATE INDEX IF NOT EXISTS idx_events_join_code  ON public.events USING btree (join_code);
CREATE INDEX IF NOT EXISTS idx_events_release_at ON public.events USING btree (release_at);
CREATE INDEX IF NOT EXISTS idx_events_starts_at  ON public.events USING btree (starts_at);

CREATE INDEX IF NOT EXISTS idx_photo_likes_user ON public.photo_likes USING btree (user_id);

CREATE INDEX IF NOT EXISTS idx_photos_captured_at ON public.photos USING btree (captured_at);
CREATE INDEX IF NOT EXISTS idx_photos_event       ON public.photos USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_photos_event_time  ON public.photos USING btree (event_id, captured_at);
CREATE INDEX IF NOT EXISTS idx_photos_user        ON public.photos USING btree (user_id);
-- Idempotent-upload guard: at most one row per (non-null) client_upload_id.
CREATE UNIQUE INDEX IF NOT EXISTS photos_client_upload_id_key
  ON public.photos USING btree (client_upload_id) WHERE (client_upload_id IS NOT NULL);

-- ---------------------------------------------------------------------
-- 3. Functions (verbatim from live pg_get_functiondef)
-- ---------------------------------------------------------------------

-- Creates a profile row for every new auth user.
CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  random_handle TEXT;
BEGIN
  random_handle := 'user_' || encode(gen_random_bytes(4), 'hex');
  INSERT INTO public.profiles (id, username, display_name, profile_setup_complete)
  VALUES (NEW.id, random_handle, random_handle, FALSE);
  RETURN NEW;
END;
$function$;

-- Keeps profiles.updated_at fresh.
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO ''
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$;

-- Non-recursive membership check used by the event_members SELECT policy
-- (RLS bypassed inside via SECURITY DEFINER).
CREATE OR REPLACE FUNCTION public.is_event_member(eid uuid)
  RETURNS boolean
  LANGUAGE sql
  STABLE SECURITY DEFINER
  SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.event_members
    WHERE event_id = eid
      AND user_id = (SELECT auth.uid())
  );
$function$;

-- Secure event-by-code lookup (bypasses the events SELECT policy so a
-- not-yet-member can resolve a join code).
CREATE OR REPLACE FUNCTION public.lookup_event_by_code(lookup_code text)
  RETURNS TABLE(id uuid, name text, creator_id uuid, join_code text,
                starts_at timestamptz, ends_at timestamptz, release_at timestamptz,
                is_deleted boolean, created_at timestamptz, member_limit integer)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
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
$function$;

-- Per-event member cap (advisory-locked, atomic). cap <= 0 = unlimited.
CREATE OR REPLACE FUNCTION public.enforce_member_limit_per_event()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
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
$function$;

-- Per-user 10-shot cap (advisory-locked, atomic). Exempts idempotent
-- retries (same client_upload_id already present).
CREATE OR REPLACE FUNCTION public.enforce_photo_limit_per_user()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  photo_limit CONSTANT INTEGER := 10;
  lock_key BIGINT;
  current_count INTEGER;
BEGIN
  -- Idempotent retry: a row with this client_upload_id already exists,
  -- so the accompanying ON CONFLICT (client_upload_id) DO NOTHING makes
  -- this INSERT a no-op. Allow it through rather than falsely raising
  -- the limit on a shot that already uploaded.
  IF NEW.client_upload_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.photos
    WHERE client_upload_id = NEW.client_upload_id
  ) THEN
    RETURN NEW;
  END IF;

  lock_key := hashtextextended(NEW.event_id::text || ':' || NEW.user_id::text, 0);
  PERFORM pg_advisory_xact_lock(lock_key);

  SELECT count(*) INTO current_count
  FROM public.photos
  WHERE event_id = NEW.event_id
    AND user_id = NEW.user_id;

  IF current_count >= photo_limit THEN
    RAISE EXCEPTION 'photo_limit_reached'
      USING ERRCODE = 'P0010',
            HINT = 'Each member can take at most 10 shots per event.';
  END IF;

  RETURN NEW;
END;
$function$;

-- Threshold-1 auto-hide on report (Apple 1.2(c)).
CREATE OR REPLACE FUNCTION public.hide_photo_on_report()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  report_threshold CONSTANT INTEGER := 1;
  reporter_count INTEGER;
BEGIN
  SELECT count(DISTINCT reporter_id) INTO reporter_count
  FROM public.photo_reports
  WHERE photo_id = NEW.photo_id;

  IF reporter_count >= report_threshold THEN
    UPDATE public.photos
      SET hidden_at = now()
      WHERE id = NEW.photo_id
        AND hidden_at IS NULL;
  END IF;

  RETURN NEW;
END;
$function$;

-- In-app account deletion (Apple 5.1.1(v)). Atomically removes all of the
-- caller's data, then the auth user.
CREATE OR REPLACE FUNCTION public.delete_my_account()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
AS $function$
DECLARE
    uid uuid;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM public.photo_likes WHERE user_id = uid;
    DELETE FROM public.photos WHERE user_id = uid;
    DELETE FROM public.events WHERE creator_id = uid;
    DELETE FROM public.event_members WHERE user_id = uid;
    DELETE FROM public.profiles WHERE id = uid;
    DELETE FROM auth.users WHERE id = uid;
END;
$function$;

-- ---------------------------------------------------------------------
-- 4. Triggers
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS enforce_member_limit_per_event ON public.event_members;
CREATE TRIGGER enforce_member_limit_per_event
  BEFORE INSERT ON public.event_members
  FOR EACH ROW EXECUTE FUNCTION public.enforce_member_limit_per_event();

DROP TRIGGER IF EXISTS enforce_photo_limit_per_user ON public.photos;
CREATE TRIGGER enforce_photo_limit_per_user
  BEFORE INSERT ON public.photos
  FOR EACH ROW EXECUTE FUNCTION public.enforce_photo_limit_per_user();

DROP TRIGGER IF EXISTS hide_photo_on_report ON public.photo_reports;
CREATE TRIGGER hide_photo_on_report
  AFTER INSERT ON public.photo_reports
  FOR EACH ROW EXECUTE FUNCTION public.hide_photo_on_report();

-- ---------------------------------------------------------------------
-- 5. Row Level Security
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_likes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_reports ENABLE ROW LEVEL SECURITY;

-- profiles: world-readable to authenticated (needed for lobby rosters);
-- write only your own row.
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
CREATE POLICY "Users can view all profiles" ON public.profiles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (id = (SELECT auth.uid()));

-- events: visible to members; creator-only writes.
DROP POLICY IF EXISTS "Users can view their events" ON public.events;
CREATE POLICY "Users can view their events" ON public.events
  FOR SELECT TO authenticated
  USING (id IN (SELECT event_members.event_id FROM public.event_members
                WHERE event_members.user_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS "Users can create events" ON public.events;
CREATE POLICY "Users can create events" ON public.events
  FOR INSERT TO authenticated WITH CHECK (creator_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Creators can update their events" ON public.events;
CREATE POLICY "Creators can update their events" ON public.events
  FOR UPDATE TO authenticated USING (creator_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Creators can delete their events" ON public.events;
CREATE POLICY "Creators can delete their events" ON public.events
  FOR DELETE TO authenticated USING (creator_id = (SELECT auth.uid()));

-- event_members: see your own row OR any row in an event you belong to
-- (via the recursion-safe is_event_member helper). This is the lobby
-- roster fix (was own-rows-only, which made every lobby show just you).
DROP POLICY IF EXISTS "Users can view own memberships" ON public.event_members;
DROP POLICY IF EXISTS "Users can view members of their events" ON public.event_members;
CREATE POLICY "Users can view members of their events" ON public.event_members
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_event_member(event_id));

DROP POLICY IF EXISTS "Users can join events" ON public.event_members;
CREATE POLICY "Users can join events" ON public.event_members
  FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can leave events" ON public.event_members;
CREATE POLICY "Users can leave events" ON public.event_members
  FOR DELETE TO authenticated USING (user_id = (SELECT auth.uid()));

-- photos: visible to members of the event; insert your own into events
-- you belong to; update your own; creators (or owner) may delete.
DROP POLICY IF EXISTS "Users can view photos from their events" ON public.photos;
CREATE POLICY "Users can view photos from their events" ON public.photos
  FOR SELECT TO authenticated
  USING (event_id IN (SELECT event_members.event_id FROM public.event_members
                      WHERE event_members.user_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS "Users can upload photos" ON public.photos;
CREATE POLICY "Users can upload photos" ON public.photos
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid())
              AND event_id IN (SELECT event_members.event_id FROM public.event_members
                               WHERE event_members.user_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS "Users can update own photos" ON public.photos;
CREATE POLICY "Users can update own photos" ON public.photos
  FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Creators can moderate photos" ON public.photos;
CREATE POLICY "Creators can moderate photos" ON public.photos
  FOR DELETE TO authenticated
  USING (event_id IN (SELECT events.id FROM public.events
                      WHERE events.creator_id = (SELECT auth.uid()))
         OR user_id = (SELECT auth.uid()));

-- photo_likes: any authenticated user may read; write only your own.
DROP POLICY IF EXISTS "Users can view likes" ON public.photo_likes;
CREATE POLICY "Users can view likes" ON public.photo_likes
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Users can like photos" ON public.photo_likes;
CREATE POLICY "Users can like photos" ON public.photo_likes
  FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own likes" ON public.photo_likes;
CREATE POLICY "Users can update own likes" ON public.photo_likes
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can unlike photos" ON public.photo_likes;
CREATE POLICY "Users can unlike photos" ON public.photo_likes
  FOR DELETE TO authenticated USING ((SELECT auth.uid()) = user_id);

-- photo_reports: file and read only your own reports.
DROP POLICY IF EXISTS "Users can file their own reports" ON public.photo_reports;
CREATE POLICY "Users can file their own reports" ON public.photo_reports
  FOR INSERT TO authenticated WITH CHECK (reporter_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can read their own reports" ON public.photo_reports;
CREATE POLICY "Users can read their own reports" ON public.photo_reports
  FOR SELECT TO authenticated USING (reporter_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------
-- 6. Function execute grants (match live ACLs exactly)
-- ---------------------------------------------------------------------
-- Trigger-only function, never called by clients.
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Client RPCs / policy helpers: authenticated only (anon revoked).
REVOKE ALL ON FUNCTION public.is_event_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_event_member(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.lookup_event_by_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lookup_event_by_code(text) TO authenticated, service_role;

-- Account deletion + report-hide: PUBLIC revoked; both no-op / RAISE for
-- unauthenticated callers (kept matching live: anon retains EXECUTE but
-- is harmless — see PR notes for the optional anon-revoke follow-up).
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.hide_photo_on_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hide_photo_on_report() TO anon, authenticated, service_role;

-- enforce_member_limit_per_event / enforce_photo_limit_per_user /
-- update_updated_at_column keep Supabase default grants (trigger
-- functions; execute privilege is irrelevant — triggers run as the
-- table owner).

-- ---------------------------------------------------------------------
-- 7. Storage: buckets + policies
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('momento-photos', 'momento-photos', false, 8388608, ARRAY['image/jpeg']::text[]),
  ('avatars',        'avatars',        true,  2097152, ARRAY['image/jpeg']::text[])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- momento-photos (private): membership-scoped, case-insensitive folder
-- match (folder = EVENT_ID uppercase from Swift UUID.uuidString).
DROP POLICY IF EXISTS "Members can upload photos to their events" ON storage.objects;
CREATE POLICY "Members can upload photos to their events" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'momento-photos'
    AND lower((storage.foldername(name))[1]) IN (
      SELECT lower(event_id::text) FROM public.event_members
      WHERE user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "Members can view photos from their events" ON storage.objects;
CREATE POLICY "Members can view photos from their events" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'momento-photos'
    AND lower((storage.foldername(name))[1]) IN (
      SELECT lower(event_id::text) FROM public.event_members
      WHERE user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "Members can update their own photos" ON storage.objects;
CREATE POLICY "Members can update their own photos" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'momento-photos'
    AND owner = (SELECT auth.uid())
    AND lower((storage.foldername(name))[1]) IN (
      SELECT lower(event_id::text) FROM public.event_members
      WHERE user_id = (SELECT auth.uid())
    )
  );

-- Creator-moderation delete (note: live qual uses bare auth.uid()).
DROP POLICY IF EXISTS "Creators can delete photos" ON storage.objects;
CREATE POLICY "Creators can delete photos" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'momento-photos'
    AND (storage.foldername(name))[1] IN (
      SELECT events.id::text FROM public.events
      WHERE events.creator_id = auth.uid()
    )
  );

-- avatars (public bucket → reads are open; writes are owner-scoped,
-- case-insensitive folder = USER_ID).
DROP POLICY IF EXISTS "avatars_owner_insert" ON storage.objects;
CREATE POLICY "avatars_owner_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars'
              AND lower((storage.foldername(name))[1]) = lower((auth.uid())::text));

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars'
         AND lower((storage.foldername(name))[1]) = lower((auth.uid())::text));

DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars'
         AND lower((storage.foldername(name))[1]) = lower((auth.uid())::text));

-- =====================================================================
-- End baseline.
-- =====================================================================
