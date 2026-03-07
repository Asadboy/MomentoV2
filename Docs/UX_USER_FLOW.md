# Momento — Full UX User Flow

**Date:** March 2026
**Context:** Post-pivot to 10-shot disposable camera for parties

---

## Table of Contents

1. [First-Time User Onboarding](#1-first-time-user-onboarding)
2. [Host Creating an Event](#2-host-creating-an-event)
3. [Guest Joining an Event](#3-guest-joining-an-event)
4. [Camera Experience During Event](#4-camera-experience-during-event)
5. [Shot Counter Mechanics](#5-shot-counter-mechanics)
6. [What Happens When Shots Run Out](#6-what-happens-when-shots-run-out)
7. [Event Ending](#7-event-ending)
8. [Photo Reveal Experience](#8-photo-reveal-experience)
9. [Downloading & Sharing Photos](#9-downloading--sharing-photos)
10. [Web Album Experience](#10-web-album-experience)
11. [Edge Cases](#11-edge-cases)
12. [Screen Inventory](#12-screen-inventory)
13. [Disposable Camera Feel — Suggestions](#13-disposable-camera-feel--suggestions)

---

## 1. First-Time User Onboarding

### Current Flow

```
App Launch
  → AuthenticationRootView (checks session)
  → SignInView (Google / Apple sign-in)
  → UsernameSelectionView (pick @username, 3-20 chars)
  → OnboardingView (3 swipeable screens)
      Screen 1: "Every event looks different through every lens"
      Screen 2: "Shoot now. See everything later" (shows 12hr window + 24hr reveal)
      Screen 3: "Then everything drops at once" (stacked photo cards)
  → OnboardingActionView ("Create a Momento" / "Join a Momento")
  → ContentView (main event list)
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Onboarding Screen 2 | Shows "12 hour photo window" | Update to emphasise **10 shots per person** as the core mechanic |
| Onboarding Screen 2 | 3-step visual: Capture → Locked → Revealed | Add shot counter visual — show the 10 → 0 countdown concept |
| OnboardingActionView | Equal weight: Create / Join | Should still work — host sees "Create", guest who got a link sees "Join" |
| Username | Required before onboarding | **Question: Is username still needed?** Currently no social features use it. Only shows on photo attribution ("by @username"). Could simplify onboarding by removing or making optional later. Keep for now since it's attribution. |

### Recommended Flow (Pivot)

```
App Launch
  → SignInView (Google / Apple)
  → UsernameSelectionView (keep — used for photo attribution)
  → OnboardingView (3 screens, updated copy)
      Screen 1: "Your party. One disposable camera each."
      Screen 2: "10 shots. No previews. No retakes." (show shot counter rolling down)
      Screen 3: "The next morning — see everything everyone took."
  → OnboardingActionView ("Create a Momento" / "Join a Momento")
  → ContentView
```

### State Transitions

```
checkingAuth ──[no session]──→ needsSignIn
     │                              │
     │                        [sign in success]
     │                              │
     ├──[session found]──→ needsUsername ──[username set]──→ needsOnboarding
     │                                                           │
     │                                                   [onboarding complete]
     │                                                           │
     └──[returning user]──→ authenticated ←──────────── needsAction
```

---

## 2. Host Creating an Event

### Current Flow

```
ContentView → tap "+" button
  → CreateMomentoFlow (3-step sheet)

Step 1: Name Your Momento
  - Text input with glow focus effect
  - Suggested names: "Birthday", "Weekend Trip", "Night Out", "Game Day", "Celebration"
  - Next button enabled when name entered

Step 2: Configure Timing
  - Date picker (default: 1 hour from now)
  - Auto-calculates:
      endsAt = start + 12 hours (photo window)
      releaseAt = start + 24 hours (reveal time)
  - Shows timeline:
      📷 "Photo Window: 12 hours until [time]"
      🕐 "Photos Reveal: 24 hours after start"

Step 3: Share & Invite
  - Success checkmark
  - 6-character join code displayed
  - Copy code button (with "Copied!" feedback)
  - Share button (renders invite card as image, opens share sheet)
  - Done → dismisses back to ContentView
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Suggested names | "Weekend Trip", "Night Out", "Game Day" | Replace with birthday/party focused: **"Birthday", "House Party", "Kickback", "Celebration", "Get Together"** |
| Step 2 timeline | Shows photo window (12hrs) + reveal (24hrs) | Add: **"Each guest gets 10 shots"** — make this prominent |
| Step 2 info | Technical timeline focus | Add a line: **"Everyone gets their own roll of 10 photos"** |
| Photo limit | Hardcoded 12 per user in `PhotoLimitConfig` | **Change to 10** |

### Recommended Flow (Pivot)

```
Step 1: Name Your Momento
  - Same UI, updated suggested names
  - "Birthday", "House Party", "Kickback", "Celebration", "Get Together"

Step 2: Set the Time
  - Date picker for start time
  - Simplified info display:
      "📷 10 shots each"
      "🔒 Photos locked until reveal"
      "✨ Reveal: [date/time] (24hrs after start)"

Step 3: Invite Your Friends
  - Same share mechanics
  - Invite message updated: "Join my Momento! Everyone gets 10 shots 📸"
```

### State Transitions

```
ContentView ──[tap +]──→ Step 1 (Name)
                             │
                        [name entered]
                             │
                         Step 2 (Time)
                             │
                        [tap Next → API creates event]
                             │
                         Step 3 (Share)
                             │
                        [tap Done]
                             │
                         ContentView (new event in list)
```

---

## 3. Guest Joining an Event

### Current Flow

```
Two entry points:
  A) QR icon in toolbar → JoinEventSheet
  B) OnboardingActionView → "Join a Momento" → JoinEventSheet

JoinEventSheet has two modes:

Mode 1: QR Scan (default)
  - Camera viewfinder with scan frame
  - Scans QR code → extracts join code
  - Auto-lookup event

Mode 2: Code Entry
  - 6-character input field
  - Clipboard detection (auto-fills if valid code found)
  - Accepts: raw code, momento:// link, https:// link
  - "Preview" button when 6 chars entered

Both modes → EventPreviewModal
  - Shows: event name, date, member count
  - "Join" button → SupabaseManager.joinEvent()
  - Dismiss → ContentView (event added with glow animation)
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| EventPreviewModal | Shows name, date, member count | Add: **"You'll get 10 shots"** — set expectation before joining |
| Post-join | Event appears in list with glow | Consider: brief **"You've got 10 shots — make them count"** toast/moment |
| Clipboard detection | Detects 6-char codes | No change needed — works well |

### Recommended Flow (Pivot)

```
JoinEventSheet (QR Scan / Code Entry — same as current)
  → EventPreviewModal
      Event name
      Host: @hostname
      Date: [start time]
      "You'll get 10 shots 📷"
      [Join] [Cancel]
  → Join confirmed
  → ContentView (event in list, glow animation)
```

### State Transitions

```
ContentView ──[QR icon]──→ JoinEventSheet
                               │
                    ┌──────────┴──────────┐
                    │                     │
              QR Scan Mode          Code Entry Mode
                    │                     │
              [scan code]          [enter 6 chars]
                    │                     │
                    └──────────┬──────────┘
                               │
                        [lookup event]
                               │
                    ┌──────────┴──────────┐
                    │                     │
              Event Found           Not Found
                    │                     │
            EventPreviewModal      Error message
                    │
              [tap Join]
                    │
              API: joinEvent()
                    │
              ContentView (new event, glow)
```

---

## 4. Camera Experience During Event

### Current Flow

```
ContentView → tap event card (when event state = .live)
  → PhotoCaptureSheet
      - Fetches remaining photo count from server
      - Shows loading spinner until ready
      - If permission denied → shows request dialog
  → CameraView
      Top bar: [X close] [⚡ flash] [0.5x/1.0x zoom] [🔄 flip]
      Viewfinder: Live camera preview
      Bottom: [Film counter (left)] [Shutter button (center)] [empty (right)]

Capture flow:
  1. Tap shutter → haptic feedback
  2. White flash animation (0.05s in, 0.15s out)
  3. Photo captured via AVFoundation
  4. "Saved!" indicator flashes at top
  5. Film counter decrements with spring animation
  6. Photo saved locally → queued for upload
  7. Camera stays open for next shot

No preview of captured photo. Camera stays live.
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Photo limit | 12 (`PhotoLimitConfig.defaultPhotoLimit`) | **Change to 10** |
| Film counter | Rolling number, white (normal) → orange (≤3) → gray (locked) | This is great — keep it. Update threshold to match 10 (orange at ≤3 still works) |
| Post-capture | "Saved!" text at top | Good — reinforces "no preview" mechanic |
| Shutter button | Standard white circle | No change needed |
| Right side of bottom bar | Empty | **Suggestion: Show mini shot tally (e.g. "3/10" or dots)** — see suggestions section |

### Recommended Flow (Pivot)

```
Tap live event card
  → Camera opens
  → Shot counter shows "10" (or remaining count)

Take photo:
  Tap shutter
  → Flash animation
  → "Saved!" indicator
  → Counter: 10 → 9 (spring animation)
  → Camera stays live, no preview

Continue shooting...
  → Counter turns orange at 3 remaining
  → Counter hits 0
  → Shutter locks (lock icon appears)
  → Tap locked shutter → shake + error haptic
  → User closes camera

Close camera:
  → Back to ContentView
  → Photos upload in background (offline-safe)
```

### State Transitions

```
ContentView ──[tap live event]──→ PhotoCaptureSheet
                                       │
                                  [load remaining count]
                                       │
                              ┌────────┴────────┐
                              │                 │
                        count > 0          count = 0
                              │                 │
                         CameraView      CameraView (locked)
                              │                 │
                       [tap shutter]      [tap shutter]
                              │                 │
                     Capture photo      Shake + haptic
                              │           (nothing happens)
                     Decrement counter
                              │
                     ┌────────┴────────┐
                     │                 │
               count > 0          count = 0
                     │                 │
               Camera stays      Lock shutter
               open for next     Show lock icon
```

---

## 5. Shot Counter Mechanics

### Current Implementation

```
Location: Bottom-left of CameraView
Visual: Film icon + rolling number wheel

Behaviour:
  - Numbers scroll DOWN as count decreases (like film advancing)
  - Spring animation on each decrement
  - Color states:
      White    → normal (4+ remaining)
      Orange   → low (≤3 remaining)
      Gray     → locked (0 remaining)

Loading:
  - On camera open: fetch remaining count from server
  - Formula: limit - (photos already uploaded for this event by this user)
  - Default limit: 12 (needs to become 10)
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Default limit | 12 | **10** |
| Counter prominence | Bottom-left, film icon + number | **Make bigger / more prominent** — this is THE mechanic |
| Orange threshold | ≤3 | Keep at ≤3 (30% of 10, feels right) |
| Lock threshold | 0 | No change |

### Recommended Counter UX (Pivot)

```
Visibility states:

  [📷 10]  Full roll (white, calm)
  [📷  7]  Mid-roll (white, calm)
  [📷  3]  Low roll (orange, slightly larger)
  [📷  1]  Last shot (orange, pulse animation?)
  [📷  0]  Empty (gray, lock icon on shutter)
```

### Key Design Decision

The counter should feel like a **film advance wheel**, not a digital counter. The rolling number animation already achieves this. The pivot just needs to:

1. Change the limit from 12 → 10
2. Optionally increase visual prominence
3. Consider a subtle pulse or glow when hitting the last 3 shots

---

## 6. What Happens When Shots Run Out

### Current Implementation

```
When photosRemaining reaches 0:
  1. Film counter shows 0 in gray
  2. Shutter button shows lock icon overlay
  3. Shutter button turns gray/muted
  4. Tapping locked shutter:
     - Button shakes (horizontal oscillation)
     - Error haptic feedback
     - Nothing else happens
  5. Camera stays open (user can close manually via X)

No message. No prompt. No celebration.
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Lock feedback | Shake + haptic only | **Add a message**: "Roll finished" or "That's a wrap" |
| Post-lock state | Camera stays open silently | **Auto-close camera after brief moment?** Or show a completion card |
| Emotional beat | None — feels like an error | Should feel like **satisfaction**, not failure |

### Recommended Flow (Pivot)

```
User takes shot #10 (last shot):
  → Flash animation
  → "Saved!" indicator
  → Counter: 1 → 0
  → Brief pause (0.5s)
  → Shutter locks with lock icon
  → Overlay message fades in:
      "That's a wrap 📷"
      "Your 10 shots are locked in"
      [Close Camera] button
  → User taps close → back to ContentView

If user re-opens camera for this event:
  → Camera opens in locked state immediately
  → Shows: "You've used all 10 shots"
  → Counter shows 0 (gray)
  → Shutter is locked
  → X button to close
```

---

## 7. Event Ending

### Current Implementation

```
Event State Machine:
  UPCOMING  (now < startsAt)          → "Starts in X"
  LIVE      (startsAt ≤ now < endsAt) → Camera active
  PROCESSING (endsAt ≤ now < releaseAt) → "Developing in X"
  REVEALED  (now ≥ releaseAt)         → Reveal available

Timing:
  endsAt = startsAt + 12 hours (photo window closes)
  releaseAt = startsAt + 24 hours (reveal unlocks)

When event moves to PROCESSING:
  - Event card in ContentView updates icon to hourglass
  - Tapping card shows alert: "developing in X hours"
  - No push notification currently
  - Camera can no longer be opened for this event

When event moves to REVEALED:
  - Event card updates to sparkle icon
  - Tapping opens FeedRevealView
  - Push notification: "Your photos are ready!" (if implemented)
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Processing message | "Developing in X" | Keep — "developing" fits the disposable camera metaphor |
| Processing state | Just an alert on tap | **Consider: show a developing animation on the event card** — film being processed |
| Reveal notification | Basic push (if implemented) | **Critical for retention** — must ship with push notification |
| Event card during processing | Hourglass icon | Could show a **film canister / developing tray** icon |

### Recommended State Display on Event Cards

```
UPCOMING:    📅 "Starts in 3 hours"     → tap shows alert
LIVE:        📷 "Live — 7 shots left"   → tap opens camera
PROCESSING:  ⏳ "Developing..."         → tap shows countdown
REVEALED:    ✨ "Ready to reveal"       → tap opens reveal
COMPLETED:   📸 "48 photos"             → tap opens gallery
```

### Key Addition for Pivot

The event card for a LIVE event should show the user's remaining shot count. This reinforces the 10-shot mechanic even from the home screen.

```
┌─────────────────────────────────┐
│  🟢 LIVE                        │
│  Asad's Birthday                │
│  📷 7 shots left · 12 guests    │
│                                 │
└─────────────────────────────────┘
```

---

## 8. Photo Reveal Experience

### Current Flow

```
Tap revealed event → FeedRevealView (full-screen cover)

Phase 1: Pre-Reveal
  - Dark screen with purple glow
  - Title: "Photos"
  - Subtitle: event name
  - Timestamp: "Revealed together at [time]"
  - Center: "Reveal" button (large, white)

Phase 2: Viewing (after tapping "Reveal")
  - Header: "X of Y photos" + heart count
  - Vertical scroll feed (paged, one photo per screen)
  - Each photo is a RevealCardView:
      Unrevealed state:
        - Grainy dark overlay
        - "Tap to reveal" with hand icon
      Revealed state:
        - Overlay fades out (0.3s)
        - Photo visible
        - 2-second delay
        - Action bar fades in: [❤️ Like] [⬆️ Share]
        - Photo info: date + "by @username"
  - Pagination: 10 photos loaded at a time, prefetch 3 from end
  - Scroll locked until current photo's action buttons appear

Phase 3: Complete (after scrolling past last photo)
  - Sparkle icon
  - "That was the night."
  - Stats: "X photos liked"
  - Button: "View Liked Photos"
  - Transitions to LikedGalleryView

LikedGalleryView:
  - Segmented toggle: Liked / All
  - 3-column photo grid
  - Tap photo → GalleryDetailView (full-screen, save/share)
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Pre-reveal screen | "Photos" title, technical timestamp | Update copy to feel more like **opening a developed roll** |
| Photo count | "X of Y photos" | Keep — gives sense of progress |
| Reveal mechanic | Tap each photo individually | Consider: keep individual taps but **faster pace** — 2-second button delay may be too slow for 50-150 photos |
| Photo attribution | "by @username" | Keep — important for the "who took what" curiosity |
| Completion screen | "That was the night." | Good copy — keep it |
| Liked photos | Heart icon, count tracked | Keep — drives the "pick your favourites" behaviour |
| Button delay | 2 seconds before like/share appear | **Reduce to 1 second** for better pacing at higher photo counts |

### Recommended Flow (Pivot)

```
Tap revealed event
  → Pre-Reveal Screen
      "[Event Name]"
      "XX photos from the night"
      "Taken by X people"
      [Open] button (or "Develop" / "Reveal" — test the copy)

  → Reveal Feed
      Vertical scroll, one photo per screen
      Each photo: tap to reveal → photo fades in → 1s delay → like/share buttons
      Photo info: date + "by @username"
      Progress: "12 of 48"

  → Completion Screen
      "That was the night."
      "You liked X photos"
      [View Gallery]

  → LikedGalleryView
      Liked / All toggle
      Grid browse
      Tap → full screen → save/share
```

### Key Consideration

With the pivot to 10 shots and 5-15 people, the reveal will typically contain **50-150 photos**. The current tap-to-reveal mechanic works at this scale, but:

- At 150 photos with 2-second delays, the reveal takes **5+ minutes minimum**
- Users should be able to **speed through** if they want — the 2-second lock on scroll should be reduced or made skippable after the first few photos
- Consider: after revealing 10-20 photos, let the user **scroll freely** without tap-to-reveal on each one (auto-reveal on scroll into view)

---

## 9. Downloading & Sharing Photos

### Current Flow

```
From Reveal (RevealCardView):
  - Share button on each revealed photo
  - Opens UIActivityViewController
  - No watermark on shared image

From Gallery (GalleryDetailView):
  - Save button: downloads to camera roll
      - Requests photo library permission (.addOnly)
      - Success/failure alert
  - Share button: opens share sheet
  - No watermark

From Gallery toolbar:
  - Link button: generates web album URL
      Format: https://yourmomento.app/album/{joinCode}
```

### What Needs to Change for Pivot

| Element | Current | Pivot Change |
|---------|---------|--------------|
| Watermark | None | **Not now** — first 100 users are friends. Add later. |
| Download | Free, unlimited | Keep free for now. Gate later with 30-day retention. |
| Share | Standard share sheet | Keep — this is the viral moment |
| Batch download | Not available | **Future: "Save All" or "Save Liked"** would be valuable |
| Web album link | UI exists, backend unclear | Needs to work — this is a key viral/sharing tool |

### Recommended Flow (Pivot)

No major changes needed now. The sharing flow is solid. Future additions:

```
Post-Reveal Gallery:
  - "Save All Liked" button (batch download to camera roll)
  - Share to Instagram Stories (pre-formatted collage?)
  - Web album link prominent in gallery toolbar
```

---

## 10. Web Album Experience

### Current State

```
- Web album URL format exists: https://yourmomento.app/album/{joinCode}
- ShareLink in gallery toolbar generates this URL
- Backend/web implementation status: unclear from codebase
- Mentioned in vision doc as existing feature for viral loop
```

### Recommended Flow (Pivot)

```
Web Album URL shared (via text, social, etc.)
  → Browser opens https://yourmomento.app/album/{joinCode}
  → Landing page:

  ┌──────────────────────────────────────┐
  │  📸 Momento                          │
  │                                      │
  │  [Event Name]                        │
  │  [Date] · [X photos] · [X people]   │
  │                                      │
  │  ┌────┐ ┌────┐ ┌────┐               │
  │  │    │ │    │ │    │               │
  │  │ 📷 │ │ 📷 │ │ 📷 │  (photo grid) │
  │  │    │ │    │ │    │               │
  │  └────┘ └────┘ └────┘               │
  │  ┌────┐ ┌────┐ ┌────┐               │
  │  │    │ │    │ │    │               │
  │  │ 📷 │ │ 📷 │ │ 📷 │               │
  │  │    │ │    │ │    │               │
  │  └────┘ └────┘ └────┘               │
  │                                      │
  │  ┌──────────────────────────────┐    │
  │  │ 📲 Get Momento for next time │    │
  │  └──────────────────────────────┘    │
  │                                      │
  │  App Store link / Smart banner       │
  └──────────────────────────────────────┘

Key features:
  - View-only (no account required)
  - Photo grid with tap-to-enlarge
  - Download individual photos
  - CTA: "Get Momento for your next party" → App Store
  - No editing, no liking, no social features
  - Photos attributed: "by @username"
```

### Viral Purpose

The web album serves two goals:
1. **Guests who didn't download the app** can still see the photos (reduces friction)
2. **CTA converts viewers to future app users** (guest → host pipeline)

---

## 11. Edge Cases

### Late Joiners

| Scenario | Current Behaviour | Recommended |
|----------|-------------------|-------------|
| Join after event started (LIVE) | Can join, gets full photo limit | **Correct — still gets 10 shots** (per vision doc) |
| Join during PROCESSING | Can join, but can't take photos | Should still be able to join and see the reveal |
| Join after REVEALED | Can join and see all photos | Allow — they missed the fun but can browse |

### Leaving / Removing

| Scenario | Current Behaviour | Recommended |
|----------|-------------------|-------------|
| User closes app mid-event | Photos queue offline, upload on return | No change — works well |
| User deletes app | Photos in queue are lost | Accept this — offline queue is best-effort |
| User wants to leave event | No leave mechanism exists | **Not needed for v1** — events are temporary anyway |

### Photo Upload Failures

| Scenario | Current Behaviour | Recommended |
|----------|-------------------|-------------|
| Upload fails | Retries up to 3 times, marks as failed | No change |
| Manual retry | Available via OfflineSyncManager | Should surface retry UI somewhere if there are failed uploads |
| Network offline all night | Photos queue locally, upload on reconnect | No change — works well |
| Photo exceeds limit on server | Marked complete, local file deleted | With 10-shot limit, counter should prevent this. Server check is a safety net. |

### Timing Edge Cases

| Scenario | Current Behaviour | Recommended |
|----------|-------------------|-------------|
| Taking photo at exact end time | Race condition possible | Accept — 12-hour window is generous enough |
| Event created in past | Date picker allows it | **Prevent: minimum start time = now** |
| Multiple live events | All show as live, user can switch | Works fine — each event has its own shot counter |

### Account Edge Cases

| Scenario | Current Behaviour | Recommended |
|----------|-------------------|-------------|
| Same user joins twice | Returns existing membership, no error | Correct |
| User signs out mid-event | Clears queue (photos may be lost) | **Consider: warn user if pending uploads exist** |
| Username change | Not implemented | Not needed for v1 |

---

## 12. Screen Inventory

### Current Screens (23 total)

| # | Screen | File | Entry Point |
|---|--------|------|-------------|
| 1 | Auth Loading | AuthenticationRootView.swift | App launch |
| 2 | Sign In | SignInView.swift | No session |
| 3 | Username Selection | UsernameSelectionView.swift | Post-auth |
| 4 | Onboarding 1 (Hook) | OnboardingView.swift | Post-username |
| 5 | Onboarding 2 (Mechanic) | OnboardingView.swift | Swipe/next |
| 6 | Onboarding 3 (Payoff) | OnboardingView.swift | Swipe/next |
| 7 | Onboarding Action | OnboardingActionView.swift | Post-onboarding |
| 8 | Event List (Home) | ContentView.swift | Authenticated |
| 9 | Create Step 1 (Name) | CreateStep1NameView.swift | Tap "+" |
| 10 | Create Step 2 (Config) | CreateStep2ConfigureView.swift | Next |
| 11 | Create Step 3 (Share) | CreateStep3ShareView.swift | Next |
| 12 | Join - QR Scan | JoinEventSheet.swift | QR icon |
| 13 | Join - Code Entry | JoinEventSheet.swift | Switch mode |
| 14 | Event Preview | EventPreviewModal.swift | Code/QR found |
| 15 | Camera | CameraView.swift | Tap live event |
| 16 | Reveal - Pre | FeedRevealView.swift | Tap revealed event |
| 17 | Reveal - Viewing | FeedRevealView.swift | Tap "Reveal" |
| 18 | Reveal - Complete | FeedRevealView.swift | Scroll to end |
| 19 | Gallery (Liked/All) | LikedGalleryView.swift | Post-reveal |
| 20 | Photo Detail | GalleryDetailView.swift | Tap thumbnail |
| 21 | Photo Full Screen | FullScreenPhotoView.swift | Tap in grid |
| 22 | Profile/Settings | ProfileView.swift | Gear icon |
| 23 | Invite Sheet | InviteSheet.swift | Long-press event |

### Screens Needed for Pivot (Changes Only)

| Screen | Change Type | Description |
|--------|-------------|-------------|
| Onboarding 2 | **Update copy** | Emphasise 10 shots, not time windows |
| Create Step 2 | **Update copy** | Show "10 shots each" prominently |
| Event Preview | **Update copy** | Add "You'll get 10 shots" |
| Camera | **Config change** | Limit 12 → 10 |
| Camera | **New overlay** | "That's a wrap" message when shots run out |
| Event Card | **Update** | Show remaining shots when live |

No new screens required for the pivot. The changes are mostly copy updates and one config value.

---

## 13. Disposable Camera Feel — Suggestions

### Already Working Well

These existing elements nail the disposable camera vibe:

- **No photo preview after capture** — you don't know what you got
- **Film counter with rolling animation** — feels like advancing film
- **Shutter flash effect** — mimics a real flash going off
- **"Saved!" indicator** — brief confirmation, then gone
- **Photos locked until reveal** — like waiting for film to develop
- **Disposable camera filter** (Bethan Reynolds) — applied to all photos
- **"Developing..." processing state** — perfect metaphor

### Suggestions to Enhance

#### 1. Viewfinder Aesthetic
Add a subtle viewfinder frame overlay on the camera preview — thin rounded rectangle with slight vignette at edges. Disposable cameras had a visible viewfinder border. Keep it minimal so it doesn't obstruct the photo.

#### 2. Shutter Sound
Add an optional mechanical shutter click sound — the satisfying "ka-chunk" of a disposable camera. Should be toggleable (respect silent mode) but on by default. This is a huge sensory anchor.

#### 3. Film Advance Animation
After capture, add a brief "film advance" animation — the counter rolling down could be accompanied by a subtle horizontal shift of the viewfinder image, like film physically advancing. Very brief (0.2s).

#### 4. Last Shot Moment
When the user takes their **last shot (#10)**, make it feel special:
- Slightly longer flash
- Different haptic (celebration pattern?)
- Counter rolls to 0 with a final "click"
- "That's a wrap" message
- This is an emotional beat — the roll is done

#### 5. Rewind Animation on Event End
When the event transitions from LIVE to PROCESSING, the event card could show a brief **film rewind** animation — reinforcing that the roll is being sent for developing.

#### 6. "Developing" State Visual
During PROCESSING, the event card could show a subtle **darkroom red tint** or a developing tray animation. The film is being processed — make it feel tangible.

#### 7. Reveal as "Opening the Envelope"
The pre-reveal screen currently has a generic "Reveal" button. Consider making it feel like **tearing open a photo envelope** — a swipe-up gesture that "opens" the photos, rather than a button tap.

#### 8. Photo Date Stamp
Photos already show a date in monospaced orange font (like a disposable camera timestamp). This is great. Consider making it slightly more prominent or adding the shot number: "Shot 7 of 10 · 11:47 PM".

#### 9. No Zoom During Capture
Disposable cameras don't have zoom. Consider **removing the 0.5x/1.0x zoom toggle** to enforce the constraint. What you see is what you get. This is a strong opinion — could alienate some users but would reinforce authenticity.

#### 10. Flash Always On (or Auto)
Disposable cameras had a flash that was either always on or required manual charge. Consider defaulting flash to **auto** and removing the off option, or making flash behaviour feel more "disposable" — always firing in low light, with the characteristic blown-out look.

---

## Summary of Pivot Changes Required

### Code Changes (Minimal)

| Change | File | Effort |
|--------|------|--------|
| Photo limit 12 → 10 | `PhotoLimitConfig` / `CameraView` | Trivial |
| Onboarding copy update | `OnboardingView.swift` | Small |
| Create flow copy update | `CreateStep2ConfigureView.swift` | Small |
| Event preview copy update | `EventPreviewModal.swift` | Small |
| Suggested event names | `CreateStep1NameView.swift` | Trivial |
| Shot counter on event card (LIVE) | `ContentView.swift` | Small |
| "That's a wrap" overlay | `CameraView.swift` | Medium |
| Invite message update | `CreateStep3ShareView.swift` | Trivial |

### UX Enhancements (Post-Pivot Polish)

| Enhancement | Effort | Impact |
|-------------|--------|--------|
| Shutter sound effect | Small | High — sensory anchor |
| Last-shot celebration | Small | Medium — emotional beat |
| Reduce reveal button delay 2s → 1s | Trivial | Medium — better pacing |
| Auto-reveal on scroll (after first 10-20) | Medium | High — prevents fatigue at 100+ photos |
| "Developing" card animation | Medium | Medium — atmosphere |
| Batch "Save All Liked" | Medium | High — utility |
| Push notification for reveal | Medium | Critical — retention |

---

*This document maps the full UX as it exists today and what needs to change for the 10-shot pivot. The pivot requires surprisingly few code changes — mostly copy updates and one config value. The disposable camera feel is already strong; the enhancements above would take it from good to iconic.*
