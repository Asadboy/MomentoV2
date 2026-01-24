# Main Screen UI Redesign

**Date:** 2026-01-24
**Status:** Ready for implementation
**Context:** Event cards look the same across phases, screen feels dated, state doesn't update after reveal

---

## Problem Statement

1. Cards look identical across all phases - hard to tell state at a glance
2. Revealed events still show "Ready to reveal" (bug)
3. Overall screen looks dated despite nice glow effect
4. No visual hierarchy between active and completed events

---

## Design Principles

- **Purple is the brand** - Keep purple throughout, vary intensity not color
- **Calm confidence** - Not pushy or urgent, app is about being present
- **Clear state differentiation** - Instantly know what phase each event is in
- **Celebratory completion** - Revealed events feel like achievements, not just "done"

---

## Phase Designs

### 1. Upcoming Phase

**Goal:** Minimal, anticipation building, not distracting.

| Property | Value |
|----------|-------|
| Border | 1pt, purple at 30% opacity |
| Glow | None |
| Animation | None |

**Content:**
- Event name
- "Starts in 2h 30m" with clock icon
- Member count only (no photo count yet)

**Right indicator:** Circular countdown ring, muted purple, time inside

**Tap action:** Alert "This Momento starts in X hours"

---

### 2. Live Phase

**Goal:** Calm confidence, present-moment feel, not pushy.

| Property | Value |
|----------|-------|
| Border | 2pt, solid purple at 60% opacity |
| Glow | Soft purple, 10pt blur |
| Animation | Gentle pulse, 3s cycle (subtle) |

**Content:**
- Event name
- Green dot + "Live now"
- Member count + "X taken" (group photo count)

**Right indicator:** Camera icon with subtle pulse

**Tap action:** Opens camera immediately

**Key:** No countdown visible - keeps user present, not anxious

---

### 3. Ready to Reveal Phase

**Goal:** Excitement, magic moment, draw attention.

| Property | Value |
|----------|-------|
| Border | 3pt, purple-to-cyan gradient |
| Glow | Strong purple/cyan, 20pt blur |
| Animation | Pulsing glow, shimmer effect |

**Content:**
- Event name
- Sparkle + "Ready to reveal!"
- Member count + "X photos waiting"

**Right indicator:** "Reveal" button with sparkle icon, pulsing

**Tap action:** Opens FeedRevealView

**Note:** This is the current look - keep it, it works

---

### 4. Revealed Phase (Complete)

**Goal:** Celebratory but clearly done, show achievement.

| Property | Value |
|----------|-------|
| Border | 1.5pt, solid purple at 40% opacity |
| Glow | None |
| Animation | None |

**Content:**
- Event name + checkmark badge (top right)
- "Revealed • X liked"
- Member count + total photo count

**Right indicator:** "Gallery" button (muted)

**Tap action:** Opens LikedGalleryView directly

---

## Overall Screen Improvements

### Card Spacing
- Increase gap between cards: 16pt → 20pt

### Sorting Order
1. Live events (most urgent)
2. Ready to Reveal events
3. Upcoming events (by start time)
4. Revealed events (most recent first)

### Header
- Keep current layout
- Slightly more breathing room

---

## Bug Fixes Required

### State Transition After Reveal

**Problem:** Cards stay on "Ready to reveal" after user completes reveal.

**Fix:** When determining card state, check if user has completed reveal:

```swift
// In PremiumEventCard or Event.swift
if event.currentState(at: now) == .revealed {
    // Also check if THIS USER has completed their reveal
    if let progress = revealProgress, progress.completed {
        return .revealed
    } else {
        return .readyToReveal
    }
}
```

### Liked Count for Revealed Cards

**Need:** Fetch user's liked photo count for each revealed event to display "X liked"

---

## Implementation Tasks

| # | Task | Type | Complexity |
|---|------|------|------------|
| 1 | Fix state transition bug after reveal | Bug | Medium |
| 2 | Add liked count to revealed card | Data | Easy |
| 3 | Update Upcoming card styling | UI | Easy |
| 4 | Update Live card styling | UI | Easy |
| 5 | Create Revealed card styling | UI | Easy |
| 6 | Adjust card spacing | UI | Easy |
| 7 | Update sort order | Logic | Easy |

---

## Success Criteria

- [ ] Each phase visually distinct at a glance
- [ ] Revealed events show checkmark and liked count
- [ ] State updates correctly after completing reveal
- [ ] Purple brand maintained throughout
- [ ] Screen feels modern, not dated
- [ ] No urgency/anxiety in Live phase - calm confidence
