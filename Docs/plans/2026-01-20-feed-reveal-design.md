# Feed Reveal Redesign

**Date:** 2026-01-20
**Status:** Ready for implementation
**Context:** London beta feedback - reveal is the magic moment, needs to be intuitive and bug-free

---

## Problems to Solve

1. **Mirror bug:** Photos displayed horizontally flipped during reveal (correct in gallery after)
2. **Swipe UX:** Tinder-style horizontal swipes feel wrong for photo browsing
3. **Bandwidth:** No caching = repeated downloads, hitting Supabase egress limits
4. **Decision fatigue:** Forcing like/archive choice on every photo is exhausting

---

## New Design: Vertical Feed Reveal

### Core Experience

Replace the Tinder-style swipe stack with a vertical scrolling feed (like Instagram).

**Flow:**
1. User enters reveal screen after Momento event ends
2. Sees vertical feed of unrevealed photo cards
3. Taps a card to reveal the photo (fade/dissolve animation)
4. Action bar appears below with Like and Download buttons
5. Scrolls down to see more photos
6. Scrolling past without liking = implicit skip (no archive action needed)

### Card States

**Unrevealed:**
- Grainy film-texture placeholder hiding the actual photo
- Can be branded with Momento styling later
- No image download until revealed (saves bandwidth)

**Revealed:**
- Full photo visible at 4:3 aspect ratio (no cropping)
- Action bar below with:
  - Heart button (like/unlike toggle)
  - Download button (saves to camera roll)
- Photo stays revealed when scrolling away and back

### Visual Layout

```
┌─────────────────────────────┐
│  3 of 12          5 liked   │  ← Progress bar
├─────────────────────────────┤
│                             │
│   ┌─────────────────────┐   │
│   │                     │   │
│   │   [Grainy texture]  │   │  ← Unrevealed card
│   │    Tap to reveal    │   │
│   │                     │   │
│   └─────────────────────┘   │
│                             │
│   ┌─────────────────────┐   │
│   │                     │   │
│   │   [Actual photo]    │   │  ← Revealed card
│   │                     │   │
│   ├─────────────────────┤   │
│   │   ♡ Like    ↓ Save  │   │  ← Action bar
│   └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

### Animations

**Reveal (on tap):**
- Grainy overlay fades out: `opacity 1 → 0` over 0.3s
- Use `withAnimation(.easeOut(duration: 0.3))`
- Photo underneath is already loaded, just hidden

**Like:**
- Heart fills in / turns red
- Quick scale bounce (1.0 → 1.2 → 1.0)
- Haptic feedback (light)

### Progress Indicator

Top of screen shows:
- "X of Y" - current position / total photos
- "Z liked" - running count of liked photos

---

## Image Caching Strategy

### Problem

No caching = every scroll re-downloads images. 11 people × 200 photos × 200KB = 440MB per event, multiplied every time someone scrolls.

### Solution: Two-Tier Cache

**Tier 1: Memory Cache (NSCache)**
- Stores images while app is open
- Auto-clears on app close or memory pressure
- Zero disk footprint
- Solves: scrolling up/down re-downloads

**Tier 2: Bounded Disk Cache**
- Only current event's photos
- Hard cap: 100MB maximum
- Auto-cleanup rules:
  - Clear when event ends (48 hours post-reveal)
  - Clear past events immediately on leave
  - Oldest-first eviction if cap exceeded
- Solves: close/reopen app re-downloads

### Implementation

```swift
class ImageCacheManager {
    static let shared = ImageCacheManager()

    // Memory cache - auto-managed by system
    private let memoryCache = NSCache<NSString, UIImage>()

    // Disk cache - bounded to 100MB
    private let diskCacheLimit: Int = 100 * 1024 * 1024

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        // Check memory first
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            memoryCache.setObject(diskCached, forKey: key)
            return diskCached
        }

        // Download and cache
        guard let image = await downloadImage(url) else { return nil }
        memoryCache.setObject(image, forKey: key)
        saveToDisk(image, key: key)
        return image
    }
}
```

---

## Technical Implementation

### New Files

- `FeedRevealView.swift` - Main vertical scroll feed
- `RevealCardView.swift` - Individual card component (unrevealed/revealed states)
- `ImageCacheManager.swift` - Two-tier caching system

### Changes to Existing Files

- `SupabaseManager.swift` - No changes needed (same data model)
- `StackRevealView.swift` - Deprecate/remove after new view works
- Navigation to use `FeedRevealView` instead of `StackRevealView`

### Card State Model

```swift
struct RevealablePhoto: Identifiable {
    let id: String
    let imageURL: URL
    let timestamp: Date
    let photographerName: String?

    var isRevealed: Bool = false
    var isLiked: Bool = false
}
```

### Mirror Bug Fix

The mirror bug was in `StackRevealView`'s image rendering. New implementation will:
- Use standard `AsyncImage` or cached `Image(uiImage:)`
- Respect EXIF orientation data
- No transform modifiers that could flip the image
- Test with both front and back camera photos

---

## Data Flow

1. **Load:** Fetch photos from Supabase (existing `fetchEventPhotos`)
2. **Display:** Show in `LazyVStack` for performance
3. **Reveal:** On tap, set `isRevealed = true` (local state)
4. **Like:** On heart tap, toggle `isLiked` (local state)
5. **Save:** On completion or leave, batch sync liked status to Supabase
6. **Download:** On download tap, save full image to camera roll

---

## Future Considerations (Not This Build)

### Story Export
- Add "Share to Story" button
- Auto-crop to 9:16 from center
- Open iOS share sheet
- Track shares as metric

### 0.5x Ultra-Wide Camera
- Add lens switcher in camera view
- Popular request from London beta

### Dynamic Island
- Show photo count while capturing
- Event timer countdown

### Thumbnails for Galleries
- Generate 400px thumbnails on upload
- Use in grid views (Liked Gallery, Photo Gallery)
- Keep 1200px for reveal feed

---

## Success Criteria

- [ ] Photos display correctly (no mirroring)
- [ ] Vertical scroll feels natural
- [ ] Tap-to-reveal works with smooth fade animation
- [ ] Like/download buttons work correctly
- [ ] Progress indicator shows position and liked count
- [ ] Images cache properly (no re-downloads on scroll)
- [ ] Cache auto-clears (app stays slim)
- [ ] Bandwidth usage reduced by ~70%+
