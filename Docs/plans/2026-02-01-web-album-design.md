# Momento: Web Album Design

**Date:** 2026-02-01
**Status:** Draft
**Test Event:** Sopranos Party

---

## Overview

A shareable web album that lets non-app users view photos from a Momento event. Solves the problem of sharing photos with people who attended but don't have the app.

**URL:** `yourmomento.app/album/[joinCode]`

**Purpose:**
- Gift to non-app attendees (they can see and download photos)
- Growth tool (CTA to download the app)
- Premium feature (gated behind upgrade, once RevenueCat is integrated)

---

## Design Rules

- **No emojis** — Clean typography, no emoji decorations in either product
- **Mobile-first** — Most users receive links via phone (WhatsApp, iMessage)
- **Gift first, growth second** — The album is valuable on its own, CTA is subtle

---

## URL Structure & Routing

**Route:** `yourmomento.app/album/[joinCode]`

**Example:** `yourmomento.app/album/ABC123`

**File structure:**

```
/pages
  /album
    /[code].js              → Album page component
/pages/api
  /album
    /[code].js              → Fetch event + first 10 photos
    /[code]/photos.js       → Paginated photo fetching
```

**Flow:**

1. User visits `/album/ABC123`
2. Page calls `/api/album/ABC123` for event details + first 10 photos
3. As user scrolls, page calls `/api/album/ABC123/photos?offset=10` for more
4. Each API response includes signed URLs (valid 7 days)

---

## API Response Structure

### GET `/api/album/[code]` — Initial load

```json
{
  "event": {
    "title": "Sopranos Party",
    "date": "2026-01-25",
    "photoCount": 47,
    "contributorCount": 11
  },
  "photos": [
    {
      "id": "uuid",
      "url": "https://signed-url...",
      "capturedAt": "2026-01-25T22:34:00Z",
      "username": "asad"
    }
  ],
  "hasMore": true,
  "nextOffset": 10
}
```

### GET `/api/album/[code]/photos?offset=10` — Pagination

```json
{
  "photos": [...],
  "hasMore": true,
  "nextOffset": 20
}
```

**Notes:**

- `contributorCount` = distinct user count from photos
- `username` displayed as `@asad` in UI
- Photos ordered by `captured_at` ascending (chronological)
- No internal IDs or user data exposed

---

## Page Layout

### Album Header

```
┌─────────────────────────────────┐
│                                 │
│      Sopranos Party             │
│      25 January 2026            │
│                                 │
│      47 photos · 11 people      │
│                                 │
└─────────────────────────────────┘
```

- Title is the visual anchor (no emoji)
- Date formatted readable (25 January 2026)
- Stats show social proof

### Photo Grid

```
┌───────┐ ┌───────┐ ┌───────┐
│       │ │       │ │       │
│  📷   │ │  📷   │ │  📷   │
│       │ │       │ │       │
└───────┘ └───────┘ └───────┘
```

- 3-column grid
- Square thumbnails (center cropped)
- Infinite scroll (loads 10 more as user scrolls)
- Tap any photo → opens lightbox

### Footer

```
┌─────────────────────────────────┐
│       Made with Momento         │
└─────────────────────────────────┘
```

- Subtle, not pushy
- Links to App Store

---

## Lightbox Experience

### Layout

```
┌─────────────────────────────────┐
│  ✕                          1/47│
├─────────────────────────────────┤
│                                 │
│         [ PHOTO ]               │
│                                 │
├─────────────────────────────────┤
│  @asad · 10:34pm                │
│                                 │
│  ┌─────────────────────────┐    │
│  │     ↓ Save photo        │    │
│  └─────────────────────────┘    │
└─────────────────────────────────┘
        ↕ scroll for more
```

### Behaviour

- Vertical scroll/swipe between photos
- `✕` closes lightbox, returns to grid
- `1/47` shows position
- `@username · time` below each photo
- "Save photo" triggers download

### Download CTA

After first download, show once per session:

```
┌─────────────────────────────────┐
│                                 │
│      Photo saved!               │
│                                 │
│   Want to host your own         │
│   Momento?                      │
│                                 │
│  ┌─────────────────────────┐    │
│  │      Get the app        │    │
│  └─────────────────────────┘    │
│                                 │
│        Maybe later              │
│                                 │
└─────────────────────────────────┘
```

- Appears once per session, not every download
- "Maybe later" dismisses without guilt
- "Get the app" → App Store link

---

## Error States

### Not found (invalid join code)

```
┌─────────────────────────────────┐
│                                 │
│      This album doesn't         │
│      exist                      │
│                                 │
│      The link might be wrong,   │
│      or the album was removed.  │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Create your own →     │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

### Not yet revealed

```
┌─────────────────────────────────┐
│                                 │
│      Sopranos Party             │
│                                 │
│      This album isn't           │
│      ready yet                  │
│                                 │
│      Photos reveal on           │
│      Sunday 26 Jan, 7pm         │
│                                 │
│  ┌─────────────────────────┐    │
│  │   Get the app to join → │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

### Empty album

```
┌─────────────────────────────────┐
│                                 │
│      Sopranos Party             │
│      25 January 2026            │
│                                 │
│      No photos were taken       │
│                                 │
└─────────────────────────────────┘
```

