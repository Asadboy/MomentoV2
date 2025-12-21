# Momento - Feature Backlog

## Priority Legend
- 🔴 **P0** - Must have for MVP (Jan 10th beta)
- 🟡 **P1** - Should have soon after beta
- 🟢 **P2** - Nice to have
- ⚪ **P3** - Future consideration

---

## 🔴 P0 - MVP (Jan 10th Beta)

### Done ✅
- [x] Google OAuth authentication
- [x] Create evento with Supabase backend
- [x] Join evento via code
- [x] Photo capture during event
- [x] Offline photo queue with retry
- [x] Basic event cards UI

### In Progress 🔄
- [ ] Full end-to-end photo upload test (40 people beta)

### Done ✅ (Dec 21)
- [x] New Create Momento wizard (multi-step flow)
- [x] Start time & end time for events  
- [x] Share flow (QR code, join code, share link)
- [x] Event state handling (upcoming → live → processing → revealed)
- [x] Camera enhancements (front/back toggle, flash, multi-capture)
- [x] Shutter animation + "Saved!" feedback
- [x] Processing state UI ("Developing in X time")
- [x] Removed 5-photo limit for beta

### To Do 📋
- [ ] Photo reveal experience polish
- [ ] Pull-to-refresh events list (exists but needs testing)
- [ ] Verify all photos upload to Supabase storage

---

## 🟡 P1 - Post-Beta Priorities

### User Experience
- [ ] Apple Sign In (needs Apple Dev account)
- [ ] Onboarding flow for first-time users
- [ ] Event countdown animations
- [ ] Photo reveal animations polish
- [ ] Haptic feedback throughout app

### Photos
- [ ] View all photos in an event gallery
- [ ] Photo reactions (emoji reactions on photos)
- [ ] Photo captions
- [ ] Delete your own photos

### Events
- [ ] Edit event details after creation
- [ ] Delete/cancel event
- [ ] Event cover image (not just emoji)
- [ ] See who's in the event (member list)

### Notifications
- [ ] Push notifications setup
- [ ] "Event starting soon" notification
- [ ] "Photos are ready!" notification
- [ ] "Someone joined your evento" notification

---

## 🟢 P2 - Nice to Have

### Social
- [ ] User profiles with avatar
- [ ] Add friends
- [ ] See friends' public events
- [ ] Comments on photos

### Photos
- [ ] Filters on camera
- [ ] Video clips (5-10 seconds)
- [ ] Photo download to camera roll
- [ ] Share individual photos

### Events
- [ ] Recurring events
- [ ] Event templates
- [ ] Private vs public events
- [ ] Event location with map

### Polish
- [ ] App icon design
- [ ] Custom loading animations
- [ ] Confetti on reveal
- [ ] Sound effects

---

## ⚪ P3 - Future Ideas

- [ ] Web app for viewing photos
- [ ] Premium tier (more photos, longer events, etc.)
- [ ] AI photo highlights
- [ ] Printed photo books
- [ ] Integration with Apple Photos
- [ ] Widget for home screen
- [ ] Apple Watch companion

---

## Bugs to Fix 🐛

- [ ] CoreGraphics NaN errors in console (non-blocking)
- [ ] Keyboard constraint warnings (non-blocking)
- [x] Event time showing +1 day (timezone issue) - Fixed with proper startsAt/endsAt

---

## Beta Test Checklist (Jan Beta) ✅

### Before Beta
- [ ] Run verification SQL in Supabase (check storage bucket + event columns)
- [ ] Test create event → appears in Supabase `events` table
- [ ] Test take photo → appears in Supabase `photos` table AND storage bucket
- [ ] Test with airplane mode → photos queue locally → upload when back online
- [ ] Test with 10+ photos in one event
- [ ] Verify all device types (front camera, back camera)

### During Beta
- [ ] Monitor Supabase logs for errors
- [ ] Check storage bucket size
- [ ] Watch for any RLS policy errors

---

## Technical Debt 🔧

- [ ] Add proper error handling throughout
- [ ] Unit tests for SupabaseManager
- [ ] UI tests for critical flows
- [ ] Performance profiling
- [ ] Crash reporting (Sentry/Crashlytics)

---

**Last Updated:** December 21, 2025

