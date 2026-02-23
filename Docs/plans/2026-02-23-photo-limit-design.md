# Photo Limit — Disposable Camera Experiment

**Date:** 2026-02-23
**Status:** Approved
**Part of:** Capture Feature Revamp

## Concept

Each guest gets 12 photos per event — like handing everyone their own disposable camera at the party. The hypothesis: scarcity drives intentionality, which drives better reveals.

This is a behavioral experiment for the next beta. No monetization, no upsell. We want to learn:
- Do users take more intentional photos?
- Does the reveal feel higher quality?
- How many guests use all 12 vs. stop early?

## Design Decisions

- **12 photos per person** (host included, no exceptions)
- **Hardcoded constant** for now, coded so it's easy to swap to host-configurable later (10 / 16 / 24 / unlimited)
- **Server-side enforcement** with client-side UX
- **No schema changes** — limit is application logic on existing `photos` table
- **No delete-and-retake** — once a photo is taken, it's taken

## Camera UX

### Counter
- Existing rolling dial counter (bottom-left) counts **down** from remaining shots
- On camera open, fetch remaining count from server: `12 - photosTaken`

### Last 3 shots
- Counter text shifts to amber/orange at 3 remaining
- No toast or modal — just a subtle color cue

### Hitting 0 (lock state)
- Counter shows `0`
- Shutter button gets a `lock.fill` SF Symbol overlay
- Tapping the locked shutter: haptic buzz + shake animation on the button
- Camera viewfinder stays live (doesn't feel like a crash)
- User closes the camera themselves

### Reopening after limit reached
- Camera sheet still opens but shows locked state immediately (counter at 0, lock on shutter)

## Server-Side Logic

### Fetch count
```sql
SELECT COUNT(*) FROM photos WHERE event_id = :eventId AND user_id = :userId
```
Returns `photosTaken`. Camera initializes with `remaining = 12 - photosTaken`.

### Upload rejection
Before uploading a queued photo in `OfflineSyncManager`, re-check server count. If `photosTaken >= 12`, drop the photo from the queue. Handles:
- App crash/restart mid-session
- Offline queued photos exceeding the limit
- Client-side bypass attempts

### Analytics
Fire `photo_limit_reached` PostHog event when a user hits 0 remaining.

## Files to Modify

1. **`CameraView.swift`** — Countdown counter, amber at 3, lock state at 0 (icon, shake, haptic)
2. **`PhotoCaptureSheet.swift`** — Fetch remaining count on appear, pass to CameraView, block capture at 0
3. **`OfflineSyncManager.swift`** — Server-side count check before upload, drop excess photos
4. **`SupabaseManager.swift`** — Add `getPhotoCount(eventId:userId:)` method, replace commented-out limit check

## New File

5. **`Config/PhotoLimitConfig.swift`** — Single constant `defaultPhotoLimit = 12`

## What We're NOT Building

- No host configuration UI
- No database schema changes
- No upsell or paywall
- No different limits for hosts vs guests
- No delete-and-retake mechanic
