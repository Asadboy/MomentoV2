# Supabase Setup Guide

## Step 1: Get Supabase Credentials

1. Go to [supabase.com](https://supabase.com) and sign in
2. Create a new project or select your existing one
3. Navigate to **Settings** → **API**
4. Copy these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

## Step 2: Install Supabase Swift SDK

### In Xcode:

1. Open `Momento.xcodeproj`
2. Go to **File** → **Add Package Dependencies...**
3. Enter this URL: `https://github.com/supabase-community/supabase-swift`
4. Click **Add Package**
5. Select **Supabase** and **SupabaseStorage** libraries
6. Click **Add Package**

### Or via Terminal:

```bash
cd /Users/asad/Documents/Momento
# Xcode will automatically detect and install SPM packages
```

## Step 3: Configure Credentials

1. Open `Momento/Config/SupabaseConfig.swift`
2. Replace `YOUR_SUPABASE_URL_HERE` with your Project URL
3. Replace `YOUR_SUPABASE_ANON_KEY_HERE` with your anon key
4. Save the file

**IMPORTANT:** This file is in `.gitignore` and won't be committed!

## Step 4: Create Database Schema

Go to your Supabase project → **SQL Editor** → **New Query**

Run this SQL:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends auth.users)
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

-- Events table
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
  
  -- Stats
  member_count INTEGER DEFAULT 1,
  photo_count INTEGER DEFAULT 0,
  
  -- Reveal
  is_revealed BOOLEAN DEFAULT false,
  reveal_job_scheduled BOOLEAN DEFAULT false
);

-- Event members table
CREATE TABLE public.event_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by UUID REFERENCES auth.users(id),
  role TEXT DEFAULT 'member',
  
  UNIQUE(event_id, user_id)
);

-- Photos table
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

-- Indexes
CREATE INDEX idx_events_creator ON events(creator_id);
CREATE INDEX idx_events_join_code ON events(join_code);
CREATE INDEX idx_events_release_at ON events(release_at);
CREATE INDEX idx_event_members_event ON event_members(event_id);
CREATE INDEX idx_event_members_user ON event_members(user_id);
CREATE INDEX idx_photos_event ON photos(event_id);
CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_captured_at ON photos(captured_at);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
```

## Step 5: Set Up Row Level Security Policies

Run this SQL:

```sql
-- Profiles policies
CREATE POLICY "Users can view all profiles"
ON profiles FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid());

-- Events policies
CREATE POLICY "Users can view their events"
ON events FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Users can create events"
ON events FOR INSERT
TO authenticated
WITH CHECK (creator_id = auth.uid());

CREATE POLICY "Creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (creator_id = auth.uid());

CREATE POLICY "Creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (creator_id = auth.uid());

-- Event members policies
CREATE POLICY "Users can view members of their events"
ON event_members FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Users can join events"
ON event_members FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Photos policies
CREATE POLICY "Users can view photos from their events"
ON photos FOR SELECT
TO authenticated
USING (
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Users can upload photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() AND
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Creators can moderate photos"
ON photos FOR DELETE
TO authenticated
USING (
  event_id IN (
    SELECT id FROM events
    WHERE creator_id = auth.uid()
  )
);
```

## Step 6: Create Storage Bucket

1. In Supabase dashboard, go to **Storage**
2. Click **New bucket**
3. Name: `momento-photos`
4. **Public bucket**: NO (keep private)
5. Click **Create bucket**

### Set Storage Policies

Go to **Storage** → **Policies** → **New Policy**

**Policy 1: Upload photos**
```sql
CREATE POLICY "Users can upload photos to their events"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT event_id::text FROM event_members
    WHERE user_id = auth.uid()
  )
);
```

**Policy 2: View photos**
```sql
CREATE POLICY "Users can view photos from their events"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'momento-photos' AND
  (storage.foldername(name))[1] IN (
    SELECT event_id::text FROM event_members
    WHERE user_id = auth.uid()
  )
);
```

## Step 7: Configure Authentication

### Enable Apple Sign In

1. Go to **Authentication** → **Providers**
2. Enable **Apple**
3. Follow Supabase instructions to configure Apple Developer account

### Enable Google Sign In

1. Enable **Google** provider
2. Add your OAuth credentials from Google Cloud Console

## Step 8: Test Connection

Build and run the app. Check Xcode console for:
```
✅ Supabase configured successfully
```

If you see errors, check:
- Credentials are correct in `SupabaseConfig.swift`
- Supabase Swift SDK is installed
- Database tables are created

---

## Troubleshooting

### "Module 'Supabase' not found"
- Clean build folder: `Cmd + Shift + K`
- Rebuild: `Cmd + B`

### "Invalid API key"
- Double-check your anon key in Supabase dashboard
- Make sure no extra spaces in `SupabaseConfig.swift`

### "Table does not exist"
- Run the SQL schema creation script
- Check in Supabase → Database → Tables

---

## Next Steps

Once setup is complete, we'll build:
1. ✅ SupabaseManager singleton
2. ✅ Authentication flow
3. ✅ Event creation
4. ✅ Photo upload

Let me know when Steps 1-7 are done! 🚀

