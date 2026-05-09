# 10Shots — Vision & Product Direction

**Date:** May 2026  
**Status:** Rebrand locked, pre-launch sprint  
**Former name:** Momento  
**Internal note:** Backend/project names can remain Momento where changing them adds risk. Public brand is 10Shots.

---

## One-Liner

> 10Shots is a disposable camera game for your favourite people: everyone gets 10 shots, no previews, no retakes, and the whole roll reveals later.

---

## Product Vision

10Shots is not just a shared photo album. It is a social camera game built around one constraint:

> **Everyone gets 10 shots.**

The original Momento idea was a delayed shared-memory photo app. Through betas, product taste, and the shift toward more intentional capture, the product has evolved into 10Shots: a disposable camera experience where the limit is the magic.

The app exists to make nights, trips, weekends away, birthdays, family gatherings, and time with friends feel more intentional. Instead of everyone taking hundreds of forgettable photos, each person gets a small roll of 10. That limit creates tension during the event, curiosity before the reveal, and nostalgia afterwards.

10Shots should feel like:

- a game during the event
- a disposable camera after the event
- a shared memory without becoming a social network

---

## Core Product Thesis

> **The 10-shot constraint is the product.**

10 shots is not a limitation to apologise for. It is the mechanic that makes the app fun, memorable, and easy to explain.

The constraint creates:

| Effect | Why it matters |
|---|---|
| **Intentionality** | Users think before taking a shot. |
| **Tension** | Every shot spent means fewer shots left. |
| **Social pressure** | The lobby shows who is using their roll and who is not. |
| **Better reveal** | Fewer spam photos means the final roll feels more curated. |
| **Word of mouth** | “Everyone gets 10 shots” is instantly understandable. |
| **Brand identity** | The ten dots become the logo, counter, lobby, and visual system. |

The product should always protect this sentence:

> **10 shots each. No previews. Reveal later.**

---

## Positioning

### Primary Positioning

> **A disposable camera game for parties, trips, and weekends with friends.**

### Short Copy Options

- **10 photos each. Reveal tomorrow.**
- **Your night. 10 shots each.**
- **A disposable camera for the whole group.**
- **Everyone gets 10. Make them count.**
- **No previews. No retakes. Just the reveal.**

### What 10Shots Is

- A party-game-esque disposable camera
- A shared event camera
- A social constraint around taking photos
- A next-day reveal experience
- A fun way to capture time with friends and family

### What 10Shots Is Not

- Not a social network
- Not a public photo feed
- Not a daily camera app
- Not a photo editing app
- Not an Instagram competitor
- Not a wedding SaaS product
- Not a massive event platform, at least for now
- Not a drinking app, despite the playful “shots” wording

The word “shots” should always be paired with camera language: disposable camera, photos, rolls, reveal, dots, capture.

---

## Target Audience

### Core Audience

Friend groups who are already together in real life.

This includes:

- birthdays
- house parties
- pre-drinks
- weekends away
- trips
- festivals
- family gatherings
- Christmas / New Year
- university houses
- small celebrations
- camping/hiking weekends
- casual weddings as a guest group, not formal wedding software

### Ideal Event Profile

| Attribute | Ideal |
|---|---|
| **Group size** | 3–15 people initially |
| **Primary paid unlock** | More people in one event |
| **Social dynamic** | People know each other |
| **Host** | Clear person organising the event |
| **Photo volume** | 30–150 total shots |
| **Environment** | Social, memorable, not too chaotic |

### Where It Probably Does Not Work

- Huge public events with strangers
- Raves where people forget to use the app
- Corporate/professional events
- Any use case where people need polished, guaranteed photography

---

## Core Loop

```text
Host creates event
  → Friends join
    → Everyone sees the lobby
      → Everyone gets 10 shots
        → Dots fill up during the event
          → Reveal unlocks later
            → People like, save, and share favourites
              → A guest becomes a future host
```

The core loop should be simple enough to explain at a party in one sentence:

> “Join this — everyone gets 10 photos and we see them later.”

---

## The Lobby: The New Core Feature

The lobby is the live home of the event.

It is not just an event card. It is the game board.

### The lobby shows:

- Event name
- Event state: waiting, live, or reveal
- Countdown to start/end/reveal
- Invite button
- People list
- Each person’s avatar/name
- 10 dots per person
- Filled dots = shots used
- Empty dots = shots remaining
- Current user pinned at the top
- Other users sorted by shots taken, highest first

