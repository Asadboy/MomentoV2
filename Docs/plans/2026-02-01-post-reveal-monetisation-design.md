# Momento: Post-Reveal Monetisation Design

**Date:** 2026-02-01
**Status:** Draft
**Supersedes:** 2026-01-28-monetisation-design.md (philosophy shift)

---

## The Core Insight

The reveal moment is the emotional peak of the product. That's when users feel the most joy, nostalgia, and attachment. Monetisation and growth should happen *after* this moment — not before it.

**Old model:** Monetisation at creation, hoping the reveal validates the purchase.

**New model:** The reveal *is* the product demo. Monetisation flows from proven value, not promised value.

---

## Philosophy

**Momento does not own the memories — it orchestrates the reveal.**

### Principles

1. **Free users get the full reveal experience** — No gating, no degraded experience. The magic is free.

2. **Premium is about permanence and shareability** — Not access, not features. It's "keep this forever" and "share it beautifully."

3. **Conversion happens after emotional proof** — When users have engaged (liked, downloaded, browsed), they've already decided it's valuable. The prompt just offers to preserve that.

4. **Host-centric ownership** — Hosts create, hosts upgrade, hosts curate. Participants enjoy but don't control permanence.

5. **No pressure, just offers** — Premium is always available, never pushed. Post-reveal it's surfaced with context and stats.

### The Emotional Contract

> "Everything about creating and experiencing the Momento is free. Premium is for keeping it."

---

## Free vs Premium Split

### Free Tier (Generous, Complete)

| Feature | Details |
|---------|---------|
| Photos | Unlimited |
| Timing | Flexible — hours, days, or weeks |
| Reveal | Full experience, reactions, likes |
| Photo lifespan | 7 days after reveal, then fades |
| Downloads | With subtle Momento watermark |
| Web album | Not available |

### Premium (£7.99 One-Time, Per Event)

| Feature | Details |
|---------|---------|
| Photos | Unlimited (same as free) |
| Timing | Flexible (same as free) |
| Reveal | Full experience (same as free) |
| Photo lifespan | **Forever** |
| Downloads | **No watermark, bulk download** |
| Web album | **Shareable link for non-app users** |

### What Premium is NOT

- Not more photos (unlimited for everyone)
- Not flexible timing (free for everyone)
- Not exclusive features (everyone gets the magic)
- Not a subscription (one event, one payment)
- Not required to enjoy Momento

---

## Payment Model

**Who pays:** Event creator (host) only

- One person pays, whole group benefits
- Aligns with real-world social dynamics
- Simplifies UX: one upgrade prompt, one decision point
- Taps into host's emotional investment

**Pricing:** £7.99 one-time per event

**Integration:** RevenueCat

**Target conversion:** Post-reveal, when emotion is highest

---

## Post-Reveal Conversion (Primary)

### When It Triggers

The premium prompt appears *after* the host has demonstrated engagement:

- Liked 3+ photos
- Downloaded 1+ photo
- Browsed for 2+ minutes
- Returned to the album a second time

This ensures the prompt feels earned, not interruptive.

### What the Host Sees

A gentle card appears in the gallery (not a modal, not blocking):

```
┌─────────────────────────────────────┐
│  This Momento                       │
│  ✨ 47 likes · 12 downloads · 3 shares │
│                                     │
│  Photos fade in 6 days.             │
│  Keep them forever?                 │
│                                     │
│  [Turn into a keepsake — £7.99]     │
│                                     │
│  ✕ dismiss                          │
└─────────────────────────────────────┘
```

### Design Choices

- **Stats as social proof** — "Your friends already decided this is valuable"
- **Dismissible** — Respects their choice, no guilt
- **Soft language** — "Turn into a keepsake" not "Upgrade now"
- **One-tap purchase** — Apple Pay sheet, minimal friction
- **Appears once per session** — Doesn't nag on every visit

### After Upgrading

- "This Momento is now yours forever" confirmation
- Shareable web album link appears immediately
- Watermarks removed from downloads
- Instant gratification

---

## Creation-Time Option (Secondary)

For hosts who *know* this event is special (birthday, holiday, wedding).

### Design

A quiet toggle in the create flow, after setting name and times:

```
┌─────────────────────────────────────┐
│  ✨ Premium Momento         £7.99  │
│                                     │
│  Photos live forever · Shareable    │
│  web album · No watermark           │
│                              [ OFF ]│
└─────────────────────────────────────┘
```

### Principles

- **Toggle, not modal** — No interruption, no pressure
- **Benefits visible without tapping** — One line summary
- **OFF by default** — Free is the default, premium is opt-in
- **No urgency language** — No "limited time" or "recommended"
- **Same price as post-reveal** — No discount tricks

---

## Web Album (Premium Feature)

### Purpose

Solves the problem of sharing photos with people who don't have the app. It's a gift first, a growth tool second.

### What Non-App Users See

A clean, curated gallery page. No login required. Mobile-first.

