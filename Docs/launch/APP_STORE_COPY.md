# App Store Connect — Listing Copy (draft)

> Drafts of every text field in the App Store Connect listing. These are starting points written from VISION.md framing — please edit liberally before submission. Character limits are noted next to each field. Anything in `[brackets]` is a placeholder to fill in.

---

## App Name (30 chars max)

```
10shots
```
*7 chars — exact match for CFBundleDisplayName.*

---

## Subtitle (30 chars max)

Pick one:

```
10 photos each. Reveal later.
```
*30 chars — leads with the mechanic.*

```
Disposable camera, together.
```
*28 chars — leads with the feel.*

```
A disposable camera game.
```
*25 chars — leads with the genre.*

**Recommended:** the first one. It explains the product in five words.

---

## Promotional Text (170 chars — editable without re-review)

```
Everyone gets 10 shots. No previews, no retakes. Photos unlock tomorrow. Made for parties, trips, and weekends with the people who matter.
```
*138 chars.*

Use this field to swap in seasonal angles later (e.g. "Festival season — 10 shots a day, revealed Monday morning").

---

## Description (4000 chars max — primary listing copy)

```
10shots is a disposable camera game for your favourite people.

Everyone in the group gets exactly 10 photos. No previews. No retakes. The whole roll reveals together when the night's over.

It's the constraint that makes it fun. Ten shots forces you to be a little more deliberate, a little more present, and a lot less buried behind your phone screen. The lobby shows who's still got shots left and who's spent them — a quiet game inside the night.

— HOW IT WORKS —

Create an event. Pick when it starts and ends. Share a 6-letter code.

Friends join from the code or a tap. Everyone shows up in the lobby with ten empty dots. The shots fill in as the night goes on.

When the event ends, the camera locks. The next day, the reveal unlocks and you see everyone's roll for the first time, together.

Like the ones you love. Save your favourites. Share them outside the app if you want.

— WHO IT'S FOR —

• Birthdays and house parties
• Weekend trips and city breaks
• Festivals and camping
• Family Christmas
• Pre-drinks and dinners with friends
• Anywhere a group is going to make a memory together

— WHAT IT'S NOT —

10shots is not a social network. There's no public feed, no follower count, no algorithm. It's just a roll of photos for a moment in your life with a specific group of people.

— BUILT FOR INTENTIONAL PHOTOS —

Every shot you take counts because you only get ten. The photos that come back tend to be the moments worth keeping. No more endlessly scrolling through 200 near-duplicate photos to find the one you actually liked.

Try it on the next night that matters.
```

*~1,500 chars including section breaks — well within the limit, with room to grow.*

---

## Keywords (100 chars max, comma-separated)

```
disposable,camera,photos,friends,group,party,reveal,event,share,memories,roll,polaroid,social,fun
```
*100 chars. Lowercase, no spaces between (Apple strips spaces anyway and counts them).*

Notes on keyword choice:
- `disposable camera` is the genre we want to own
- `polaroid` because users search for the analogue feel
- `reveal` is the differentiator
- Avoided `instagram`, `bereal`, etc. — Apple flags brand names
- Avoided `drinking`, `shots` (alcohol-adjacent) per VISION.md

---

## What's New (4000 chars — release notes for each version)

### Version 1.0

```
Welcome to 10shots — the disposable camera game for your favourite people.

This is the first release. Everyone gets 10 shots, the lobby shows the roll filling up, and the whole event reveals the next day.

If you have a moment coming up that matters — a birthday, a weekend away, a Christmas dinner — try it then. That's exactly what it's made for.

Bug reports and feature requests welcome: [contact email TBD].
```

---

## Categorisation

| Field | Recommended |
|---|---|
| **Primary Category** | Photo & Video |
| **Secondary Category** | Social Networking |
| **Age Rating** | 12+ (Infrequent/Mild Mature/Suggestive Themes — to leave room; user-generated content needs at least this) |
| **Content Rights** | "Does not contain, show, or access third-party content" — **double check** before submission, depends on whether reveal music / fonts are licensed |
| **Made for Kids** | No |

**Age rating note:** Apple requires user-generated content apps to be rated at least 17+ in some interpretations, but most photo-sharing apps land at 12+. Check the questionnaire honestly — if you say "moderation in place," you can usually stay at 12+.

---

## Support URL

```
[TBD — needs hosted page or a "support" email link]
```

Cheap option: a one-page Notion or Squarespace site at `10shots.app/support` once the domain is bought.

---

## Marketing URL (optional)

```
[TBD — same as Support URL or the main 10shots.app landing]
```

---

## Localisations

Launch in **English (US)** only. Add other locales post-launch based on where users come from organically.

---

## Screenshots (separate task — needs device)

The required iPhone screenshot sizes per Apple's current spec: **6.7" display** (iPhone 14 Pro Max / 15 Pro Max / 16 Pro Max / 17 Pro Max equivalent) — minimum 3, recommended 5–10.

Recommended capture order:
1. **Empty hero** — "Start your first event" landing (clean, sells the brand)
2. **Lobby with full roster** — the EventHeroView with mid-game dots (the visual signature)
3. **Camera mid-shot** — the act of taking a shot with the shutter polish
4. **Reveal stack** — first reveal moment with a polaroid
5. **Past events** — the done-pile aggregate likes

Each can carry a single bold caption overlay if desired. Suggested captions:
- "Everyone gets 10."
- "Watch the roll fill up."
- "Shoot first, look later."
- "Reveal together."
- "Keep the moments worth keeping."

---

## Things still missing before submission

- [ ] Sentry DSN pasted into `Secrets.xcconfig` (so launch builds report crashes)
- [ ] Privacy policy URL — needs hosting (placeholder is `yourmomento.app/privacy` in SignInView)
- [ ] Terms of service URL — same situation
- [ ] App icon — final 1024×1024 plus all required sizes
- [ ] Screenshots — capture on device per list above
- [ ] Support URL / contact email
- [ ] Submit

See `Docs/launch/APP_REVIEW_NOTES.md` for what to write in the App Review Information panel.
