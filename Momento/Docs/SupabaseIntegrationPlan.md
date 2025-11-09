# Supabase Integration Plan - Momento MVP

## Overview
This document outlines the complete Supabase backend integration for Momento's MVP launch targeting 50-200 beta users in the UK music/social scene.

---

## 1. Authentication Strategy

### Social Logins (Primary)
- **Apple Sign In** - Required for App Store, builds trust
- **Google Sign In** - Broad reach, familiar to users

**Why Social Login?**
- Faster onboarding (no password to remember)
- Higher trust factor for new apps
- Built-in email verification
- Reduces friction in sign-up flow

**Email/Password (Optional - Recommended)**
- Fallback for users without Apple/Google accounts
- Required for web version if you build one later
- Minimal extra effort with Supabase Auth

### User Profile Structure
```sql
users (extends Supabase auth.users)
├── id (UUID, primary key)
├── username (unique, lowercase, alphanumeric + underscore)
├── first_name (optional)
├── last_name (optional)
├── display_name (computed: first_name + last_name or username)
├── avatar_url (optional)
├── created_at
├── is_premium (boolean, default false)
└── total_events_joined (integer, default 0)
```

**Username vs Real Name:**
- Store both, let users choose what shows publicly
- Default to username for `capturedBy` field (cooler, more social)
- Allow toggle in settings: "Show real name" vs "Show username"
- Best of both worlds!

### Onboarding Flow
```
1. User scans QR code / clicks invite link
   ↓
2. App opens to event preview (no auth required)
   ↓
3. User taps "Join Event"
   ↓
4. Auth modal appears: "Sign in to join"
   - Apple Sign In button
   - Google Sign In button
   - Email/Password option
   ↓
5. After auth, user auto-joins event
   ↓
6. Redirect to event card (now a member)
```

**Key Point:** Seamless QR → Preview → Sign Up → Join flow

---

## 2. Database Schema

### Events Table
```sql
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  creator_id UUID REFERENCES auth.users(id) NOT NULL,
  join_code TEXT UNIQUE NOT NULL,
  release_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Privacy & Access
  is_private BOOLEAN DEFAULT false,
  is_corporate BOOLEAN DEFAULT false, -- Corp events, popups
  
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

-- Indexes
CREATE INDEX idx_events_creator ON events(creator_id);
CREATE INDEX idx_events_join_code ON events(join_code);
CREATE INDEX idx_events_release_at ON events(release_at);
```

### Event Members Table
```sql
CREATE TABLE event_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by UUID REFERENCES auth.users(id), -- Track invites
  role TEXT DEFAULT 'member', -- 'creator', 'admin', 'member'
  
  UNIQUE(event_id, user_id)
);

-- Indexes
CREATE INDEX idx_event_members_event ON event_members(event_id);
CREATE INDEX idx_event_members_user ON event_members(user_id);
```

### Photos Table
```sql
CREATE TABLE photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  
  -- Storage
  storage_path TEXT NOT NULL, -- Path in Supabase Storage
  file_size INTEGER,
  
  -- Metadata
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  captured_by_username TEXT, -- Denormalized for performance
  device_type TEXT,
  
  -- Status
  is_revealed BOOLEAN DEFAULT false,
  upload_status TEXT DEFAULT 'pending', -- 'pending', 'uploaded', 'failed'
  
  -- Dimensions
  width INTEGER,
  height INTEGER
);

-- Indexes
CREATE INDEX idx_photos_event ON photos(event_id);
CREATE INDEX idx_photos_user ON photos(user_id);
CREATE INDEX idx_photos_captured_at ON photos(captured_at);
```

### Join Codes Table (Optional - for analytics)
```sql
CREATE TABLE join_code_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  views INTEGER DEFAULT 0,
  joins INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ, -- NULL for permanent codes
  is_custom BOOLEAN DEFAULT false -- Premium feature
);
```

---

## 3. Storage Structure

### Bucket Organization
```
Supabase Storage
└── momento-photos (main bucket)
    ├── evento_<event_id_1>/
    │   ├── <photo_id_1>.jpg
    │   ├── <photo_id_2>.jpg
    │   └── thumbnails/
    │       ├── <photo_id_1>_thumb.jpg
    │       └── <photo_id_2>_thumb.jpg
    ├── evento_<event_id_2>/
    └── ...
```

**Why one bucket with folders?**
- Easier to manage (one bucket = simpler permissions)
- Supabase free tier has bucket limits
- Still track event count via `events` table
- Folders provide logical separation

