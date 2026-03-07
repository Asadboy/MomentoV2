# Momento — Vision & Product Direction

**Date:** March 2026
**Status:** Post-pivot, pre-launch

---

## One-Liner

> You all get a disposable camera with 10 photos each for the night — the next morning you get to see everything everyone took.

---

## Product Vision

Momento is a **shared disposable camera for parties**. It gives every guest a roll of 10 shots, locks the photos away, and reveals them the next day. The result is a collection of real, unfiltered, intentional moments — captured by everyone, seen by everyone.

Momento exists to bring back the feeling of disposable cameras in a world of infinite camera rolls. Not every moment needs to be captured — just the ones that matter enough to spend a shot on.

---

## Core Emotion

Momento sells **nostalgia** — both during and after the event.

- **During the event:** The constraint of 10 shots makes every photo feel deliberate. You're not documenting — you're choosing what matters.
- **After the reveal:** The photos trigger the feeling of flipping through a developed roll. Laughing at the unexpected ones, saving the beautiful ones, being nosy about what everyone else saw that night.

The reveal is the delivery mechanism. Nostalgia is the product.

---

## Target Audience

### The Host

The host is the customer. They are the person whose birthday it is, whose house the party is at, whose night it is. Momento gives them:

- A fun addition to their party ("everyone download Momento tonight")
- A sentimental collection of how their friends experienced the night
- Content for their own social media the next day

The host does the legwork — they tell their friends, they create the event. Every host who runs a successful Momento event puts the app in front of 5-15 potential future hosts.

### The Guest

The guest is the user, not the customer. They need the experience to be:

- Effortless to join
- Fun to use during the event
- Rewarding the next morning

If a guest has a great experience, they become a future host.

### Ideal Event Profile

| Attribute | Ideal |
|---|---|
| **Type** | Birthdays, house parties, small gatherings |
| **Group size** | 5–15 people |
| **Photo volume** | 50–150 total photos (5-15 people x 10 shots) |
| **Social dynamic** | Clear host, defined friend group, people who know each other |
| **Environment** | Engaged, social, not too chaotic |

### Where Momento Doesn't Work

- Raves and nightlife (too chaotic, people forget)
- Large-scale events (too many strangers)
- Professional events (wrong vibe)

---

## Core Mechanics

### 10 Shots. No Exceptions.

Every guest gets **10 shots** per event. This is the entire pivot and the core product mechanic.

- No bonus shots
- No earning more
- Join late? Still 10
- Host? Also 10
- Run out? You're done

The constraint is the feature. It creates:

- **Intentionality** — you think before you shoot
- **Quality** — fewer spam photos, more meaningful ones
- **Participation** — everyone has the same budget, so everyone contributes
- **A story** — 10 shots is a curated slice of someone's night

### Shot Counter

The remaining shot count must be **painfully obvious** at all times. This is not a subtle UI element — it's the signature of the entire experience. The countdown from 10 to 0 is the gamified tension that makes Momento feel different from opening your normal camera.

### The Reveal

- Photos are locked until the event ends (currently 24 hours after creation)
- A push notification tells guests the reveal is ready
- Guests open at their own pace (most within 24-48 hours)
- The reveal is currently a solo experience — you scroll through everyone's photos on your own time

### Photo Lifecycle

| Phase | Current | Future |
|---|---|---|
| **During event** | Photos locked, no preview | No change |
| **Reveal** | All photos visible in-app | No change |
| **Retention** | Photos live forever in-app | **30-day retention policy** |
| **Export** | Download & share, no watermark | Watermark or monetise downloads |

The 30-day retention policy leans into the disposable metaphor — the photos aren't permanent unless you choose to save them. This also opens a monetisation path around permanence.

---

## Viral Growth

### The Loop

```
Host creates event
  → 5-15 guests join
    → Guests have a great experience
      → Guests host their own event later
        → New guests join
          → Repeat
```

**Target: K-factor of 1** — every host generates at least one future host.

### Amplifiers

- **Shareable web album** — attendees who don't have the app can view photos via a web link, with a CTA to download for next time
- **Post-reveal sharing** — guests share favourite photos to group chats and Instagram stories, creating organic awareness
- **Word of mouth** — "we used this app at the party last night" is the primary acquisition channel for now

### What's NOT the Growth Strategy

- No social feed, no public discovery
- Not fighting for daily attention like Instagram
- Momento is an **event utility**, not a social network — and that's a strength

---

## Brand Identity

### What Momento Is

