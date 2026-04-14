# Momento — Launch Audit
*April 2026 | 5th beta (Milan) this weekend → App Store after*

---

## The Shift in Thinking

**Old mindset:** Gate features → monetise → ship
**New mindset:** Build the best product → ship → monetise from position of market leadership

USP is singular: **10 shots.** Not filters, not premium tiers. The constraint IS the product.

---

## Where We Are

| Area | Status |
|---|---|
| Core loop (create → shoot → reveal) | ✅ Working, 4 betas validated |
| 10-shot limit enforced | ✅ |
| Multi-user (separate Supabase accounts) | ✅ |
| TestFlight distribution | ✅ |
| Black & white theme | ✅ |
| Onboarding flow | ✅ |
| Analytics (PostHog) | ✅ |
| Film filter on photos (BethanReynolds/Kodak Gold) | ✅ Applied automatically on upload |
| Offline queue with retry | ✅ |
| Push notifications | ❌ Zero implementation |
| App Store assets | ❌ Not started |
| yourmomento.app pages (terms, privacy, album) | ❌ URLs hardcoded, pages must exist |

---

## Milan Beta (This Weekend) — Pre-Flight

These are the only things that matter before Saturday:

- [ ] Build to all 3 devices via TestFlight
- [ ] All 3 on separate Supabase accounts — confirm multi-user works
- [ ] Monitor Supabase dashboard during the shoot for errors
- [ ] Note any friction in the UX — especially the reveal moment

**Push notifications:** Not needed for Milan. 3 people, controlled test, you know the reveal time. Skip.

---

## Dead Code to Remove

### 1. `AccordionRow.swift` — DELETE
- Lives in `Components/AccordionRow.swift`
- Never used anywhere in the app UI
- Only appears in its own `#Preview`
- Safe to delete + remove from `project.pbxproj`

### 2. `FilterPickerView.swift` — DELETE (the UI only, filter still works)
- `FilterPickerView` / `FilterOptionView` are never rendered anywhere
- Users can't select a filter — the Kodak Gold (BethanReynolds) filter is applied automatically to all photos in `OfflineSyncManager.swift:276`
- The `PhotoFilter` enum and `selectedFilter` state in `CreateMomentoFlow` exist but only send to analytics — no user-facing effect
- **Decision:** Either surface the filter picker in the camera, OR delete this UI and lean into "Kodak Gold by default" as part of the aesthetic. Given 10-shots USP, automatic film filter feels right — delete the picker.
- Safe to delete `FilterPickerView.swift` + remove `selectedFilter` state from `CreateMomentoFlow`

### 3. Stale session notes — DELETE
These are development artifacts, not docs. Safe to delete:
```
2025-11-30_NEXT_SESSION.md
SESSION_2025_11_30_OAUTH.md
SESSION_2025_11_30_SUMMARY.md
SESSION_2025_12_21_PHOTO_UPLOAD.md
SESSION_2025_12_26_REVEAL_GALLERY.md
SESSION_SUMMARY.md
HANDOFF_OAUTH_SETUP.md
INSTALL_SUPABASE_SDK.md
INSTALL_SWIFTLINT.md
MANUAL_SUPABASE_INSTALL.md
PHOTO_REVEAL_SYSTEM_COMPLETE.md
QUICK_START_REVEAL.md
QUICK_TEST.md
REVEAL_SYSTEM_SETUP.md
BACKEND_PROGRESS.md
DATABASE_TODO.md
```
Keep: `CLAUDE.md`, `SETUP.md`, `BACKLOG.md`, `MOMENTO_VISION.md`, `TESTING_CHECKLIST.md`

---

## Naming Clarity

**`PremiumEventCard`** is just the main event card. No premium logic in it — it's state-aware (live/upcoming/processing/reveal/revealed) with shot dots, badges, pulsing glow. The name is a legacy artifact from an earlier premium tier idea. Rename to `EventCard` post-launch if it causes confusion, but not a priority.

---

## Before App Store Submission

### Push Notifications (P0)
Zero implementation exists. This is the biggest remaining technical task.

Required flows:
- `"Your photos are ready to reveal"` — sent when `releaseAt` passes
- `"X just joined your momento"` — nice to have

Implementation path:
1. Enable Push Notifications capability in Xcode
2. Add `UNUserNotificationCenter` permission request (during onboarding or on first event create)
3. Register device token with Supabase
4. Use Supabase Edge Function (or pg_cron + Supabase Realtime) to trigger when `releaseAt` passes
5. Send via APNs

### yourmomento.app URLs (P0 for App Store)
Hardcoded in 4 places:
- `SignInView.swift` — Terms of Service + Privacy Policy links
- `FeedRevealView.swift` — Share album link (2 places)
- `LikedGalleryView.swift` — Share album link
- `PremiumEventCard.swift` — Share album link

The terms/privacy pages **must exist** for App Store review. Album sharing is a feature, not a review requirement, but it shouldn't 404.

### App Store Assets
- Screenshots (required): events list, live camera, reveal moment
- App description + keywords
- App icon (check it looks sharp at all sizes)

### Tech Debt (post-launch, not blocking)
- Reveal state stored in `UserDefaults` (local only) — should sync to Supabase so reveal history persists across device reinstalls. See `RevealStateManager.swift`
- Crash reporting not set up (Sentry or Crashlytics)

---

## The Monetisation Position

Confirmed: no feature gating at launch. Ship the best 10-shot experience free.

When monetisation comes:
- Mental model = buying a disposable camera ($7.99 one-time per event, paid by host)
- Premium unlocks: 20 shots (2 rolls), no watermark, multi-day events
- Free tier stays fully functional — guests never hit a wall

---

## Summary Priorities

**Before Milan (this weekend):**
1. Nothing critical — trust the 4 previous betas

**Before App Store:**
1. Push notifications ("photos ready") — biggest technical gap
2. yourmomento.app terms + privacy pages live
3. App Store screenshots + description
4. Delete dead code (AccordionRow, FilterPickerView, session notes)

**Post-launch:**
- Sync reveal state to Supabase
- Crash reporting
- Rename PremiumEventCard → EventCard (cosmetic)
