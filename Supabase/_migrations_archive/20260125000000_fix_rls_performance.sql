-- Fix RLS Performance: Wrap auth.uid() in (select ...) for single evaluation
-- This prevents re-evaluation of auth.uid() for each row
-- Expected impact: 200-500ms saved per query on large result sets

-- ============================================
-- PROFILES POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = (select auth.uid()));

-- ============================================
-- EVENTS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view their events" ON events;
CREATE POLICY "Users can view their events"
ON events FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can create events" ON events;
CREATE POLICY "Users can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (creator_id = (select auth.uid()));

DROP POLICY IF EXISTS "Creators can update their events" ON events;
CREATE POLICY "Creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (creator_id = (select auth.uid()));

DROP POLICY IF EXISTS "Creators can delete their events" ON events;
CREATE POLICY "Creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (creator_id = (select auth.uid()));

-- ============================================
-- EVENT MEMBERS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view own memberships" ON event_members;
DROP POLICY IF EXISTS "Users can view members of their events" ON event_members;
CREATE POLICY "Users can view members of their events"
ON event_members FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can join events" ON event_members;
CREATE POLICY "Users can join events"
ON event_members FOR INSERT
TO authenticated
WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can leave events" ON event_members;
CREATE POLICY "Users can leave events"
ON event_members FOR DELETE
TO authenticated
USING (user_id = (select auth.uid()));

-- ============================================
-- PHOTOS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view photos from their events" ON photos;
CREATE POLICY "Users can view photos from their events"
ON photos FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

-- Consolidate duplicate INSERT policies into one
DROP POLICY IF EXISTS "Users can upload photos" ON photos;
DROP POLICY IF EXISTS "photos_insert" ON photos;
CREATE POLICY "Users can upload photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (select auth.uid()) AND
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = (select auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can update own photos" ON photos;
CREATE POLICY "Users can update own photos"
ON photos FOR UPDATE
TO authenticated
USING (user_id = (select auth.uid()));

-- Consolidate duplicate DELETE policies into one
DROP POLICY IF EXISTS "Creators can moderate photos" ON photos;
DROP POLICY IF EXISTS "photos_delete" ON photos;
CREATE POLICY "Creators can moderate photos"
ON photos FOR DELETE
TO authenticated
USING (
  event_id IN (
    SELECT id FROM events
    WHERE creator_id = (select auth.uid())
  )
  OR user_id = (select auth.uid())
);

-- ============================================
-- PHOTO_INTERACTIONS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can manage their own interactions" ON photo_interactions;
CREATE POLICY "Users can manage their own interactions"
ON photo_interactions FOR ALL
TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- USER_REVEAL_PROGRESS POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can manage their own progress" ON user_reveal_progress;
CREATE POLICY "Users can manage their own progress"
ON user_reveal_progress FOR ALL
TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));