**Storage Policies:**
```sql
-- Users can upload to their event folders
CREATE POLICY "Users can upload photos to events they're members of"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'momento-photos' AND
  EXISTS (
    SELECT 1 FROM event_members
    WHERE event_id = (storage.foldername(name))[1]::uuid
    AND user_id = auth.uid()
  )
);

-- Users can read photos from events they're members of
CREATE POLICY "Users can view photos from their events"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'momento-photos' AND
  EXISTS (
    SELECT 1 FROM event_members
    WHERE event_id = (storage.foldername(name))[1]::uuid
    AND user_id = auth.uid()
  )
);
```

---

## 4. Photo Upload Flow

### Upload Strategy
```
1. User captures photo
   ↓
2. Save to local cache immediately (offline support)
   ↓
3. Check network status
   ↓
4. If WiFi/Data available:
   - Compress image (max 2MB)
   - Upload to Supabase Storage
   - Create photo record in database
   - Mark as 'uploaded' in local cache
   ↓
5. If offline:
   - Mark as 'pending' in local cache
   - Show "Will upload when online" badge
   ↓
6. Background sync:
   - Monitor network changes
   - Auto-upload pending photos when WiFi available
   - Update UI with upload progress
```

### Upload Error Handling
```swift
enum UploadStatus {
    case pending      // Not uploaded yet
    case uploading    // In progress
    case uploaded     // Success
    case failed       // Failed after retries
}

// Retry logic
- Attempt 1: Immediate
- Attempt 2: After 5 seconds
- Attempt 3: After 30 seconds
- After 3 failures: Show "Upload Failed" with manual retry button
```

### Image Compression
```swift
// Before upload
let compressed = image.jpegData(compressionQuality: 0.8)
// Target: ~2MB max file size
// Resize if needed: max dimension 2048px
```

---

## 5. Real-time Updates

### Supabase Realtime Subscriptions
```swift
// Subscribe to event updates
supabase
  .from("events")
  .on(.update, schema: "public") { payload in
    // Update photo_count, member_count in UI
  }
  .subscribe()

// Subscribe to new photos in event
supabase
  .from("photos")
  .on(.insert, schema: "public") { payload in
    // Increment photo counter
    // Show subtle animation
  }
  .subscribe()
```

**Update Strategy:**
- Photo count: Real-time via Supabase Realtime
- Member count: Real-time via Supabase Realtime
- Fallback: Poll every 30 seconds if Realtime fails

---

## 6. Photo Reveal System

### Backend Cron Job (Supabase Edge Function)
```typescript
// Scheduled function runs every minute
// File: supabase/functions/reveal-photos/index.ts

Deno.serve(async (req) => {
  const now = new Date();
  
  // Find events that should be revealed
  const { data: events } = await supabase
    .from('events')
    .select('id')
    .eq('is_revealed', false)
    .lte('release_at', now.toISOString())
    .eq('reveal_job_scheduled', false);
  
  for (const event of events) {
    // Update event
    await supabase
      .from('events')
      .update({ is_revealed: true })
      .eq('id', event.id);
    
    // Update all photos
    await supabase
      .from('photos')
      .update({ is_revealed: true })
      .eq('event_id', event.id);
    
    // Send push notifications to all members
    await sendRevealNotifications(event.id);
  }
  
  return new Response('OK');
});
```

**Cron Schedule:**
```bash
# Run every minute
* * * * *
```

### Push Notifications (Phase 1)
```swift
// When photos are revealed
"🎉 Your Momento is ready! Tap to view photos from [Event Name]"

// Deep link to event gallery
momento://event/{event_id}/gallery
```

---

## 7. Row Level Security (RLS) Policies

### Events Table
```sql
-- Users can read events they're members of
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

-- Only creators can update their events
CREATE POLICY "Creators can update their events"
ON events FOR UPDATE
TO authenticated
USING (creator_id = auth.uid());

-- Only creators can delete their events
CREATE POLICY "Creators can delete their events"
ON events FOR DELETE
TO authenticated
USING (creator_id = auth.uid());
```

### Photos Table
```sql
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

-- Users can upload photos to their events
CREATE POLICY "Users can upload photos"
ON photos FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid() AND
  event_id IN (
    SELECT event_id FROM event_members
    WHERE user_id = auth.uid()
  ) AND
  -- Check photo limit
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
```

---

## 8. Join Code System

### Code Generation
```swift
func generateJoinCode() -> String {
    // 6-character alphanumeric code
    // Exclude ambiguous characters: 0, O, 1, I, l
    let chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    return String((0..<6).map { _ in chars.randomElement()! })
}

// Ensure uniqueness
func ensureUniqueCode() async -> String {
    var code = generateJoinCode()
    while await codeExists(code) {
        code = generateJoinCode()
    }
    return code
}
```

