# Join Event Redesign

**Date:** 2026-01-24
**Status:** Ready for implementation

---

## Problem Statement

The current join flow has UX issues:
1. Three tabs (QR, Code, Link) is overcomplicated - Code and Link do the same thing
2. No success feedback after joining - sheet just closes silently
3. Code entry uses default iOS styling - doesn't match premium dark aesthetic
4. No clipboard detection - misses easy win when user has code copied
5. No event preview - user joins blindly without seeing what they're joining

---

## Design Solution

### 1. Simplified Tab Structure

**Before:** QR Code | Code | Link (3 tabs)
**After:** QR Code | Enter Code (2 tabs)

The "Enter Code" tab accepts both:
- Raw codes: `HIJACK`
- Pasted links: `momento://join/HIJACK` or `https://momento.app/join/HIJACK`

Smart detection parses either format automatically.

---

### 2. Verification-Style Code Input

Replace the default iOS text field with a spread-character input:

```
┌─────────────────────────────────────┐
│  H   I   J   A   C   K              │
│  ▢   ▢   ▢   ▢   ▢   ▢   ▢   ▢     │
└─────────────────────────────────────┘
```

**Styling:**
- Dark background matching card aesthetic (rgb: 0.12, 0.1, 0.16)
- Purple border/accent (royalPurple at 50% opacity)
- Monospaced font, large characters
- Subtle glow when focused
- Auto-advances cursor as user types
- Supports paste of full code or link

---

### 3. Clipboard Detection

On sheet open, check clipboard for valid code/link pattern.

If found, show banner at top:
```
┌─────────────────────────────────────┐
│  📋 Paste "HIJACK"?            [Tap]│
└─────────────────────────────────────┘
```

- Tapping fills the code input
- Banner dismisses if user starts typing manually
- Only shows if clipboard matches code pattern (alphanumeric, 4-12 chars) or momento URL

---

### 4. Event Preview Modal

After entering valid code (before joining), show preview:

```
┌─────────────────────────────────────┐
│                                     │
│         Joe's 26th Birthday         │
│                                     │
│     Starts tonight • 8 friends      │
│                                     │
│     ┌─────────────────────────┐     │
│     │    Join the momento     │     │
│     └─────────────────────────┘     │
│                                     │
│            [Cancel]                 │
│                                     │
└─────────────────────────────────────┘
```

**Content:**
- Event title (prominent)
- Timing: Uses humanized time ("Starts tonight", "Live now", "Starts tomorrow")
- Member count: "X friends" or "X friends ready"
- CTA: "Join the momento" button (purple, prominent)
- Cancel: Secondary dismiss option

**Flow:**
1. User enters code → lookup event details
2. Show preview modal
3. User taps "Join the momento" → actually join
4. Sheet closes → animate card onto main screen

---

### 5. Success Animation

After joining, the new event card should animate onto the main screen:

- Sheet dismisses
- New card slides in or fades in with a brief purple glow/pulse
- Draws user's eye to where it landed in the list
- Glow fades after 1-2 seconds

---

## Implementation Tasks

| # | Task | Complexity |
|---|------|------------|
| 1 | Remove Link tab, keep QR + Enter Code | Easy |
| 2 | Create verification-style code input component | Medium |
| 3 | Add clipboard detection on sheet open | Easy |
| 4 | Create event preview modal | Medium |
| 5 | Add "lookup event by code" API (preview without joining) | Medium |
| 6 | Update CTA copy to "Join the momento" | Easy |
| 7 | Add success animation to ContentView | Medium |
| 8 | Handle smart code/link parsing in single field | Easy |

---

## Success Criteria

- [ ] Only 2 tabs visible: QR Code | Enter Code
- [ ] Code input has spread characters with card-matching dark styling
- [ ] Clipboard prompt appears when valid code is copied
- [ ] Event preview shows before user commits to joining
- [ ] "Join the momento" button confirms the action
- [ ] New card animates/glows when added to main screen
- [ ] Links and raw codes both work in the same field