### Why the Lobby Matters

The lobby turns 10 shots from a private limit into a shared social mechanic.

It creates moments like:

- “Joe’s already on 8/10.”
- “Alex hasn’t taken any yet.”
- “Bethan’s finished her roll.”
- “I’ve got 2 left — I need to save them.”
- “Everyone’s nearly done.”

That is the tasteful gamification. No coins. No streaks. No fake engagement. The dots are the communication.

---

## Event States

Keep the state model simple.

### 1. Waiting

`now < startsAt`

Purpose: build hype and show who has joined.

Card shows:

- Event name
- Starts in countdown
- People list with empty dots
- Invite button

### 2. Live

`startsAt <= now < endsAt`

Purpose: main game state.

Card shows:

- LIVE badge
- Ends in countdown
- People list with dots filling in
- Tap card to open camera

### 3. Reveal

`now >= endsAt`

This has two sub-phases.

#### Before reveal time

`endsAt <= now < releaseAt`

Card shows:

- Reveals in countdown
- Final dot counts
- Anticipation state

#### After reveal time

`now >= releaseAt`

Card shows:

- “Reveal your 10Shots”
- Total shots from total people
- Tap to enter reveal

After reveal, the event moves to the done pile.

---

## Taking Shots

Rules:

- 10 shots per person, per event
- No exceptions
- No previews
- No retakes
- No deleting and replacing shots
- Once the 10th shot is taken, the camera locks
- Shots sync in the background with offline support

The camera should make the remaining shot count obvious at all times.

The user should always feel:

> “I have a roll. I am spending it.”

### Last Shot Moment

Using the final shot should feel satisfying, not like an error.

Suggested copy:

> **That’s a wrap.**  
> Your 10 shots are locked in.

---

## Reveal Experience

The reveal is the emotional payoff.

During the event, the product is playful. During the reveal, it becomes nostalgic.

### Reveal Principles

- Shots reveal after the chosen reveal time
- Each person reveals independently
- All shots are shown chronologically
- Each shot has attribution
- Like/save/share should be easy
- Sharing should have no watermark in V1
- Reveal should feel like opening a developed roll

### Done Pile

Past events should live in a simple “done” section.

Each done event shows:

- Event name
- Date
- Total shots
- Total likes
- Number of people
- Tap to open gallery/liked shots

The done pile should feel like a drawer of developed rolls.

---

## Brand Identity

### The Ten Dots

The ten dots are the brand system.

They can become:

- App icon
- Camera shot counter
- Lobby progress indicator
- Loading animation
- Watermark/frame motif later
- App Store screenshot design language
- Website visual identity

The dots are not decoration. They are the mechanic made visible.

### Visual Feel

10Shots should feel:

- black/white
- simple
- high contrast
- disposable camera inspired
- social but not childish
- playful but not cringe
- nostalgic after the reveal
- sharp enough for parties, soft enough for family/trips

### Naming Caution

“Shots” can imply alcohol. The product must counterbalance this by constantly using camera language:

- disposable camera
- photos
- roll
- reveal
- capture
- dots
- camera
- gallery

Avoid alcohol-coded language:

- rounds
- drink up
- bar tab
- shot glass
- drunk-mode branding
- “take your shot” as the main line

---

## Monetisation Philosophy

The app experience should be flawless and fun first.

Money should come from event scale, not annoying feature gates.

### Core Rule

> Guests never pay. Hosts pay when the event gets bigger.

### V1

No monetisation at launch unless it risks nothing.

Focus:

- usage
- retention
- reveal rate
- shot usage
- guest-to-host conversion
- people actually wanting to use it again

### V1.5 Pricing Thesis

Simple host-paid model:

| Tier | Price | Use Case |
|---|---:|---|
| Free | £0 | Up to 5 people |
| Small Group | £1.99 | Up to 10 people |
| Bigger Group | £4.99 | 10+ people / higher member cap |

This is intentionally simple.

The product does not need:

- watermarks
- paid downloads
- subscriptions
- guest payments
- individual paid extra shots
- complicated premium features

The monetisation sentence is:

> **10Shots is free for small groups. Hosts pay when the group gets bigger.**

### Future Revenue

Prints are the cleanest future upsell.

Example:

> Print the roll — get 50 event photos delivered.

This fits the disposable camera metaphor and does not damage the digital experience.

---

## Growth Strategy

Growth should come from real events, not daily feed engagement.

### Core Growth Loop

