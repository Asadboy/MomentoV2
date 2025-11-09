-- Momento Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES TABLE
-- ============================================
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  display_name TEXT,
  avatar_url TEXT,
  is_premium BOOLEAN DEFAULT false,
  total_events_joined INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- EVENTS TABLE
-- ============================================
CREATE TABLE public.events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  join_code TEXT UNIQUE NOT NULL,
  release_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Privacy & Access
  is_private BOOLEAN DEFAULT false,
  is_corporate BOOLEAN DEFAULT false,
  
  -- Limits
  max_photos_per_user INTEGER DEFAULT 5,
  
  -- Metadata
  location_name TEXT,
  location_lat FLOAT,
  location_lng FLOAT,
  description TEXT,
  
  -- Stats (updated by triggers)
  member_count INTEGER DEFAULT 1,
  photo_count INTEGER DEFAULT 0,
  
  -- Reveal
  is_revealed BOOLEAN DEFAULT false,
  reveal_job_scheduled BOOLEAN DEFAULT false
);

-- ============================================
-- EVENT MEMBERS TABLE
-- ============================================
CREATE TABLE public.event_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by UUID REFERENCES auth.users(id),
  role TEXT DEFAULT 'member',
  
  UNIQUE(event_id, user_id)
);

-- ============================================
-- PHOTOS TABLE
-- ============================================
CREATE TABLE public.photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  
  -- Storage
  storage_path TEXT NOT NULL,
  file_size INTEGER,
  
  -- Metadata
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  captured_by_username TEXT,
  device_type TEXT,
  
  -- Status
  is_revealed BOOLEAN DEFAULT false,
  upload_status TEXT DEFAULT 'pending',
  
  -- Dimensions
  width INTEGER,
  height INTEGER
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_events_creator ON events(creator_id);
CREATE INDEX idx_events_join_code ON events(join_code);
CREATE INDEX idx_events_release_at ON events(release_at);
CREATE INDEX idx_event_members_event ON event_members(event_id);
CREATE INDEX idx_event_members_user ON event_members(user_id);
CREATE INDEX idx_photos_event ON photos(event_id);
CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_captured_at ON photos(captured_at);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user' || floor(random() * 10000)::text),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update event member count
CREATE OR REPLACE FUNCTION update_event_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE events 
    SET member_count = member_count + 1 
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE events 
    SET member_count = member_count - 1 
    WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_member_count_trigger
  AFTER INSERT OR DELETE ON event_members
  FOR EACH ROW EXECUTE FUNCTION update_event_member_count();

-- Update event photo count
CREATE OR REPLACE FUNCTION update_event_photo_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE events 
    SET photo_count = photo_count + 1 
    WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE events 
    SET photo_count = photo_count - 1 
    WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_photo_count_trigger
  AFTER INSERT OR DELETE ON photos
  FOR EACH ROW EXECUTE FUNCTION update_event_photo_count();

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Momento database schema created successfully!';
END $$;

