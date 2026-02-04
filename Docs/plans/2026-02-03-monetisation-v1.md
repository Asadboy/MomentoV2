# Momento Monetisation — V1

**Date:** 2026-02-03
**Status:** Active
**Scope:** V1 only. Anything beyond V1 is clearly labelled as "Future."

---

## Philosophy

The reveal moment is the emotional peak of the product. Monetisation happens *after* that moment — never before it.

Free users get the full experience. No gating, no degraded reveal, no locked features during capture. The reveal *is* the product demo. Premium exists to preserve what already matters.

**The emotional contract:**
> "Everything about creating and experiencing the Momento is free. Premium is for keeping it."

**Principles:**
- Free users get the full reveal experience — the magic is free
- Premium is about permanence and shareability — not access
- Conversion happens after emotional proof — they've already felt the value
- Host pays, group benefits — mirrors real-world social dynamics
- No pressure, just offers — always available, never pushed

---

## Free Tier

Every user gets the complete Momento experience at no cost.

| Feature | Details |
|---------|---------|
| Photos | Unlimited during capture |
| Reveal | Full experience — swipe, flip, likes |
| Downloads | With Momento watermark (classy, doubles as branding) |
| Web album | Not available |
| Photo lifespan | 30 days post-reveal at launch, moving to 7 days once past early adopter phase |

### Auto-Delete

Free events auto-delete after the grace period. The countdown UI is visible from day one ("This Momento fades in X days") so users understand the model from the start. The actual deletion timeline:

- **Launch period:** 30 days post-reveal (generous for early adopters — these users are your evangelists)
- **Post-launch:** 7 days post-reveal (standard free tier)

The switch from 30 to 7 days is a manual decision, not automatic. Make the call when word-of-mouth growth brings in users beyond your personal network.

### Event Card Stats

Event cards display total likes alongside photo count and member count. This passively reinforces the value of what the host would lose — "142 likes" makes permanence feel worth paying for. No hard sell, just data.

---

## Premium — £7.99 Per Event

One-time payment. Host pays, whole group benefits.

### What It Unlocks

| Feature | Details |
|---------|---------|
| Permanence | Photos live forever — no auto-delete |
| Downloads | Watermark removed |
| Web album | Shareable link at `/album/[code]` for non-app users |

### Who Pays

The host (event creator) only. One person pays, one decision point. Mirrors real life — the person who throws the party pays for the photo booth.

### Pricing

£7.99 one-time per event. No subscriptions, no tiers, no bundles. Low enough that a host doesn't hesitate after a good night, high enough to be a real business.

### Payment Provider

RevenueCat. Non-consumable in-app purchase. Implementation details TBD — will be covered in a separate implementation plan when built.

---

## Purchase Flow

Premium is offered in two places, both post-reveal, both host-only.

### Touchpoint 1: End of Reveal Feed

After the host swipes through the last photo in the reveal feed, the premium prompt appears as the final card. This is the highest-emotion moment — they've just relived the entire event.

The card shows:
- Event stats (total likes, photo count, member count)
- "This Momento fades in X days"
- Purchase CTA
- Dismiss option — no guilt, no pressure

If they dismiss, nothing else happens in that session.

### Touchpoint 2: Event Screen Modal

When the host returns to the event screen after reveal, a modal appears. Not blocking the full screen — dismissible, once per visit. A gentle reminder that premium is available.

This only shows for the host. Guests never see purchase prompts.

### After Purchase

- Event marked `is_premium = true` in Supabase
- Watermark removed from downloads immediately
- Web album link becomes available
- "This Momento is now yours forever" confirmation
- Auto-delete cancelled for this event

### Manual Override

At launch scale, you can manually set `is_premium = true` in Supabase for friends or special cases. No admin tooling needed yet.

---

## Watermark

One watermark type in V1. No variants, no complexity.

### Design

- Classy, subtle Momento branding on downloaded photos
- Designed to work as organic advertising — users share watermarked photos naturally
- Not intrusive enough to ruin the photo, visible enough to build awareness

### Rules

- Applied to all photos downloaded from free events
- Removed immediately when host purchases premium
- Applied at download time, not baked into stored photos
- Same watermark regardless of where the photo is shared

### What V1 Does NOT Have

- No separate "share branding" variant
- No in-app viewing watermark — only on downloads
- No per-photo watermark toggling

---

## Web Album

Premium-only feature. A shareable link that lets non-app users view the event's photos in a browser.

### What Exists

Already built at `/album/[code]` on the Next.js landing page site. Current functionality:

- 3-column responsive photo grid
- Lightbox/fullscreen viewing
- Photo metadata (username, time captured)
- Download functionality
- Infinite scroll with lazy loading
- "Not ready" state for unrevealed albums
- CTA after 15 photos prompting app download

### How It Works

- Host purchases premium → web album link becomes available in the app
- Host shares the link with anyone (group chat, social media, family)
- Recipients view photos in browser — no login, no app required
- If a non-app user downloads a photo, a gentle "Host your own Momento" CTA appears once

### V1 Work Needed

- Gate link generation behind `is_premium = true`
- Surface the shareable link in the event screen UI for premium hosts
- Verify signed URLs and pagination work against the new 5-table schema

### Growth Loop

Every premium purchase creates distribution. Host upgrades → shares link → non-app users see photos → some download the app → become hosts. The web album is both a feature and a growth channel.

---

## Copy & Language

The app speaks like a person, not software. Premium is framed around memories, not features.

| Avoid | Use Instead |
|-------|-------------|
| Upgrade | Keep forever |
| Subscribe | Turn into a keepsake |
| Your plan | Your memories |
| Export | Save to camera roll |
| Premium features | What you get |
| Expired / Deleted | Faded / Gone |

### Key Moments

- **End of reveal prompt:** "This Momento got 47 likes. Keep it forever?"
- **Expiry countdown:** "These photos fade in X days"
- **After purchasing:** "This Momento is now yours forever"
- **Web album CTA (non-app users):** "Host your own Momento"

---

## What's NOT In V1

These are explicitly deferred. If any of these come up in future sessions, they should be treated as new scope with their own design docs.

- **Smart engagement triggers** — no tracking likes/browse time before showing prompt
- **Guest purchasing** — only hosts can buy
- **Creation-time premium toggle** — no purchasing before reveal
- **Physical prints** — future layer on top of permanence
- **B2B / festival features** — requires curation, analytics dashboards, custom branding
- **Subscription model** — per-event only
- **Bulk download** — future premium enhancement
- **A/B testing prompt copy** — needs volume first