1. Host creates an event.
2. 5–15 friends join.
3. Guests enjoy the live dots and reveal.
4. Photos get shared to group chats and Instagram.
5. Guests think: “I’ll use this for my thing.”
6. Guest becomes host.

### Early GTM

Focus on:

- friend groups
- Manchester
- birthdays
- house parties
- trips
- university/social circles
- local seeding
- TikTok slideshows showing the concept
- App Store screenshots that explain the mechanic in 3 seconds

### Share Strategy

No watermarks in V1.

Sharing should be easy because every shared shot is marketing.

---

## Product Principles

1. **The constraint is the product.** Never dilute the 10-shot mechanic without a very strong reason.
2. **The lobby is the game board.** The dots make the event feel alive.
3. **The reveal is the emotional payoff.** The app should become nostalgic after the event.
4. **Host pays, guests play.** Never make guests hit a payment wall.
5. **No social network creep.** No feed, followers, DMs, or public profiles.
6. **Tasteful gamification only.** Dots, pressure, anticipation. No fake engagement loops.
7. **Ship before over-polishing.** The market needs to vote.
8. **Backend names do not matter.** Public brand can be 10Shots while internals remain Momento.
9. **Sharing stays easy.** No watermark or export friction in V1.
10. **Simple beats clever.** If it makes the app harder to explain, cut it.

---

## Anti-Features

Do not build these unless the product clearly demands them later:

- Public profiles
- Followers
- Explore feed
- DMs
- Comments
- Chat inside events
- Individual paid extra shots
- Infinite photos
- Photo editing tools
- Beauty filters
- Public leaderboards
- Complex event themes
- Large-scale event admin tools
- Wedding-specific workflows
- Watermarked exports in V1

Private “My Rolls” may be considered later, but it should be nostalgic and personal, not public/social.

---

## Metrics That Matter

| Metric | Why |
|---|---|
| **Average shots used per person** | Tests whether the 10-shot mechanic is engaging. |
| **% of users taking at least 1 shot** | Tests participation. |
| **% of users using 7+ shots** | Tests strength of the constraint. |
| **Reveal open rate** | Tests whether people care about the payoff. |
| **Time to first shot** | Tests whether onboarding/lobby creates action. |
| **Events created by former guests** | Core viral/growth metric. |
| **Average event size** | Helps validate pricing tiers. |
| **Share actions after reveal** | Measures organic distribution. |
| **Paid conversion by event size** | Future pricing validation. |
| **Print interest after reveal** | Future physical product validation. |

---

## V1 Ship Scope

### Must Ship

- Public rebrand to 10Shots
- App display name/icon/splash adjusted
- 10-shot limit
- Event terminology in UI
- Lobby/event card with people + dots
- Current user pinned at top
- Shot counts per member
- Camera opens from live card
- Reveal flow still works
- Done pile/basic past event list
- Likes/save/share still work
- No backend rename
- No watermark
- No monetisation required for launch

### Should Ship If Easy

- Dot animations
- “That’s a wrap” final-shot moment
- Better invite copy
- Cleaner App Store screenshots
- Basic analytics events

### Explicitly Post-Launch

- Paid tiers
- Print packs
- Web album polish
- Private My Rolls profile
- Push notifications
- Batch save/download
- 30-day retention
- Host analytics
- Wider B2B/event packages

---

## 2-Week Sprint Focus

The sprint has one job:

> **Make 10Shots obvious, social, and shippable.**

### Week 1: Core Product

- Finalise state simplification
- Build member + shot count query
- Build lobby card with dots
- Wire lobby into home screen
- Update terminology
- Remove old Momento-facing copy where visible

### Week 2: Rebrand + Ship

- App name/icon/splash
- Dot branding pass
- Final UX polish
- Device testing
- App Store assets
- Submit

No identity spiral. No backend rename. No new product philosophy.

---

## Long-Term Vision

10Shots can become a small, profitable lifestyle business first.

The goal is not necessarily to become a huge VC-backed social network. The first meaningful business milestone is:

> A simple app that people use at real events, generating enough paid events and print orders to reach meaningful monthly revenue.

The upside case is that 10Shots becomes a party/friend-group craze. But the base case is already valuable:

- small team
- low overhead
- simple product
- clear paid model
- strong brand mechanic
- real-life usage
- enough revenue to buy back time and live more intentionally

---

## Final North Star

> **10Shots is the disposable camera game where everyone gets 10 photos. The lobby makes it social. The reveal makes it emotional.**
