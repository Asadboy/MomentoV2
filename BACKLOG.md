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
- [ ] New Create Momento wizard (multi-step flow)
- [ ] Start time & end time for events
- [ ] Share flow (QR code, join code, share link)

### To Do 📋
- [ ] Photo reveal experience (24h after event ends)
- [ ] Event state handling (countdown → live → ended → reveal)
- [ ] Pull-to-refresh events list
- [ ] Basic error handling UI

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

---

## Technical Debt 🔧

- [ ] Add proper error handling throughout
- [ ] Unit tests for SupabaseManager
- [ ] UI tests for critical flows
- [ ] Performance profiling
- [ ] Crash reporting (Sentry/Crashlytics)

---

**Last Updated:** December 21, 2025

