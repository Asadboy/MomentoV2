# Momento - Next Session Plan (November 30, 2025)

**Previous Session:** November 9, 2025  
**Status:** Backend integration 95% complete, ready for OAuth + testing  
**Git Status:** Committed but not pushed (push via GitHub Desktop when ready)

---

## 🎯 SESSION GOAL

**Primary:** Configure OAuth and test full authentication flow  
**Secondary:** Build photo reveal system  
**Stretch:** Polish error handling and prepare for TestFlight

---

## ✅ WHAT'S ALREADY DONE

### Backend Infrastructure (100% Complete)
- ✅ **Supabase project** - https://thnbjfcmawwaxvihggjm.supabase.co
- ✅ **Database schema** - 4 tables (profiles, events, event_members, photos)
- ✅ **RLS policies** - Secure access control on all tables
- ✅ **Storage bucket** - `momento-photos` (private, with policies)
- ✅ **Migrations** - All pushed to production

### Code Complete (100%)
- ✅ **SupabaseManager.swift** (622 lines)
  - Authentication methods (Apple, Google, Email)
  - Event CRUD (create, join, get, delete, leave)
  - Photo management (upload, get, delete, flag)
  - Real-time subscriptions
  - Join code validation
  - 5-photo limit enforcement

- ✅ **OfflineSyncManager.swift** (295 lines)
  - Photo upload queue
  - Retry logic (max 3 attempts)
  - Background sync on app activation
  - JPEG compression (80%)
  - Persistent queue across app restarts

- ✅ **Authentication UI**
  - `SignInView.swift` - Beautiful sign-in screen
  - `AuthenticationRootView.swift` - Session routing
  - Apple Sign In integration (nonce generation, etc.)

- ✅ **App Integration**
  - `ContentView.swift` - Loads events from Supabase
  - `JoinEventSheet.swift` - Server-side code validation
  - `Event.swift` - Bridge between local/Supabase models
  - `MomentoApp.swift` - Uses AuthenticationRootView

### Build Status
- ✅ **Compiles successfully**
- ✅ **No linter errors**
- ✅ **All dependencies resolved**
- ⚠️ **DEBUG_SKIP_AUTH = true** (bypasses sign-in for testing)

---

## ⚠️ WHAT'S BLOCKING FULL TESTING

### 🔐 Issue: Can't Sign In Yet
**Why:** OAuth providers not configured in Supabase dashboard  
**Impact:** Can't test any authenticated features (create/join events, upload photos)  
**Current Workaround:** `DEBUG_SKIP_AUTH = true` in `AuthenticationRootView.swift`

---

## 🚀 TODAY'S PRIORITY TASKS

### ⭐ **TASK 1: Configure Apple Sign In OAuth** (15-20 minutes)

**Step-by-step:**

1. **Get your Bundle ID from Xcode:**
   - Open `Momento.xcodeproj`
   - Select Momento target
   - General tab → Identity section
   - Copy Bundle Identifier (probably `com.yourname.Momento`)

