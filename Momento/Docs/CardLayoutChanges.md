# Event Card Layout Changes

## Layout Update

### Before
```
┌─────────────────────────────────────┐
│  [Circle]  Event Title              │
│            Subtitle                 │
│            [Badges]                 │
└─────────────────────────────────────┘
```

### After (Current)
```
┌─────────────────────────────────────┐
│  Event Title              [Circle]  │
│  Subtitle                           │
│  [Badges]                           │
└─────────────────────────────────────┘
```

**Why this is better:**
- Title is first thing you see (left-aligned, natural reading order)
- State indicator on right draws eye after reading title
- More balanced visual weight
- Feels more premium and polished

---

## Countdown Subtitle Improvements

### Before
- Always showed "Releases soon" regardless of time

### After (Dynamic)
- **Days away**: "Starts in 2 days", "Starts in 1 day"
- **Hours away**: "Starts in 12 hours", "Starts in 1 hour"
- **Minutes away**: "Starts in 45 minutes"
- **Very soon**: "Starting soon" (< 1 minute)

**Examples:**
- 36 hours → "Starts in 1 day"
- 12 hours → "Starts in 12 hours"
- 90 minutes → "Starts in 1 hour"
- 45 minutes → "Starts in 45 minutes"
- 30 seconds → "Starting soon"

**Why this is better:**
- More informative and accurate
- Builds anticipation
- Professional feel
- Updates in real-time as countdown progresses

---

## Visual Hierarchy

### Left Side (Primary)
1. **Event Title** - Largest, most prominent
2. **Subtitle** - Context about state
3. **Metadata Badges** - Supporting info

### Right Side (Secondary)
- **State Indicator** - Visual at-a-glance status
  - Countdown: Progress ring
  - Live: Pulsing camera
  - Revealed: Gallery icon

This creates a natural left-to-right reading flow:
**"What is it?"** → **"What's the status?"**

---

## State-Specific Subtitles

### Countdown State
- Dynamic time-based message
- Clock icon
- White 60% opacity
- Updates every second

### Live State
- "Live now - Tap to capture"
- Pulsing purple dot
- Royal purple color
- Clear call-to-action

### Revealed State
- "Photos revealed"
- Checkmark icon
- White 60% opacity
- Completion indicator

---

## Design Rationale

### Why Right-Aligned Circle?
1. **Natural reading flow**: Title first, then status
2. **Visual balance**: Text on left, icon on right
3. **Premium feel**: More sophisticated layout
4. **Thumb-friendly**: Right side easier to tap on right-handed use
5. **Consistency**: Matches iOS design patterns (e.g., Settings app)

### Why Dynamic Countdown?
1. **Informative**: Users know exactly when event starts
2. **Anticipation**: Builds excitement as time gets closer
3. **Professional**: Shows attention to detail
4. **Useful**: Helps users plan when to check back
5. **Real-time**: Updates every second for accuracy

---

## Implementation Details

### Layout Change
```swift
HStack(alignment: .center, spacing: 16) {
    // Left: Event info
    VStack(alignment: .leading, spacing: 8) {
        Text(event.title)
        stateSubtitle
        HStack { /* badges */ }
    }
    
    Spacer()
    
    // Right: State indicator
    stateIndicator
        .frame(width: 72, height: 72)
}
```

### Dynamic Subtitle
```swift
private var countdownSubtitle: String {
    let hours = remainingSeconds / 3600
    if hours >= 24 {
        let days = hours / 24
        return days == 1 ? "Starts in 1 day" : "Starts in \(days) days"
    } else if hours > 0 {
        return hours == 1 ? "Starts in 1 hour" : "Starts in \(hours) hours"
    } else {
        let minutes = remainingSeconds / 60
        return minutes <= 1 ? "Starting soon" : "Starts in \(minutes) minutes"
    }
}
```

---

## User Feedback

> "I like it especially the live ones it makes them feel more premium, maybe the circles could be on the right side instead of left side"

✅ **Implemented**: Circles now on right side

> "for the joe 26th one it says releases soon but it should say something else"

✅ **Implemented**: Dynamic countdown messages based on actual time remaining

---

## Testing Checklist

- [x] Circle appears on right side
- [x] Title is left-aligned
- [x] Countdown shows correct time units
- [x] "Starts in X days" for 24+ hours
- [x] "Starts in X hours" for 1-23 hours
- [x] "Starts in X minutes" for 2-59 minutes
- [x] "Starting soon" for < 2 minutes
- [x] Live state still shows pulsing camera
- [x] Revealed state shows gallery icon
- [x] All states look balanced
- [x] Touch targets still work correctly

