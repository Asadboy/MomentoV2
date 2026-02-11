# Momento V1 — Pivot Roadmap (No Monetisation)

**Date:** 2026-02-11
**Status:** Active
**Target submission:** Friday Feb 13, 2026
**Target live:** Feb 21, 2026

---

## The Pivot

Strip all monetisation for the first ~100 users. No RevenueCat, no premium purchases, no watermarks, no auto-delete. Everything is free. The web album becomes the primary growth flywheel — not a premium perk.

**Why:** Paywalling the web album kills the viral loop before it starts. A freely shared web album creates more hosts than a £7.99 paywall ever could at zero users. Monetisation comes later once hosting is habitual and the loop is proven.

**The loop we're optimising for:**
```
Attendee → Feels the reveal → Sees "host your own" nudge → Creates event →
New audience → Some attend future events → Loop repeats
```

**The web album's role:**
```
Host shares album link → Non-app users see photos → "How did you make this?" →
Download app → Become future hosts
```

---

## What Gets Stripped

### Files to Delete
1. `Momento/Services/PurchaseManager.swift` — RevenueCat wrapper
2. `Momento/Features/Events/PremiumUpgradeModal.swift` — premium upsell modal
3. `Momento/Components/WatermarkRenderer.swift` — photo watermark renderer
4. `Momento/Config/RevenueCatConfig.swift` — RevenueCat API key

### Files to Modify (Remove Premium References)
5. `Momento/App/MomentoApp.swift` — remove `PurchaseManager.shared.configure()`
6. `Momento/App/ContentView.swift` — remove premium modal trigger logic
7. `Momento/Models/Event.swift` — remove `isPremium`, `expiresAt` properties (or keep in model but ignore in UI)
8. `Momento/Services/SupabaseManager.swift` — remove `PurchaseManager.identify()` calls, remove `markEventPremium()`, remove `expires_at` calculation on event creation
9. `Momento/Features/Events/PremiumEventCard.swift` — remove expiry badge, ungated web album link (show for ALL revealed events)
10. `Momento/Features/Reveal/FeedRevealView.swift` — remove `premiumPromptCard`, replace with attendee "host your own" nudge
11. `Momento/Features/Reveal/RevealCardView.swift` — remove `isPremium` param, always use clean images (no watermark)
12. `Momento/Features/Gallery/LikedGalleryView.swift` — remove watermark logic, ungated web album ShareLink
13. `Momento/Services/AnalyticsManager.swift` — remove premium analytics events
14. `Momento.xcodeproj/project.pbxproj` — remove RevenueCat package dependency

### Web (Landing Page at /Users/asad/Documents/Momento Landing Page/)
15. `pages/privacy.js` — remove RevenueCat references, premium purchase mentions, 7-day deletion language
16. `pages/terms.js` — remove "Premium Purchases" section, watermark mentions, 7-day deletion, £7.99 pricing
17. `pages/album/[code].js` — update interlude CTA (after 15 photos) from "download the app" to "Host your own Momento"

---

## What Gets Added

### 1. Attendee "Host Your Own" Nudge (In-App)

After the reveal completion screen ("That was the night"), all users (not just hosts) see:

> *"Got something coming up?"*
> [Create a Momento]

- Appears below the existing completion content
- One line, one button, same cinematic energy as the reveal
- Tapping goes straight to the create flow
- If dismissed, gone — no persistence, no guilt
- Shown to ALL users (attendees and hosts alike)

### 2. Web Album Link for All Hosts

The "Share album link" button on `PremiumEventCard.swift` currently requires `event.isPremium`. Change to show for ALL revealed events. Same button, same copy link behaviour.

Also surface the web album link at the end of the reveal flow — after "That was the night" but before the "host your own" nudge. Something like:

> "Share this album" → copies `yourmomento.app/album/{code}`

This is the moment the host is most likely to drop the link in the group chat.

### 3. Web Album "Host Your Own" CTA

Update the interlude card on the web album (appears after 15 photos) from a generic "download the app" prompt to:

> *"This was [Host Name]'s night. Yours could look like this."*
> [Host your own Momento]

Same button leads to app store. End of album also gets a similar CTA.

### 4. Memory Nudge Notification (Post-Launch)

Not blocking for submission. Build after launch:
- One push notification 7-10 days after a reveal
- Shows a photo from the event they attended
- No CTA, just the memory
- Puts Momento back in their head naturally

---

## Execution Plan

### Day 1: Wednesday Feb 11 — Strip Premium + Ungate Web Album

