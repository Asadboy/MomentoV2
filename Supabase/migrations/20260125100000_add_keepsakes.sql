-- Add Keepsakes Tables
-- Keepsakes are rare digital collectibles that users can earn

-- ============================================
-- KEEPSAKES TABLE
-- ============================================
-- Defines the available keepsakes (collectibles)
CREATE TABLE public.keepsakes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  artwork_url TEXT NOT NULL,
  flavour_text TEXT,
  event_id UUID REFERENCES events(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- USER_KEEPSAKES TABLE
-- ============================================
-- Junction table tracking which users have earned which keepsakes
CREATE TABLE public.user_keepsakes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  keepsake_id UUID REFERENCES keepsakes(id) ON DELETE CASCADE NOT NULL,
  earned_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, keepsake_id)
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_user_keepsakes_user ON user_keepsakes(user_id);
CREATE INDEX idx_keepsakes_event ON keepsakes(event_id);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================
ALTER TABLE keepsakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_keepsakes ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Anyone can view keepsakes (needed for rarity calculation)
CREATE POLICY "Anyone can view keepsakes"
ON keepsakes FOR SELECT
TO authenticated
USING (true);

-- Users can only view their own keepsakes
-- Using (select auth.uid()) pattern for performance (single evaluation)
CREATE POLICY "Users can view own keepsakes"
ON user_keepsakes FOR SELECT
TO authenticated
USING (user_id = (select auth.uid()));

-- No INSERT policy on user_keepsakes - only service role can grant keepsakes

-- ============================================
-- SEED INITIAL KEEPSAKES
-- ============================================
INSERT INTO keepsakes (name, artwork_url, flavour_text) VALUES
  ('Lakes', 'keepsakes/lakes.png', 'Some moments are worth waiting 3 years for.'),
  ('Sopranos', 'keepsakes/sopranos.png', 'Made member of the first family.'),
  ('Hijack x DoubleDip', 'keepsakes/hijack-doubledip.png', 'On board from the start. London.');
