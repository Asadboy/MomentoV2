# Event Card UI Rules

## Design Philosophy
The event card is the primary interface for Momento. It must be:
- **Descriptive** - User immediately knows the event state
- **Clean** - Premium look, like a £100k design budget
- **Intuitive** - Actions are discoverable but not overwhelming
- **Native** - Leverages iOS design patterns and animations

## Three Event States

### 1. Countdown State (Before Event Starts)
**Visual Identity:**
- Circular progress indicator showing time until release
- Purple accent color with subtle gradient background
- Compact time display (e.g., "12h 30m")
- Tap circle to expand to full time format (HH:MM:SS)

**User Actions:**
- Tap card: No action (event not started)
- Long press: Show invite/share options
- Tap circle: Toggle between compact and expanded time

**Metadata Shown:**
- Event title (with optional emoji in title)
- Member count
- "Releases soon" subtitle with clock icon

---

### 2. Live State (Event Active)
**Visual Identity:**
- Animated camera icon with pulsing background
- Purple border glow to indicate active state
- Photo counter badge on camera icon (e.g., "5")
- "Live now - Tap to capture" subtitle with live dot

**User Actions:**
- Tap card: Open camera for photo capture
- Long press: Show invite/share options
- Camera opens with haptic feedback

**Metadata Shown:**
- Event title
- Member count
- Photo count (both in badge and metadata)
- Live indicator dot (pulsing purple)

**Animations:**
- Camera icon background pulses (scale 1.0 → 1.1)
- Border has subtle glow effect
- Live dot pulses

---

### 3. Revealed State (24h After Release)
**Visual Identity:**
- Gallery/photo stack icon
- White/neutral color scheme (not purple)
- Photo count displayed
- "Photos revealed" subtitle with checkmark

**User Actions:**
- Tap card: Open gallery view with revealed photos
- Long press: Show share/export options

**Metadata Shown:**
- Event title
- Member count
- Total photo count
- Checkmark indicating completion

**Gallery View:**
- Photos shown at 30% opacity initially (greyed out)
- Tap photo to reveal at full opacity
- Grid layout for multiple photos
- Premium reveal animation (to be designed later)

---

## Card Layout Specifications

### Dimensions
- Card height: Auto (based on content)
- Card padding: 20pt all sides
- Corner radius: 20pt
- Spacing between cards: 16pt

### Typography
- Title: SF Pro, 20pt, Semibold, White
- Subtitle: SF Pro, 13pt, Medium, White 60% / Purple (live)
- Metadata: SF Pro, 12pt, Semibold

### Colors
- Royal Purple: RGB(128, 0, 204) / `Color(red: 0.5, green: 0.0, blue: 0.8)`
- Card Background: RGB(31, 26, 41) / `Color(red: 0.12, green: 0.1, blue: 0.16)`
- Text Primary: White
- Text Secondary: White 60%

### Shadows
- Primary: Black 30%, radius 16, y-offset 8
- Secondary: Black 20%, radius 4, y-offset 2

### State Indicator (Left Side)
- Size: 72x72pt
- Circle with gradient background
- Icon size: 28pt (camera, gallery) or progress ring (countdown)
- Progress ring: 3pt stroke, rounded caps

---

## Interaction Patterns

### Tap Gesture
- **Countdown**: No action (or show event details)
- **Live**: Open camera
- **Revealed**: Open gallery

### Long Press Gesture (0.5s)
- Triggers haptic feedback (medium impact)
- Shows invite/share sheet
- Available in all states

### Context Menu (Right-click / Long press alternative)
- Debug option: "View Debug Photos"
- Production: Share, Edit, Delete options

---

## Future Enhancements

### Dynamic Island Integration (Phase 2)
- Show live photo counter in Dynamic Island
- Quick camera access from Dynamic Island
- Countdown timer in Dynamic Island for upcoming events

### Animations
- Card entrance: Slide up with fade
- State transitions: Smooth cross-fade
- Camera button: Pulse animation (1.5s cycle)
- Countdown ring: Smooth progress animation

### Accessibility
- VoiceOver labels for all states
- High contrast mode support
- Reduced motion alternatives for animations

---

## Implementation Notes

### Component Structure
```
PremiumEventCard
├── State Indicator (Left)
│   ├── Countdown: CircularProgress + Time
│   ├── Live: AnimatedCamera + Counter
│   └── Revealed: GalleryIcon + Count
├── Event Info (Right)
│   ├── Title
│   ├── State Subtitle
│   └── Metadata Badges
└── Gestures
    ├── Tap
    ├── Long Press
    └── Context Menu
```

### State Logic
- Countdown: `now < releaseAt`
- Live: `now >= releaseAt && now < releaseAt + 24h`
- Revealed: `now >= releaseAt + 24h`

### Performance
- Animations use `.animation()` modifier with spring curves
- Timer updates every 1 second for countdown
- Camera scale animation repeats forever (autoreverses)
- Lazy loading for large event lists

---

## Design References
- Instagram: Clean card layouts, subtle shadows
- Snapchat: Live indicators, quick actions
- BeReal: Time-based UI, urgency indicators
- Dispo: Disposable camera aesthetic, reveal mechanics