- **Authentic** — real photos, no retakes, no filters beyond the disposable aesthetic
- **Fun** — a party feature, not a productivity tool
- **Disposable** — impermanent by design, precious because of it
- **Simple** — one mechanic, no complexity

### What Momento Is NOT

Momento deliberately refuses to become:

- A social network (no feed, no followers, no public profiles)
- A photo editing app (no filter packs, no beautification)
- A communication platform (no comments, no DMs — at least not now)
- A content creation tool (it captures moments, it doesn't produce content)

### Anti-Features (things we will NOT build)

- Likes or reactions on photos
- Social feeds or explore pages
- Photo editing or retouching
- Public profiles or follower counts
- Comments (users have asked — answer is no for now)

Usernames exist in the codebase but have no clear purpose yet. Revisit only if they serve a specific mechanic.

### Photo Aesthetic

Photos currently have a disposable camera filter applied. No additional watermark or branding for now. The first 100 users are friends-of-friends — a recognisable Momento aesthetic (timestamp, grain, frame) is a future consideration, not a launch priority.

---

## Product Principles

1. **The constraint is the feature.** 10 shots is not a limitation — it's the entire point. Never dilute it.
2. **The host is the hero.** Every product decision should make the host look good and feel rewarded.
3. **Participation over perfection.** A blurry photo from your mate is worth more than a perfect photo from a stranger.
4. **Don't fight for attention.** Momento opens at parties and the morning after. That's it. No engagement tricks.
5. **Ship, then polish.** The first 100 users are friends. Watermarks, aesthetics, and premium features come after product-market fit.

---

## Monetisation

### Philosophy

The host is the paying customer. Monetisation should feel like an upgrade, never a tax. Guests should never hit a paywall.

### Revenue Paths (Prioritised)

| Path | Description | Timing |
|---|---|---|
| **Extra rolls** | Host buys additional rolls of 10 shots for guests | Post-launch, once 10-shot limit is validated |
| **Print-on-demand** | Host picks their favourite 20 photos → physical prints delivered | Later — requires pipeline |
| **Premium event features** | "Party pack" with extras for the host (more guests, extended reveal, etc.) | Later |
| **Permanence** | Pay to keep photos beyond the 30-day retention window | After retention policy ships |
| **Watermark-free exports** | Free exports now; gate behind payment later | After brand/watermark is established |

### Competitive Reference

POV and Once (competitors in the space) already charge for photo counts and guest counts — this validates the model.

---

## v1 vs Later

### v1 (Ship Now)

- 10 shots per guest, hard limit
- Prominent shot counter in camera UI
- Host creates event, guests join
- Photos locked until reveal
- Reveal notification + gallery
- Download and share photos (no watermark)
- Shareable web album with download CTA
- Disposable camera filter on photos

### v2 (After PMF)

- 30-day photo retention policy
- Extra rolls (in-app purchase)
- Host "party pack" premium tier
- Momento watermark/brand on exported photos
- Improved reveal experience (animations, slideshow)

### v3+ (Future)

- Print-on-demand pipeline
- Recognisable Momento photo aesthetic (timestamp, frame, grain)
- TikTok/Instagram content strategy ("things to have at your birthday")
- Host analytics (participation stats, most-viewed photos)
- Comments on photos (only if it serves the experience)

---

## Differentiation

**"Why not just make a shared iCloud album?"**

> Because Momento isn't about collecting photos — it's about the experience of taking them and the chaos of seeing them. You don't get to preview your shots. You don't get unlimited tries. You don't see what anyone else took until the next morning. A shared album is a folder. Momento is a disposable camera that the whole party shares.

The moat is the **mechanic + the emotion**, not the technology. No existing tool combines:

- A hard shot limit that forces intentionality
- Hidden photos that build anticipation
- A collective reveal that creates a shared moment the next day

---

## Key Metrics to Track

| Metric | Why It Matters |
|---|---|
| **Shots used per guest** | Are people engaging with the 10-shot mechanic? Target: 7+ average |
| **Participation rate** | % of guests who take at least 1 photo. Target: 80%+ |
| **Reveal open rate** | % of guests who open the reveal. Target: 90%+ |
| **Guest-to-host conversion** | % of guests who later create their own event. This IS the growth metric |
| **Photos shared externally** | How many photos get posted to stories/group chats — organic reach |
| **Time to first shot** | How quickly do guests start shooting after joining? |

---

*This document is the north star for all product decisions until Momento finds product-market fit.*
