# Momento Backend Testing Checklist

## 🎯 Testing Session - Backend Integration

### Phase 1: App Launch & UI Flow (No Auth Required)

**1. Run the App**
```bash
# From terminal OR just press Cmd+R in Xcode
cd /Users/asad/Documents/Momento
open Momento.xcodeproj
```

**Expected Behavior:**
- ✅ App launches without crashing
- ✅ Shows splash screen with loading spinner
- ✅ After 0.5 seconds, shows SignInView (beautiful gradient background)
- ✅ Console shows: "✅ Supabase configured successfully"
- ✅ Console shows: "📍 URL: https://thnbjfcmawwaxvihggjm.supabase.co"
- ✅ Console shows: "ℹ️ No active session" (since not logged in)

**2. Check SignInView UI**
- ✅ See "Momento" title with camera icon
- ✅ See "Sign in with Apple" button (white)
- ✅ See "Sign in with Google" button (grayed out/disabled)
- ✅ See "Sign in with Email" button (grayed out/disabled)
- ✅ See Terms & Privacy Policy links at bottom

**3. Try Apple Sign In (Will Fail - Expected)**
- Tap "Sign in with Apple"
- Expected: Error message OR Apple sign in sheet appears but fails
- Why: OAuth not configured in Supabase dashboard yet

---

### Phase 2: OAuth Configuration (Required for Full Testing)

**Before continuing, you MUST configure authentication:**

1. Go to: https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/auth/providers

2. **Enable Apple Sign In:**
   - Click "Apple" provider
   - Toggle "Enable"
   - Add your iOS Bundle ID: `com.yourcompany.Momento` (check in Xcode)
   - Get Apple credentials from https://developer.apple.com
   - Add Services ID and Key ID

3. **Enable Google Sign In (Optional):**
   - Click "Google" provider
   - Toggle "Enable"
   - Add OAuth Client ID and Secret from Google Cloud Console

---

### Phase 3: Full Flow Testing (After OAuth Setup)

**1. Sign In Flow**
```
Launch App → Splash Screen → SignInView → Tap Apple Sign In → Face ID/Touch ID → SUCCESS!
```

**Expected Console Output:**
```
✅ Supabase configured successfully
📍 URL: https://thnbjfcmawwaxvihggjm.supabase.co
✅ User session found: [UUID]
✅ Profile created for user: [username]
```

**2. Create Event Flow**
```
Main Screen → Tap + Button → Enter Event Details → Save
```

**Expected:**
- Event appears in list immediately
- Console shows: `✅ Event created: [title] with code: [CODE]`
- Check Supabase dashboard → Events table → New row appears

**3. Join Event Flow**
```
Main Screen → Tap QR Code Icon → Enter Code → Join Event
```

**Expected:**
- Event validation happens on server
- If valid code: Event appears in your list
- If invalid: Error message shown
- Console shows: `✅ Joined event: [title]`

**4. Photo Capture Flow**
```
Tap Event Card → Camera Opens → Take Photo → Photo Captured
```

**Expected:**
- Photo saves locally immediately
- Console shows: `✅ Photo captured and queued for upload: [UUID]`
- Console shows: `Pending uploads: 1`
- Photo uploads in background
- Check Supabase Storage → momento-photos bucket → New photo appears

**5. Offline Sync Test**
```
Turn on Airplane Mode → Take Photo → Turn off Airplane Mode → Wait
```

**Expected:**
- Photo queues while offline
- Auto-uploads when back online
- Console shows: `✅ Photo uploaded successfully: [UUID]`

---

### Phase 4: Database Verification

**Check Supabase Dashboard:**

1. **Profiles Table:**
   - https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/editor
   - Should see your user profile with username

2. **Events Table:**
   - Should see created events with join codes
   - Member count should update

3. **Event Members Table:**
   - Should see your user_id linked to events
   - is_creator = true for your events

4. **Photos Table:**
   - Should see uploaded photos
   - storage_url should point to bucket

5. **Storage Bucket:**
   - https://supabase.com/dashboard/project/thnbjfcmawwaxvihggjm/storage/buckets
   - Open "momento-photos"
   - Should see folders by event ID
   - Inside: JPEG files

---

## 🐛 Common Issues & Solutions

### Issue: "No such module 'Supabase'"
**Solution:** 
1. File → Packages → Reset Package Caches
2. Product → Clean Build Folder (Shift+Cmd+K)
3. Product → Build (Cmd+B)

### Issue: Apple Sign In fails
**Solution:** Must configure in Supabase dashboard first

### Issue: Photos don't upload
**Check:**
1. User is authenticated
2. User is member of the event
3. User hasn't exceeded 5-photo limit
4. Network connection exists

### Issue: "Profile not found"
**Solution:** Auto-created on first sign in, wait a moment and retry

---

## 📊 Success Criteria

Before considering backend integration "done":

- [ ] App launches without crashes
- [ ] SignInView appears correctly
- [ ] Apple Sign In works (after OAuth setup)
- [ ] Can create events
- [ ] Events appear in Supabase database
- [ ] Can join events with code
- [ ] Can capture photos
- [ ] Photos upload to Supabase Storage
- [ ] Offline queue works
- [ ] No console errors

---

## 🎥 Quick Demo Script

**For showing to team/testing:**

1. **Launch**: "App launches → Shows sign in screen"
2. **Auth**: "Sign in with Apple → Face ID → Success"
3. **Create**: "Create new momento called 'Test Event'"
4. **Join**: "Copy join code, use second device to join"
5. **Photo**: "Take a photo → Uploads automatically"
6. **Offline**: "Turn off WiFi, take photo, turn on WiFi → Auto-syncs"
7. **Dashboard**: "Check Supabase → All data appears"

---

## 🚀 Next Steps After Testing

1. **If everything works:**
   - Commit and push to GitHub
   - Update BACKEND_PROGRESS.md with test results
   - Start on Phase 2 features (photo reveal, notifications)

2. **If issues found:**
   - Document in GitHub Issues
   - Fix critical bugs
   - Re-test

3. **For production:**
   - Add error tracking (Sentry)
   - Add analytics
   - Beta test with 10-20 users
   - Scale to 50-200 users

---

**Last Updated:** November 9, 2025  
**Status:** Ready for Testing  
**Next:** Configure OAuth → Full Testing

