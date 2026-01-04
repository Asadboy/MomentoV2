# Beta Readiness Design
**Date:** January 4, 2026
**Target:** Jan 10th Beta Launch (6 days)
**Status:** Design Complete - Ready for Implementation

---

## Overview

Simplify event creation flow and fix core timing logic before beta launch. Remove complexity that detracts from core experience (emoji pickers, manual time selection). Establish foundation for future premium tier.

---

## 1. Event Timing Logic (Simplified)

### Current Behavior
- User picks start AND end times
- Reveal time calculated as: 8pm same day as `endsAt`, or 8pm next day if event ends after 8pm
- Complex, unintuitive logic

### New Behavior
- User picks: **Start time only**
- System auto-calculates:
  - `endsAt = startsAt + 12 hours` (photo-taking window)
  - `releaseAt = startsAt + 24 hours` (reveal time)

### Example
- Party starts: Saturday 8pm
- Photos accepted until: Sunday 8am (12h from start)
- Photos reveal: Sunday 8pm (24h from start)

### Rationale
- Predictable: Always 24h from party start
- Simple: One input instead of three
- Better UX: "Next day dopamine hit" at same time party started

---

## 2. Photo Limits (Beta Fix)

### Current Setup
- Database: `max_photos_per_user` defaults to 5
- RLS policy: Enforces limit server-side
- Client: Check disabled

### Problem
Server rejects uploads after 5 photos per person despite client allowing it.

### Beta Solution (Quick Fix)
Change database default: 5 → 9999 (effectively unlimited)

**SQL Migration:**
```sql
ALTER TABLE events
ALTER COLUMN max_photos_per_user SET DEFAULT 9999;

UPDATE events SET max_photos_per_user = 9999;
```

### Post-Beta Plan
- Add `max_photos_total` column (30 for regular events)
- Add `is_premium` flag to events
- Premium events: unlimited photos
- Regular events: 30 total (not per-user)
- Modify RLS policy to check total event photos

---

## 3. Create Event UI (Ultra-Simplified)

### Current Flow
- Step 1: Name + Emoji picker
- Step 2: Start time + End time
- Step 3: Share/invite

### New Flow
- Step 1: **Event name only** (text input)
- Step 2: **Start time picker** + calculated display
- Step 3: Share/invite (unchanged)

### Emoji Handling
**No emoji picker.** Users type emojis directly in title if desired (e.g., "🎉 Joe's Birthday").

### Step 2 Display
```
Pick when your event starts:
[Date/Time Picker]

📸 Photos accepted for 12 hours (until Sunday 8am)
⏰ Photos develop 24 hours after event starts (Sunday 8pm)
```

---

## 4. Implementation Changes

### 4.1 Database (Supabase SQL)
- Change `max_photos_per_user` default: 5 → 9999
- Update existing events to 9999

### 4.2 Backend (SupabaseManager.swift)
**Location:** `createEvent` function (lines 256-266)

Replace 8pm logic with:
```swift
let endsAt = startsAt.addingTimeInterval(12 * 3600)  // +12 hours
let releaseAt = startsAt.addingTimeInterval(24 * 3600) // +24 hours
```

Also update EventManager.swift (local fake data) to match.

### 4.3 UI Changes

**CreateStep1NameView.swift:**
- Remove emoji picker completely
- Just event name text field

**CreateStep2TimesView.swift:**
- Remove `endsAt` picker
- Show only `startsAt` picker
- Display calculated times as read-only info

**CreateMomentoFlow.swift:**
- Pass only `startsAt` to create function
- Remove `endsAt` parameter

**Event.swift (model):**
- Keep `coverEmoji` field but stop using it in UI
- Or remove entirely (breaking change - would need migration)

---

## 5. Testing Checklist

Before beta launch:
- [ ] Create event with new timing logic
- [ ] Verify event appears in Supabase with correct `startsAt`, `endsAt`, `releaseAt`
- [ ] Take photos, verify uploads succeed with 9999 limit
- [ ] Check event state transitions (upcoming → live → processing → revealed)
- [ ] Join flow testing (via TestFlight with friend)

---

## 6. Future Premium Tier (Post-Beta)

**Regular Events:**
- 30 photos total per event
- Standard features

**Premium Events:**
- Unlimited photos
- Custom event duration (not fixed 12h)
- Custom reveal time (not fixed 24h)

**Implementation Notes:**
- Add `is_premium` column to events table
- Add `max_photos_total` column (default 30)
- Modify RLS policy to check premium status and total count
- Add premium toggle in Create Event UI (Step 2)

---

## Timeline

**Day 1-2:** Implement timing logic + photo limit fix + UI changes
**Day 3:** Testing + bug fixes
**Day 4:** TestFlight setup
**Day 5-6:** Beta testing with friends + iteration
**Day 7:** Launch

---

## Success Criteria

- Event creation takes <30 seconds
- Users understand when photos reveal without explanation
- No upload failures due to photo limits
- Multi-user join flow works seamlessly
- Zero emoji-picker friction
