# User Profile & Keepsakes Design

**Date:** 2026-01-25
**Status:** Approved

---

## Overview

Transform the settings screen from a simple username display into a personal memory vault. The profile is a private space for users to reflect on their Momento journey - not social media, not gamification, just meaningful memories.

### Core Principles

- Memory-keeping, not gamification
- Warm language ("moments captured" not "photos taken")
- Keepsakes are rare surprises, not achievements to grind
- Consistent with existing dark theme + purple glow aesthetic
- Card-based layout matching current UI patterns

---

## Screen Structure

Single scrollable screen, top to bottom:

```
┌─────────────────────────────┐
│  ✨ @username               │
│     User #47                │
├─────────────────────────────┤
│  STATS                      │
│  ┌───────┐ ┌───────┐        │
│  │ 42    │ │ 18    │        │
│  │moments│ │photos │        │
│  │captured│ │loved  │       │
│  └───────┘ └───────┘        │
│  ... (8 stats total)        │
├─────────────────────────────┤
│  KEEPSAKES                  │
│  ┌──┐ ┌──┐ ┌──┐             │
│  │🏔️│ │🎭│ │🚢│             │
│  └──┘ └──┘ └──┘             │
│  (hidden if none)           │
├─────────────────────────────┤
│  [Sign Out]                 │
└─────────────────────────────┘
```

---

## Header

- **Username** with existing purple glow effect
- **User #** displayed beneath (e.g., "User #47")
  - Calculated by counting profiles created before user's `created_at`
  - Part of identity, not a stat

---

## Stats

8 stats displayed in cards with warm, nostalgic copy. Grid layout (2 columns).

### Activity Stats (Core 4)

| Display Copy | Data Source |
|--------------|-------------|
| "Moments captured" | `COUNT(*) FROM photos WHERE user_id = ?` |
| "Photos loved" | `COUNT(*) FROM photo_interactions WHERE user_id = ? AND status = 'liked'` |
| "Reveals completed" | `COUNT(*) FROM user_reveal_progress WHERE user_id = ? AND completed = true` |
| "Momentos shared" | `COUNT(*) FROM event_members WHERE user_id = ?` |

### Journey Stats (4)

| Display Copy | Data Source |
|--------------|-------------|
| "First Momento" | `MIN(joined_at) FROM event_members WHERE user_id = ?` (display as date) |
| "Friends captured with" | Count distinct users who share events with this user |
| "Most active Momento" | Event title where user took the most photos |
| "Most recent Momento" | Event title with most recent `joined_at` |

### Implementation Notes

All queries are simple - no new tables needed for stats. Consider caching or computing on profile load.

---

## Keepsakes

Rare, manually-granted digital collectibles that commemorate special moments.

### What is a Keepsake?

- Digital collectible tied to a specific event or milestone
- Manually granted (not automatic achievements)
- "NFT without the bullshit" - provenance and ownership without crypto
- Future B2B2C potential: branded keepsakes for event companies (digital wristbands)

### Keepsake Data Model

Each keepsake contains:

| Field | Description |
|-------|-------------|
| `id` | Unique identifier |
| `name` | Display name (e.g., "Sopranos") |
| `artwork_url` | Visual badge/design |
| `flavour_text` | Story behind the keepsake |
| `event_id` | Optional - tied to specific event |
| `created_at` | When keepsake was created |

User-keepsake relationship:

| Field | Description |
|-------|-------------|
| `user_id` | User who earned it |
| `keepsake_id` | The keepsake |
| `earned_at` | When they earned it |

### Rarity Calculation

"X% of users have this" = `(users with keepsake / total users) * 100`

### Initial Keepsakes

| Name | Flavour Text | Who Gets It |
|------|--------------|-------------|
| Lakes | "Some moments are worth waiting 3 years for." | Lake District reunion crew (pre-beta test) |
| Sopranos | "Made member of the first family." | First beta event attendees |
| Hijack x DoubleDip | "On board from the start. London." | Boat party attendees |

### Profile Display

- Grid of keepsake artwork below stats section
- Tap keepsake to expand modal with full details:
  - Artwork (large)
  - Name
  - Flavour text
  - Rarity percentage
- **Section hidden entirely if user has no keepsakes** (preserves surprise)

---

## Keepsake Reveal Experience

When a user earns a keepsake, it should feel like a special moment.

### Trigger

After completing a reveal for an event that grants a keepsake.

### Flow

1. User finishes tapping through photos (existing confetti animation plays)
2. Full screen takeover begins
3. Keepsake flip animation (same mechanic as photo reveals - familiar interaction)
4. Artwork flips into view
5. Name appears below artwork
6. Flavour text fades in
7. Rarity displays ("0.3% of users have this")
8. "View on profile" button at bottom
9. Tap anywhere or button to dismiss, return to event

### Why Flip Animation?

Users are already in the "tap to reveal" flow from photos. Same muscle memory, feels cohesive with the reveal experience.

---

## Database Changes

### New Tables

```sql
-- Keepsake definitions
CREATE TABLE keepsakes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    artwork_url TEXT NOT NULL,
    flavour_text TEXT NOT NULL,
    event_id UUID REFERENCES events(id), -- optional, for event-specific keepsakes
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User-keepsake relationship
CREATE TABLE user_keepsakes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    keepsake_id UUID NOT NULL REFERENCES keepsakes(id),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, keepsake_id)
);

-- Indexes
CREATE INDEX idx_user_keepsakes_user_id ON user_keepsakes(user_id);
CREATE INDEX idx_keepsakes_event_id ON keepsakes(event_id);
```

### RLS Policies

```sql
-- Users can view all keepsakes (to see rarity)
CREATE POLICY "Anyone can view keepsakes"
    ON keepsakes FOR SELECT
    USING (true);

-- Users can only view their own earned keepsakes
CREATE POLICY "Users can view own earned keepsakes"
    ON user_keepsakes FOR SELECT
    USING (auth.uid() = user_id);

-- Only admins/service role can grant keepsakes
CREATE POLICY "Service role can insert keepsakes"
    ON user_keepsakes FOR INSERT
    WITH CHECK (false); -- Handled via service role or admin function
```

---

## UI Components

### New Components

1. **ProfileView** - Redesigned settings/profile screen
2. **StatsGridView** - 2-column grid of stat cards
3. **StatCardView** - Individual stat card (number + warm copy)
4. **KeepsakeGridView** - Grid of keepsake artwork thumbnails
5. **KeepsakeDetailModal** - Full keepsake details on tap
6. **KeepsakeRevealView** - Full-screen keepsake reveal animation

### Modified Components

1. **RevealView** - Add keepsake check after reveal completion
2. **SettingsView** - Rename/replace with ProfileView

---

## Future Considerations

### Brand Partnerships (B2B2C)

- Event companies (like Hijack) can have branded keepsakes
- Each event gets its own unique keepsake
- Potential revenue stream: charge brands for custom keepsakes
- Digital wristband concept - "I was there"

### Seasonal Keepsakes

- NYE, summer events, etc.
- Still manually granted, but themed

### Keepsake Artwork

- Need design assets for each keepsake
- Consider consistent style/frame with unique interiors
- Should look good at small (grid) and large (modal) sizes

---

## Out of Scope

- Public profiles / social features
- Automatic achievement badges
- Trading or transferring keepsakes
- Avatar/profile photo (keep minimal for now)
- Push notifications for keepsakes