```
┌─────────────────────────────────────┐
│  [Cover Emoji]                      │
│  Sarah's Birthday                   │
│  January 25, 2026 · 47 photos       │
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ 📷  │ │ 📷  │ │ 📷  │           │
│  └─────┘ └─────┘ └─────┘           │
│  (grid of photos, tap to expand)    │
│                                     │
│  ─────────────────────────────────  │
│  Made with Momento                  │
└─────────────────────────────────────┘
```

### Contextual CTA

When a non-app user downloads a photo:

```
┌─────────────────────────────────────┐
│  📷 Photo saved!                    │
│                                     │
│  Want to host your own Momento?     │
│  [Get the app]        [Maybe later] │
└─────────────────────────────────────┘
```

- Appears on first download, not every download
- "Maybe later" dismisses without guilt
- Tracks the action for analytics

### CTA Hierarchy

1. **Primary:** "Host your own Momento"
2. **Secondary:** "Get the app"
3. **Tertiary:** Footer link (passive)

### Future: Host Curation

Hosts can select which photos appear in the web album — useful for B2B/festivals where you want a curated public gallery.

---

## Growth Loop

```
Host creates Momento (free, generous)
        ↓
Event happens, photos taken
        ↓
Reveal (emotional peak)
        ↓
Host upgrades → gets web album link
        ↓
Host shares link with non-app attendees
        ↓
Non-app users view photos (gift)
        ↓
Non-app users download → see CTA
        ↓
Some convert → become hosts → cycle repeats
```

### Why It Works

1. **Every premium upgrade creates distribution** — Web album is both feature and growth channel
2. **Non-app users experience value before downloading** — They see the photos, understand the product
3. **Conversion at emotional moment** — They just saw photos from a night they loved
4. **Hosts become evangelists** — Sharing the link is sharing the product

---

## Copy & Language

### Principles

| Avoid (software) | Use (keepsake) |
|------------------|----------------|
| Upgrade | Keep forever |
| Subscribe | Turn into a keepsake |
| Your plan | Your memories |
| Export | Save to camera roll |
| Premium features | What you get |
| Expired | Faded / Gone |

### Key Moments

**Post-reveal prompt:**
- "This Momento got 47 likes. Keep it forever?"

**Expiry warning:**
- "These photos fade in 3 days"

**Web album CTA:**
- "Host your own Momento"

**After upgrading:**
- "This Momento is now yours forever"

### Metaphors

- **Fade, not delete** — Photos "fade away" like old memories
- **Keepsake, not archive** — You're keeping a moment, not storing files
- **Host, not create** — You host a Momento like you host a party

---

## Metrics to Track

| Metric | What it tells you |
|--------|-------------------|
| Post-reveal conversion rate | Primary success metric |
| Engagement before conversion | Optimal prompt timing |
| Web album opens | Premium feature usage |
| Web → App installs | Growth loop efficiency |
| New hosts from web visitors | Full funnel success |

---

## Anti-Patterns to Avoid

| Pattern | Why it's bad |
|---------|--------------|
| Modal interruptions | Breaks the emotional moment |
| "You can't do X" blocks | Feels hostile |
| Urgency tactics | Erodes trust |
| Discount at creation | Undermines post-reveal conversion |
| Watermark on in-app viewing | Punishes free users |
| Premium-only reveal | Hostage-taking |
| Per-photo pricing | Nickel-and-diming |

**North star test:**
> "Does this make the free experience worse, or the premium experience better?"

Only the latter is acceptable.

---

## Implementation Priorities

### Phase 1: Post-Reveal Conversion

The core of the new strategy.

- Track engagement metrics (likes, downloads, browse time)
- Post-reveal prompt with stats (appears after engagement threshold)
- RevenueCat integration for £7.99 one-time purchase
- "Photos saved forever" confirmation flow
- Remove 7-day expiry for upgraded events

### Phase 2: Free Tier Polish

Make the free experience genuinely generous.

- Enable flexible timing for all events
- Subtle watermark on downloads
- Expiry countdown in gallery ("Photos fade in X days")

### Phase 3: Web Album

Once premium exists, this becomes the killer feature.

- React site with Supabase integration
- Public gallery page (no auth required)
- Contextual CTA on download
- Analytics tracking
- Link generation in-app for premium hosts

### Phase 4: Growth & Iteration

Once the loop is running, optimise it.

- Host curation for web albums
- A/B test prompt timing and copy
- Track full funnel
- Bulk download feature

### Not Yet

- Physical prints (future, once volume exists)
- B2B features (future, once proof exists)
- Gift upgrades from participants (adds complexity)

---

## Future Layers

### Physical Prints

> "Turn this Momento into a photo book — £14.99 delivered"

Natural extension of the permanence value prop:
- **Free** → Experience it
- **Premium** → Keep it digitally
- **Prints** → Keep it physically

### B2B / Festivals

Event partners create branded Momentos. Attendees get premium experience free. Partner gets content + metrics.

Requires: Host curation, analytics dashboard, custom branding.

---

## Summary

**The shift:** From "pay to unlock features" to "experience the magic, then keep it forever."

**The bet:** People will pay more *after* they've felt the value than *before* they can imagine it.

**The product:** Free and generous until the reveal. Premium exists to preserve what already matters.