### Loading state

- Skeleton grid (grey boxes pulsing)
- Dark aesthetic matching landing page
- Shows immediately while API fetches

---

## Supabase Integration

### Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # Server-side only
```

### Server-side Client

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
)
```

### Queries

**1. Lookup event by join code:**

```javascript
const { data: event } = await supabase
  .rpc('lookup_event_by_code', { code: joinCode.toUpperCase() })
```

**2. Check if revealed:**

```javascript
if (new Date(event.release_at) > new Date()) {
  return { notReady: true, revealDate: event.release_at }
}
```

**3. Get photos (paginated):**

```javascript
const { data: photos } = await supabase
  .from('photos')
  .select('id, storage_path, captured_at, captured_by_username')
  .eq('event_id', event.id)
  .order('captured_at', { ascending: true })
  .range(offset, offset + 9)
```

**4. Generate signed URLs:**

```javascript
const signedPhotos = await Promise.all(
  photos.map(async (photo) => {
    const { data } = await supabase.storage
      .from('momento-photos')
      .createSignedUrl(photo.storage_path, 60 * 60 * 24 * 7)
    return { ...photo, url: data.signedUrl }
  })
)
```

**5. Get contributor count:**

```javascript
const { count } = await supabase
  .from('photos')
  .select('user_id', { count: 'exact', head: true })
  .eq('event_id', event.id)
```

---

## Component Structure

```
/pages
  /album
    [code].js                → Main album page

/components
  /album
    AlbumHeader.js           → Title, date, stats
    PhotoGrid.js             → 3-column grid with infinite scroll
    Lightbox.js              → Fullscreen vertical scroll viewer
    PhotoCard.js             → Individual photo in lightbox
    DownloadCTA.js           → "Photo saved" prompt
    NotReady.js              → "Album reveals on [date]" state
    NotFound.js              → "Album doesn't exist" state

/lib
  supabase.js                → Server-side Supabase client
```

---

## Styling

Match the existing landing page:

- **CSS Modules** (already using)
- **Dark background** (#0a0a0f)
- **Newsreader font** for headings
- **Framer Motion** for transitions
- **Mobile-first**, works on desktop

### Animations

| Action | Animation |
|--------|-----------|
| Open lightbox | Fade in + scale from thumbnail |
| Close lightbox | Fade out |
| Scroll between photos | Vertical snap scroll |
| Download CTA appears | Slide up from bottom |
| Dismiss CTA | Fade out |

---

## Analytics

**Using Vercel Analytics (for now, PostHog later)**

| Event | When | Why |
|-------|------|-----|
| `album_viewed` | Page load | Total reach |
| `photo_viewed` | Lightbox opened | Engagement depth |
| `photo_downloaded` | Save tapped | Intent signal |
| `cta_shown` | Download CTA appears | Funnel tracking |
| `cta_clicked` | "Get the app" tapped | Conversion |
| `cta_dismissed` | "Maybe later" tapped | Measure friction |

**Event data:**

```javascript
{
  joinCode: "ABC123",
  photoCount: 47,
  contributorCount: 11,
  photoIndex: 5
}
```

---

## Access Control

**Current (for testing):** Any revealed event can be viewed via join code.

**Future (after RevenueCat):** Add `is_premium` or `has_web_album` flag to events table. API returns 403 if event is not premium.

```javascript
if (!event.is_premium) {
  return { error: 'Album not available', code: 403 }
}
```

---

## Implementation Priorities

### Phase 1: Core Album

1. Supabase client setup (`/lib/supabase.js`)
2. API route for event + photos (`/api/album/[code].js`)
3. Album page with header and grid (`/pages/album/[code].js`)
4. Basic styling matching landing page

### Phase 2: Lightbox

5. Lightbox component with vertical scroll
6. Photo card with `@username · time`
7. Pagination API (`/api/album/[code]/photos.js`)
8. Infinite scroll in grid

### Phase 3: Download & CTA

9. Download button (save to camera roll)
10. Download CTA modal (once per session)
11. App Store link integration

### Phase 4: Polish

12. Error states (not found, not ready, empty)
13. Loading skeletons
14. Framer Motion animations
15. Vercel Analytics events

---

## Test Plan

**Test event:** Sopranos Party (join code from existing event)

**Test scenarios:**

1. Load album page → shows header, grid, photos
2. Scroll to bottom → loads more photos
3. Tap photo → lightbox opens
4. Scroll in lightbox → moves between photos
5. Tap download → photo saves, CTA appears
6. Dismiss CTA → continues browsing, CTA doesn't reappear
7. Invalid join code → "doesn't exist" page
8. Event not revealed → "not ready" page with date

---

## Summary

| Decision | Choice |
|----------|--------|
| URL | `/album/[joinCode]` |
| Access | Join code is the key |
| Display | Title, date, photo count, contributor count |
| Grid | 3-column, square thumbnails |
| Lightbox | Vertical scroll, `@username · time` |
| Download | Direct save, CTA once per session |
| Backend | Next.js API + Supabase service role |
| Pagination | 10 photos at a time |
| Styling | Dark, Newsreader, Framer Motion |
| Analytics | Vercel Analytics (PostHog later) |
| Emojis | None |