### QR Code Generation (Client-Side)
```swift
import CoreImage.CIFilterBuiltins

func generateQRCode(for event: Event) -> UIImage {
    // Deep link format
    let deepLink = "momento://join/\(event.joinCode)?eventId=\(event.id)"
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(deepLink.utf8)
    filter.correctionLevel = "M"
    
    if let outputImage = filter.outputImage {
        // Scale up for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }
    
    return UIImage(systemName: "qrcode")!
}
```

### Deep Linking
```swift
// Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>momento</string>
        </array>
    </dict>
</array>

// Handle deep link
@main
struct MomentoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    func handleDeepLink(_ url: URL) {
        // momento://join/ABC123?eventId=uuid
        if url.host == "join",
           let code = url.pathComponents.last {
            // Show join flow with code pre-filled
            joinEvent(withCode: code)
        }
    }
}
```

---

## 9. MVP Implementation Checklist

### Phase 1 - Core Backend (Week 1-2)
- [x] Set up Supabase project
- [x] Configure authentication (Apple, Google, Email)
- [x] Create database schema (events, photos, members)
- [x] Set up RLS policies
- [x] Create Storage bucket with policies
- [x] Implement join code generation
- [x] Build photo upload flow
- [x] Add offline sync queue

### Phase 2 - Real-time & Reveal (Week 3)
- [x] Set up Supabase Realtime subscriptions
- [x] Create reveal Edge Function
- [x] Configure cron job for auto-reveal
- [x] Implement push notifications
- [x] Add photo counter updates

### Phase 3 - Polish & Testing (Week 4)
- [ ] Error handling & retry logic
- [ ] Loading states & animations
- [ ] Beta testing with 10 users
- [ ] Bug fixes & optimization
- [ ] Prepare for 50-user beta

---

## 10. Supabase Swift SDK Integration

### Installation
```swift
// Package.swift or SPM
dependencies: [
    .package(url: "https://github.com/supabase-community/supabase-swift", from: "2.0.0")
]
```

### Configuration
```swift
// SupabaseClient.swift
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )
    }
}
```

### Usage Examples
```swift
// Sign in with Apple
let session = try await supabase.auth.signInWithIdToken(
    credentials: .init(
        provider: .apple,
        idToken: appleIDToken
    )
)

// Create event
let event = try await supabase
    .from("events")
    .insert([
        "title": "NYE Party",
        "creator_id": session.user.id,
        "join_code": generateJoinCode(),
        "release_at": releaseDate.ISO8601Format()
    ])
    .execute()

// Upload photo
let file = try await supabase.storage
    .from("momento-photos")
    .upload(
        path: "evento_\(eventId)/\(photoId).jpg",
        file: imageData,
        options: FileOptions(contentType: "image/jpeg")
    )

// Subscribe to updates
let subscription = await supabase
    .from("events:\(eventId)")
    .on(.update) { message in
        // Update UI
    }
    .subscribe()
```

---

## 11. Error Handling Strategy

### User-Facing Messages
```swift
enum MomentoError: LocalizedError {
    case networkUnavailable
    case uploadFailed
    case authenticationFailed
    case eventNotFound
    case photoLimitReached
    case invalidJoinCode
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Photos will upload when you're back online."
        case .uploadFailed:
            return "Upload failed. Tap to retry."
        case .authenticationFailed:
            return "Sign in required. Please sign in to continue."
        case .eventNotFound:
            return "Event not found. Check your join code and try again."
        case .photoLimitReached:
            return "Photo limit reached (5/5). Upgrade for unlimited photos!"
        case .invalidJoinCode:
            return "Invalid join code. Please check and try again."
        }
    }
}
```

---

## 12. Next Steps

1. **Set up Supabase project** (I can guide you through this)
2. **Run database migrations** (create tables, policies)
3. **Configure authentication providers** (Apple, Google)
4. **Install Supabase Swift SDK** in Xcode
5. **Build authentication flow** (sign in/up screens)
6. **Implement event creation** with Supabase
7. **Build photo upload** with Storage
8. **Test with real devices**

---

## Estimated Timeline

**Week 1:** Auth + Database setup  
**Week 2:** Photo upload + Storage  
**Week 3:** Real-time + Reveal system  
**Week 4:** Testing + Bug fixes  

**Target:** 4 weeks to MVP-ready backend

---

Ready to start building? Let's begin with setting up your Supabase project! 🚀

