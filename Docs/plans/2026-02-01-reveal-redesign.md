# Momento: Reveal Redesign

**Date:** 2026-02-01
**Status:** Draft

---

## Overview

Refine the reveal experience to feel more ceremonial and immersive. The reveal should feel like opening a disposable camera — not scrolling a feed.

**Core principle:** The reveal is not about showing photos. It's about remembering together.

---

## What's Changing

| Element | Current | New |
|---------|---------|-----|
| Entry | Straight to photos | Pre-reveal screen with stats + ritual line |
| Transition | Instant | Haptic pulse + fade |
| Buttons | Appear immediately | 2-second delay, then fade in together |
| Order | Chronological | Same (first taken = first seen) |
| Mid-flow cards | Repeated reveal card appearing | Fix — continuous flow, no resets |
| Group presence | None | "Revealed together at [time]" on entry |
| Ending | Abrupt | "That was the night." + View Gallery |

---

## Pre-Reveal Screen

**When user taps into a revealed Momento, before seeing photos:**

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│          143 photos                 │
│          11 people                  │
│                                     │
│   Revealed together at 11:52pm      │
│                                     │
│                                     │
│          [ Reveal ]                 │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

**Design details:**

- Full screen, dark background (matches app aesthetic)
- Stats prominent: photo count, contributor count
- "Revealed together at [time]" anchors the shared ritual
- Single "Reveal" button — the only action
- Tapping triggers haptic pulse + fade transition to first photo

**What this does:**

- Builds anticipation
- Reinforces it's a group experience
- Creates a threshold moment before immersion

---

## Photo Reveal Flow

**After tapping Reveal:**

1. **Haptic pulse** — Soft feedback marks the threshold
2. **Fade transition** — 0.5-1 second fade from pre-reveal screen to first photo
3. **First photo appears** — Full screen, no buttons yet
4. **2-second delay** — Photo sits alone, user absorbs it
5. **Buttons fade in** — Like, save, share appear together at once
6. **Swipe to continue** — User swipes to next photo, repeat from step 3

**Visual timeline:**

```
[Tap Reveal]
     ↓
[Haptic pulse]
     ↓
[0.5s fade transition]
     ↓
┌─────────────────────────────────────┐
│                                     │
│                                     │
│            [ PHOTO ]                │
│                                     │
│                                     │
│                                     │  ← No buttons yet
│                                     │
└─────────────────────────────────────┘
     ↓
[2 seconds pass]
     ↓
┌─────────────────────────────────────┐
│                                     │
│                                     │
│            [ PHOTO ]                │
│                                     │
│                                     │
│      ♡  ↓  ↗                        │  ← Buttons fade in together
│                                     │
└─────────────────────────────────────┘
     ↓
[Swipe to next photo, repeat]
```

**Key points:**

- Photos in chronological order (first taken = first seen)
- One photo at a time
- 2-second delay on EACH photo before buttons appear
- No repeated reveal cards mid-flow — continuous once you're in

---

## Closing Moment

**After the last photo, instead of abruptly ending:**

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                                     │
│        That was the night.          │
│                                     │
│                                     │
│         [ View Gallery ]            │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

**Design details:**

- Appears after swiping past the final photo
- "That was the night." — simple, nostalgic, final
- Soft fade-in, same dark aesthetic
- Single button to enter gallery/grid view

**What this does:**

- Provides closure instead of an abrupt stop
- Marks the end of the ceremony
- Transitions into "archive mode" (gallery, downloads, sharing)

---

## Bug Fix: Repeated Reveal Cards

**Problem:** A "tap to reveal" style card appears mid-flow, breaking immersion.

**Fix:**

- Investigate cause (likely loading state or pagination boundary)
- Replace any mid-flow placeholder with subtle loading indicator
- Or preload next batch so there's no visible interruption
- Reveal card should only appear ONCE — at the start

**Principle:** Once you're in the reveal, you're in. No ceremony resets.

---

## What We're NOT Doing

- No 3-act structure with hidden buttons in early phase
- No smart/curated first photo (chronological feels authentic)
- No social activity indicators mid-reveal ("Sarah liked this")
- No mid-flow chapter breaks or pauses

---

## Future Enhancements

**Engagement stats on closing screen:**

After "That was the night." — show summary stats:

```
143 photos. 47 likes. 12 saved.
```

Reinforces group engagement without interrupting the reveal.

**Deferred:** Requires database sanity check on tracking likes/downloads/shares per event.

---

## Implementation Notes

**Pre-reveal screen:**

- New view/component: `PreRevealView`
- Fetch photo count, contributor count, reveal timestamp
- Single button triggers reveal flow

**2-second button delay:**

- Modify `PhotoRevealCard` to hide buttons initially
- Timer starts when photo becomes visible
- Buttons animate in with opacity transition

**Haptic + fade transition:**

- Use `HapticsManager` for soft pulse
- SwiftUI `.transition()` with opacity for fade

**Closing screen:**

- New view/component: `RevealCompleteView`
- Detect when user swipes past last photo
- Transition to closing screen

**Bug fix:**

- Audit reveal flow for any repeated reveal cards
- Check pagination/loading logic

---

## Summary

The reveal becomes:

1. **Entry** — "143 photos. 11 people. Revealed together at 11:52pm." → Tap Reveal
2. **Threshold** — Haptic pulse + fade transition
3. **Immersion** — Photos one at a time, 2-second delay before buttons
4. **Closure** — "That was the night." → View Gallery

No interruptions. No social feed energy. Just remembering together.
