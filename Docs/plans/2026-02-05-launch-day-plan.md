# Launch Day Sprint — Feb 6, 2026

**Goal:** Complete all remaining V1 work in one day. App Store submission ready by end of day.

---

## Block 0: First Thing (9-9:30am) — Bug Fixes

### Claude does:
- [ ] Fix member count showing 2 instead of 1 (off-by-one in count query or trigger)
- [ ] Fix photo count showing 2 instead of 1 (same — likely double-counting or trigger issue)
- [ ] Fix logout not clearing events (stale state — EventManager/ContentView not resetting on sign out)

---

## Block 1: Morning (9:30-11am) — App Store Blockers

### Asad does:
- [ ] Create in-app purchase in App Store Connect (£7.99, non-consumable)
- [ ] Get product ID + RevenueCat API key
- [ ] Create APNs key in Apple Developer portal
- [ ] Add APNs key to Supabase project settings

### Claude does:
- [ ] Write privacy policy + terms of service content
- [ ] Add `/privacy` and `/terms` pages to Next.js web app
- [ ] Wire privacy/terms buttons in SignInView to open URLs
- [ ] Clean debug code: wrap `print()` in `#if DEBUG`
- [ ] Gate "Card Preview" debug button behind `#if DEBUG`
- [ ] Remove `DEBUG_SKIP_AUTH` from release builds

---

## Block 2: Midday (11am-1pm) — RevenueCat + Premium Flow

### Claude does:
- [ ] Add RevenueCat SDK dependency
- [ ] Initialize RevenueCat in app startup
- [ ] Build purchase flow: present paywall → handle result → mark event premium in Supabase
- [ ] Wire PremiumUpgradeModal to RevenueCat
- [ ] Premium prompt card at end of reveal feed (host-only)
- [ ] Premium prompt modal on event screen (host-only, once per visit)
- [ ] Expiry countdown badge on free event cards
- [ ] Surface web album link for premium events

---

## Block 3: Afternoon (1-3pm) — Push Notifications

### Claude does:
- [ ] iOS: Request notification permission on first launch
- [ ] iOS: Register device token, save to `profiles.device_token` in Supabase
- [ ] iOS: Handle incoming push (deep link to event)
- [ ] Supabase: Add `device_token` column to profiles table
- [ ] Edge Function: `send-push` — sends APNs notification to device tokens
- [ ] Edge Function: `notification-cron` — runs every 5 mins:
  - "Your reveal is ready!" → all members when `release_at` passes
  - "Don't forget to capture!" → members with 0 photos, 1hr after event start

---

## Block 4: Late Afternoon (3-5pm) — Backend + Polish + Submit Prep

### Claude does:
- [ ] Edge Function: `cleanup-expired-events` — daily cron, soft-delete free events 7 days post-reveal
- [ ] Edge Function: `revenuecat-webhook` — verify purchase, set premium fields server-side
- [ ] Final code review pass

### Asad does:
- [ ] Deploy Next.js privacy/terms pages (Vercel)
- [ ] Deploy all Edge Functions to Supabase
- [ ] Test full flow on physical device (clean install):
  - Sign in → Create → Capture → Wait for reveal → Reveal → Like → Download (check watermark) → Premium purchase
- [ ] Push notifications test (both triggers)
- [ ] Take App Store screenshots during testing
- [ ] Fill out App Store Connect: description, keywords, privacy labels, age rating
- [ ] Submit for review

---

## App Store Submission Checklist

- [ ] Privacy policy URL live and working
- [ ] Terms of service URL live and working
- [ ] SignInView buttons link to correct URLs
- [ ] In-app purchase working end-to-end
- [ ] Push notifications requesting permission
- [ ] No debug UI visible in release build
- [ ] No print statements in release build
- [ ] App icon present
- [ ] 3+ screenshots uploaded
- [ ] App description written
- [ ] Privacy nutrition labels filled out
- [ ] Age rating questionnaire complete