**Block 1: Delete premium files**
- Delete PurchaseManager.swift
- Delete PremiumUpgradeModal.swift
- Delete WatermarkRenderer.swift
- Delete RevenueCatConfig.swift
- Remove RevenueCat SPM dependency from Xcode project

**Block 2: Clean up references in modified files**
- MomentoApp.swift: remove PurchaseManager.configure()
- ContentView.swift: remove premium modal logic
- SupabaseManager.swift: remove PurchaseManager.identify() calls, remove markEventPremium(), stop setting expires_at on creation
- AnalyticsManager.swift: remove premium analytics events
- Event.swift: keep isPremium/expiresAt in model (database still has columns) but they're always false/nil

**Block 3: Ungate web album + remove watermarks**
- PremiumEventCard.swift: remove `if event.isPremium` gate on web album link — show for all revealed events. Remove expiry badge.
- RevealCardView.swift: remove isPremium param, always share clean images
- LikedGalleryView.swift: remove watermark logic, ungate web album ShareLink
- FeedRevealView.swift: remove premiumPromptCard section

**Verify:** App builds and runs. No references to RevenueCat or PurchaseManager remain. Web album link shows for all revealed events. Photos download without watermark.

### Day 2: Thursday Feb 12 — Add Nudges + Update Web Content

**Block 1: Attendee "host your own" nudge**
- In FeedRevealView.swift, after the completion card ("That was the night"), add:
  - "Share this album" button (copies web album link) — for hosts
  - "Got something coming up?" + "Create a Momento" button — for all users
  - Tapping create goes to CreateMomentoFlow

**Block 2: Update privacy + terms pages**
- privacy.js: remove RevenueCat, premium references, update data retention (no auto-delete)
- terms.js: remove Premium Purchases section, remove 7-day deletion, remove watermark/£7.99 references

**Block 3: Update web album CTA**
- album/[code].js: update interlude card copy to "Host your own Momento" framing

**Verify:** Full flow test on device: create → invite → capture → reveal → nudge appears → web album link works → web album loads in browser with updated CTA

### Day 3: Friday Feb 13 — Final Testing + Submit

**Morning: Final device testing**
- Clean install test on physical device
- Full flow: sign in → create → invite → capture → wait → reveal → like → download (no watermark) → share album link → web album loads
- Verify privacy/terms pages load from sign-in screen
- Verify no debug UI visible
- Verify no premium UI anywhere

**Midday: App Store metadata**
- Screenshots (3+ per device size showing core loop)
- App description
- Privacy nutrition labels (simplified — no IAP data)
- Age rating questionnaire
- Keywords

**Afternoon: Submit**

---

## What's NOT in This Submission

Explicitly deferred. Each gets its own plan when the time comes.

| Item | Why it waits |
|------|-------------|
| Push notifications | Text your friends. Build when you have users you don't know. |
| Premium/monetisation | Comes back once loop is proven with ~100 users |
| Auto-delete / expiry | No deletion pressure in the free phase |
| RevenueCat | Returns with premium |
| PostHog dashboards | Events are tracked. Dashboards when there's data worth looking at. |
| Memory nudge notification | Post-launch enhancement |
| Web album header/footer CTAs | Can iterate on the web side anytime without app update |

---

## Signals That The Loop Is Working

Watch for these in the first few weeks:

1. **Attendee → Host conversion:** Did anyone who attended an event go on to create their own? Even 1 out of 10 is strong.
2. **Web album views per event:** Are hosts actually sharing the link? Are non-app users clicking it?
3. **Create flow entries from reveal nudge:** PostHog can track if someone taps "Create a Momento" from the post-reveal screen.
4. **Organic installs after events:** App Store downloads in the days following an event.
5. **Second event creation:** Does a host create more than one event?

## Failure Modes to Watch

1. **Hosts don't share the web album link.** If the link is there but nobody shares it, the flywheel is dead. Consider making it more prominent or auto-suggesting sharing.
2. **Web album visitors don't convert.** They see the photos but don't download the app. CTA might need to be stronger, or the album experience might not convey enough of the magic.
3. **Attendees say "this is cool" but never host.** The gap between liking something and organising something is huge. The nudge helps but timing is everything — they need an event in their life to attach it to.
4. **Events are too small.** If every event is 4-5 close friends, the audience for each event is tiny and the loop has no fuel. Encourage larger events.
5. **The reveal isn't magical enough.** If the reveal feels like "oh, photos" instead of "oh my god, look at these," nothing downstream works. The reveal is the product demo.

---

**Last updated:** 2026-02-11
