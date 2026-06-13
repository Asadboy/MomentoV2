-- Row Level Security Policies for Momento

-- ============================================
-- PROFILES POLICIES
-- ============================================

-- Users can view all profiles
CREATE POLICY "Users can view all profiles"
ON profiles FOR SELECT
TO authenticated
USING (true);

-- Users can update own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid());

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- ============================================
-- EVENTS POLICIES
-- ============================================

-- Users can view their events
CREATE POLICY "Users can view their events"
ON events FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

-- Users can create events
CREATE POLICY "Users can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (creator_id = auth.uid());

-- Creators can update their events
CREATE POLICY "Creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (creator_id = auth.uid());

-- Creators can delete their events
CREATE POLICY "Creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (creator_id = auth.uid());

-- ============================================
-- EVENT MEMBERS POLICIES
-- ============================================

-- Users can view members of their events
CREATE POLICY "Users can view members of their events"
ON event_members FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

-- Users can join events
CREATE POLICY "Users can join events"
ON event_members FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Users can leave events
CREATE POLICY "Users can leave events"
ON event_members FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ============================================
-- PHOTOS POLICIES
-- ============================================

-- Users can view photos from their events
CREATE POLICY "Users can view photos from their events"
ON photos FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

-- Users can upload photos to their events (with limit check)
CREATE POLICY "Users can upload photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() AND
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  ) AND
  -- Check photo limit per user per event
  (
    SELECT COUNT(*) FROM photos
    WHERE event_id = photos.event_id
    AND user_id = auth.uid()
  ) < (
    SELECT max_photos_per_user FROM events
    WHERE id = photos.event_id
  )
);

-- Event creators can delete photos (moderation)
CREATE POLICY "Creators can moderate photos"
ON photos FOR DELETE
TO authenticated
USING (
  event_id IN (
    SELECT id FROM events
    WHERE creator_id = auth.uid()
  )
);

-- Users can update their own photos (for reveal status in debug)
CREATE POLICY "Users can update own photos"
ON photos FOR UPDATE
TO authenticated
USING (user_id = auth.uid());