2. **Go to Apple Developer Portal:**
   - https://developer.apple.com/account/resources/identifiers/list
   - Find your app identifier
   - Enable "Sign in with Apple" capability
   - Create a Service ID (if you don't have one)
   - Note down: Team ID, Service ID, Key ID

3. **Configure in Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/auth/providers
   - Click "Apple" provider
   - Toggle "Enable Sign In with Apple"
   - Add your Bundle ID
   - Add Service ID
   - Upload your .p8 key file (from Apple Developer)
   - Save

4. **Test:**
   - In `AuthenticationRootView.swift`, change:
     ```swift
     private let DEBUG_SKIP_AUTH = false  // Enable real auth
     ```
   - Build on **real device** (Apple Sign In doesn't work on simulator)
   - Tap "Sign in with Apple"
   - Should work! 🎉

---

### ⭐ **TASK 2: Build Photo Reveal System** (2-3 hours)

**What's Missing:** Photos don't auto-reveal after 24 hours

**Files to Create/Modify:**

#### A. Create Reveal Edge Function

**File:** `supabase/functions/reveal-photos/index.ts`
```typescript
import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    // Find events that should be revealed
    const { data: events, error } = await supabase
      .from('events')
      .update({ is_revealed: true })
      .lt('release_at', new Date().toISOString())
      .eq('is_revealed', false)
      .select()
    
    if (error) throw error
    
    console.log(`Revealed ${events?.length || 0} events`)
    
    return new Response(
      JSON.stringify({ success: true, revealed: events?.length || 0 }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

#### B. Deploy Edge Function
```bash
cd /Users/asad/Documents/Momento
supabase functions deploy reveal-photos
```

#### C. Setup Cron Job
In Supabase Dashboard:
- Database → Extensions → Enable `pg_cron`
- Run SQL:
```sql
SELECT cron.schedule(
  'reveal-photos-daily',
  '0 * * * *',  -- Every hour
  $$
  SELECT net.http_post(
    url:='https://thnbjfcmawwaxvihggjm.supabase.co/functions/v1/reveal-photos',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
  ) AS request_id;
  $$
);
```

#### D. Update Swift Code - Add Reveal Check

**File:** `Momento/ContentView.swift` - Add this method:
```swift
/// Check if event photos should be revealed
private func shouldShowPhotos(for event: Event) -> Bool {
    guard event.isRevealed else { return false }
    return Date() >= event.releaseAt.addingTimeInterval(24 * 3600)
}
```

---

### ⭐ **TASK 3: Test Full Flow** (30-60 minutes)

**Once OAuth is configured:**

1. **Sign In Test:**
   - Run app on real device
   - Tap "Sign in with Apple"
   - Complete Face ID/Touch ID
   - Should land on main screen with empty eventos list

2. **Create Event Test:**
   - Tap + button
   - Enter title: "Test Momento"
   - Set release time: 24 hours from now
   - Save
   - Check Supabase dashboard → events table → New row appears

3. **Join Event Test:**
   - Copy the join code from your event
   - Use second device OR sign out and sign in with different Apple ID
   - Tap QR code icon
   - Enter code manually
   - Event should appear in list

4. **Photo Upload Test:**
   - Tap on your event card
   - Camera should open
   - Take a photo
   - Photo should queue and upload
   - Check Supabase Storage dashboard → New photo in bucket
   - Check photos table → New row

5. **Offline Test:**
   - Enable Airplane Mode
   - Take a photo
   - Console should show: "Pending uploads: 1"
   - Disable Airplane Mode
   - Photo should auto-upload
   - Console shows: "✅ Photo uploaded successfully"

---

## 🔑 IMPORTANT INFORMATION

### Supabase Credentials
- **URL:** `https://thnbjfcmawwaxvihggjm.supabase.co`
- **Project Ref:** `thnbjfcmawwaxvihggjm`
- **Access Token:** `sbp_2d6aa71034f57630ad1f3d9322452862c89c3af8`
- **Dashboard:** https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm

### Key Files Location
- **Auth Config:** `Momento/Config/SupabaseConfig.swift`
- **Backend Manager:** `Momento/Services/SupabaseManager.swift`
- **Offline Sync:** `Momento/Services/OfflineSyncManager.swift`
- **Sign In UI:** `Momento/SignInView.swift`
- **Auth Root:** `Momento/AuthenticationRootView.swift`
- **Main View:** `Momento/ContentView.swift`

### Debug Settings
- **Auth Bypass:** Line 16 in `AuthenticationRootView.swift`
  ```swift
  private let DEBUG_SKIP_AUTH = true  // Set to false for real auth
  ```

---

## 🐛 KNOWN ISSUES FROM LAST SESSION

### Issue 1: Build Errors (Stale Cache)
**Symptoms:** "No such module Supabase" or other module errors  
**Solution:**
1. Quit Xcode
2. File → Packages → Reset Package Caches
3. Product → Clean Build Folder (Shift+Cmd+K)
4. Reopen and build

### Issue 2: Can't Create/Join Events in Debug Mode
**Why:** `DEBUG_SKIP_AUTH = true` bypasses auth, so `currentUser` is nil  
**Solution:** Configure OAuth and set `DEBUG_SKIP_AUTH = false`

### Issue 3: Photos Don't Reveal After 24h
**Why:** Auto-reveal system not built yet  
**Solution:** Build Edge Function (Task 2 above)

---

## 📋 COMPLETE TODO LIST

### Critical Path to MVP:
- [ ] **Configure Apple OAuth** (15 min) ← START HERE
- [ ] **Test sign-in flow** (10 min)
- [ ] **Set DEBUG_SKIP_AUTH = false** (1 min)
- [ ] **Build photo reveal Edge Function** (2 hours)
- [ ] **Test reveal system** (30 min)
- [ ] **Add error handling** (1 hour)
- [ ] **Test full flow** (1 hour)
- [ ] **Fix bugs found** (1-2 hours)

### Optional but Recommended:
- [ ] Push notifications for photo reveals
- [ ] Analytics tracking
- [ ] Error tracking (Sentry)
- [ ] App Store assets (icon, screenshots)

---

## 🧪 TESTING COMMANDS

### Quick Connectivity Test
Run app and check console for:
```
✅ Supabase configured successfully
📍 URL: https://thnbjfcmawwaxvihggjm.supabase.co
ℹ️ No active session
```

### Check Upload Queue
In any view, add temporarily:
```swift
.onAppear {
    print("🧪 Testing managers...")
    print("Authenticated: \(supabaseManager.isAuthenticated)")
    print("Pending uploads: \(syncManager.pendingCount)")
}
```

### Verify Database Tables
```sql
-- Run in Supabase SQL Editor
SELECT COUNT(*) FROM profiles;
SELECT COUNT(*) FROM events;
SELECT COUNT(*) FROM event_members;
SELECT COUNT(*) FROM photos;
```

---

## 🎓 IMPORTANT CONTEXT FROM LAST SESSION

### Why We Used Management API
The Supabase CLI had issues with interactive password prompts, so we bypassed it using curl to the Management API directly. This worked perfectly for pushing migrations.

### Why Two Event Models
- `Event` (local) - Optimized for SwiftUI, has UI-specific fields
- `EventModel` (Supabase) - Matches database schema exactly
- Bridge via `init(fromSupabase:)` extension

### Why Offline-First
Users at events often have poor connectivity, so photos queue locally and upload when possible. This prevents lost photos.

### Photo Flow Architecture
1. User captures photo
2. Saved locally immediately (instant feedback)
3. Queued in OfflineSyncManager
4. Uploaded to Supabase Storage in background
5. Retries automatically if fails (max 3 times)
6. Removed from queue when successful

---

## 🔧 TROUBLESHOOTING GUIDE

### "Cannot find 'SupabaseManager' in scope"
**Fix:** Restart Xcode, clean build folder

### "Initializer for conditional binding must have Optional type"
**Status:** Already fixed in last session

### "Reference to captured var 'self' in concurrently-executing code"
**Status:** Already fixed with `guard let self`

### Apple Sign In button doesn't work on simulator
**Expected:** Apple Sign In only works on real devices. Use debug mode on simulator.

### Events don't load
**Check:**
1. User is authenticated
2. Console doesn't show errors
3. Database has events in the `events` table
4. User is in `event_members` table for those events

---

## 🚀 RECOMMENDED SESSION FLOW

### Hour 1: OAuth Setup & Testing
1. Configure Apple Sign In OAuth (15 min)
2. Build on real device (5 min)
3. Test sign-in (10 min)
4. Test create event (10 min)
5. Test join event (10 min)
6. Verify in Supabase dashboard (10 min)

### Hour 2-3: Photo Reveal System
1. Create Edge Function (30 min)
2. Deploy function (10 min)
3. Setup cron job (10 min)
4. Update Swift client code (30 min)
5. Test with fake data (30 min)

### Hour 4: Testing & Polish
1. End-to-end test (30 min)
2. Fix bugs found (30-60 min)
3. Add error messages (30 min)

### Hour 5: Final Prep
1. Push notifications setup (optional)
2. App Store assets prep
3. TestFlight submission

---

## 📱 APPLE SIGN IN SETUP (Detailed Steps)

### Part 1: Apple Developer Portal

1. **Go to:** https://developer.apple.com/account/resources/identifiers/list

2. **Create/Update App Identifier:**
   - Click your app (or create new)
   - Enable "Sign in with Apple" capability
   - Save

3. **Create Service ID:**
   - Click "+" → Service IDs
   - Description: "Momento Sign In"
   - Identifier: `com.yourname.Momento.signin`
   - Enable "Sign in with Apple"
   - Configure: Add your domain (or use Supabase domain)
   - Return URLs: Add Supabase callback URL
   - Save

4. **Create Key:**
   - Keys → "+" 
   - Name: "Momento Apple Sign In Key"
   - Enable "Sign in with Apple"
   - Download .p8 file (SAVE THIS - can't download again!)
   - Note the Key ID

### Part 2: Supabase Dashboard

1. **Go to:** https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/auth/providers

2. **Enable Apple:**
   - Click "Apple"
   - Toggle "Enable Sign In with Apple"
   - Bundle ID: (from Xcode, Step 1)
   - Service ID: `com.yourname.Momento.signin`
   - Team ID: (from Apple Developer)
   - Key ID: (from Step 4 above)
   - Private Key: (paste contents of .p8 file)
   - Save

3. **Test Configuration:**
   - Build app on real device
   - Try signing in
   - Should work immediately!

---

## 🔥 PHOTO REVEAL SYSTEM IMPLEMENTATION

### Option A: Edge Function (Recommended)

**Create:** `supabase/functions/reveal-photos/index.ts`
```typescript
import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const supabase = createClient(supabaseUrl, supabaseKey)
  
  // Get current time
  const now = new Date().toISOString()
  
  // Update events that should be revealed
  const { data, error } = await supabase
    .from('events')
    .update({ is_revealed: true })
    .lt('release_at', now)
    .eq('is_revealed', false)
    .select()
  
  if (error) {
    console.error('Error revealing photos:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  console.log(`✅ Revealed ${data?.length || 0} events`)
  
  return new Response(JSON.stringify({ 
    success: true, 
    revealed: data?.length || 0,
    events: data 
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

**Deploy:**
```bash
cd /Users/asad/Documents/Momento
supabase functions deploy reveal-photos --project-ref thnbjfcmawwaxvihggjm
```

**Setup Cron:**
```sql
-- Run in Supabase SQL Editor
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule function to run every hour
SELECT cron.schedule(
  'reveal-photos-hourly',
  '0 * * * *',  -- Every hour at minute 0
  $$
  SELECT net.http_post(
    url:='https://thnbjfcmawwaxvihggjm.supabase.co/functions/v1/reveal-photos',
    headers:='{"Authorization": "Bearer YOUR_ANON_KEY_HERE"}'::jsonb
  );
  $$
);
```

### Option B: Client-Side Check (Simpler, but not automatic)

**Update:** `Momento/ContentView.swift`

Add this method:
```swift
/// Check if photos should be revealed for an event
private func checkRevealStatus(for event: Event) async {
    guard let uuid = UUID(uuidString: event.id) else { return }
    
    // Check if 24h has passed
    let releaseTime = event.releaseAt.addingTimeInterval(24 * 3600)
    let shouldBeRevealed = Date() >= releaseTime
    
    if shouldBeRevealed && !event.isRevealed {
        // Update in database
        do {
            try await supabaseManager.client
                .from("events")
                .update(["is_revealed": true])
                .eq("id", value: uuid.uuidString)
                .execute()
            
            // Update local state
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRevealed = true
            }
        } catch {
            print("Failed to update reveal status: \(error)")
        }
    }
}
```

Call on app launch:
```swift
.task {
    await loadEvents()
    
    // Check reveal status for all events
    for event in events {
        await checkRevealStatus(for: event)
    }
}
```

---

## 📊 MVP COMPLETION CHECKLIST

### Core Features:
- ✅ User authentication (code ready, OAuth pending)
- ✅ Create events (working with auth)
- ✅ Join events via code (working with auth)
- ✅ Upload photos (working with auth)
- ❌ **Auto-reveal after 24h** ← TODAY'S MAIN TASK
- ✅ Offline photo queue

### Optional Features:
- ⚠️ Push notifications (nice-to-have)
- ⚠️ Real-time counters (method exists, not wired to UI)
- ⚠️ Google Sign In (Apple is enough for MVP)
- ⚠️ Email sign-in (Apple is enough for MVP)

---

## 🎯 SUCCESS CRITERIA FOR TODAY

**Minimum Success:**
- [ ] Apple Sign In works on real device
- [ ] Can create an evento
- [ ] Can join an evento with code
- [ ] Can take and upload a photo
- [ ] Photo appears in Supabase Storage

**Ideal Success:**
- [ ] All of above +
- [ ] Photo reveal system working
- [ ] Tested full flow with 2 devices
- [ ] Ready for TestFlight beta

---

## 💾 GIT STATUS

**Last Commit:** November 9, 2025
```
✅ Complete Supabase backend integration
Commit: 15b7d2f
27 files changed, 4606 insertions(+)
```

**Status:** Committed locally, NOT pushed yet

**Remember:** You push via GitHub Desktop (don't use `git push` commands)

**Files staged and ready to push.**

---

## 🚨 IMPORTANT REMINDERS

### Before Starting:
1. Push last session's work via GitHub Desktop
2. Make sure you're on `main` branch
3. Have Apple Developer credentials ready

### During Session:
1. Test on **real device** for Apple Sign In
2. Keep Supabase dashboard open for verification
3. Watch console logs for errors
4. Commit frequently

### Before Ending:
1. Set `DEBUG_SKIP_AUTH = false` if testing complete
2. Document any bugs found
3. Update this file with progress
4. Commit and push

---

## 📞 QUICK REFERENCE

### Build & Run
```bash
cd /Users/asad/Documents/Momento
open Momento.xcodeproj
# Then Cmd+R in Xcode
```

### Clean Build
```bash
# In terminal
rm -rf ~/Library/Developer/Xcode/DerivedData/Momento-*

# Or in Xcode: Shift+Cmd+K
```

### View Logs
- Xcode console (bottom pane)
- Look for ✅ and ❌ emoji indicators

### Check Database
```sql
-- Quick status check
SELECT 
  (SELECT COUNT(*) FROM profiles) as profiles,
  (SELECT COUNT(*) FROM events) as events,
  (SELECT COUNT(*) FROM event_members) as members,
  (SELECT COUNT(*) FROM photos) as photos;
```

---

## 🎓 CONTEXT FOR AI ASSISTANT

**What happened last session:**
1. Built complete Supabase backend integration
2. Created SupabaseManager with all CRUD operations
3. Created OfflineSyncManager for photo uploads
4. Integrated authentication UI
5. Connected all existing views to Supabase
6. Successfully compiled and committed
7. Couldn't test because OAuth not configured
8. Added `DEBUG_SKIP_AUTH = true` as temporary workaround

**Current state:**
- All backend code is written and working
- Build compiles successfully  
- Can see UI but can't test authenticated features
- OAuth configuration is the blocker
- Photo reveal system is missing

**What to focus on:**
1. Priority 1: Get OAuth working so we can actually test
2. Priority 2: Build photo reveal (core feature)
3. Priority 3: Polish and prepare for TestFlight

---

## 🏁 END GOAL FOR TODAY

**By end of session, we should have:**
- ✅ Apple Sign In working on real device
- ✅ Full create → join → photo flow tested
- ✅ Photo reveal system functional
- ✅ All code pushed to GitHub
- ✅ Ready for TestFlight beta testing

**Estimated time:** 4-6 hours for all critical tasks

---

## 🚀 QUICK START COMMAND

**To jump right in:**
```bash
cd /Users/asad/Documents/Momento
open Momento.xcodeproj

# First thing: Configure OAuth in Supabase dashboard
# Then set DEBUG_SKIP_AUTH = false and test!
```

---

**Good luck! You're 95% there - just need to unlock authentication and add the reveal system. Let's finish this! 💪**

**Last Updated:** November 30, 2025  
**Session Status:** Ready to resume  
**Next Action:** Configure Apple OAuth in Supabase

