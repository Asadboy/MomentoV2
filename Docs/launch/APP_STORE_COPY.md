# App Store Connect — Listing Copy (paste-ready)

> Final copy for every App Store Connect text field. Paste the fenced blocks
> as-is. The only judgement calls left are the App Store Connect
> questionnaires (Categorisation section) — those are answered in ASC, not
> here.

---

## App Name (30 chars max)

```
10shots
```
*7 chars — exact match for CFBundleDisplayName.*

---

## Subtitle (30 chars max)

```
10 photos each. Reveal later.
```
*29 chars — leads with the mechanic. (Alternates if you want to swap later:
"Disposable camera, together." / "A disposable camera game.")*

---

## Promotional Text (170 chars — editable without re-review)

```
Everyone gets 10 shots. No previews, no retakes. Photos unlock tomorrow. Made for parties, trips, and weekends with the people who matter.
```
*138 chars. Swap seasonal angles here later without re-review.*

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
• Nights out and dinners with friends
• Anywhere a group is going to make a memory together

— WHAT IT'S NOT —

10shots is not a social network. There's no public feed, no follower count, no algorithm. It's just a roll of photos for a moment in your life with a specific group of people.

— BUILT FOR INTENTIONAL PHOTOS —

Every shot you take counts because you only get ten. The photos that come back tend to be the moments worth keeping. No more endlessly scrolling through 200 near-duplicate photos to find the one you actually liked.

Try it on the next night that matters.
```

*~1,500 chars including section breaks — well within the limit.*

---

## Keywords (100 chars max, comma-separated)

```
disposable,camera,photos,friends,group,party,reveal,event,share,memories,roll,trips,social,fun
```
*94 chars. Lowercase, no spaces (Apple counts spaces, so omit them). Avoids
brand names (instagram/bereal/polaroid) and alcohol-adjacent terms per
VISION.md — `polaroid` removed (registered trademark; Apple rejects 3rd-party
marks in metadata), replaced with `trips`.*

---

## What's New (release notes)

### Version 1.0

```
Welcome to 10shots — the disposable camera game for your favourite people.

This is the first release. Everyone gets 10 shots, the lobby shows the roll filling up, and the whole event reveals the next day.

If you have a moment coming up that matters — a birthday, a weekend away, a Christmas dinner — try it then. That's exactly what it's made for.

Bug reports and feature requests welcome: asad.amjid@gmail.com
```

---

## Categorisation

| Field | Value |
|---|---|
| **Primary Category** | Photo & Video |
| **Secondary Category** | Social Networking |
| **Made for Kids** | No |
| **Age Rating** | Answer the ASC questionnaire honestly — most photo-sharing UGC apps land at **12+** when moderation is in place (per-photo flag + self-delete). Don't pre-select; let the questionnaire compute it. |
| **Content Rights** | ASC asks whether the app contains/accesses third-party content. 10shots only shows user-generated photos, so the answer is normally "does not contain third-party content" — but confirm any bundled fonts/audio in the reveal flow are licensed before answering. |
| **Export Compliance** | The app uses only standard HTTPS/TLS. In ASC this is the "exempt" path (standard encryption) — answer accordingly; no ERN needed. |

---

## Support URL

```
https://10shots.app/support
```
*Live (FAQ + contact). Verified.*

## Marketing URL (optional)

```
https://10shots.app
```
*Live one-pager.*

---

## Localisations

Launch in **English (U.S.)** only. Add locales post-launch based on where
users actually come from.

---

## Screenshots ✅ DONE

Final 5-screenshot set committed at `Docs/launch/screenshots/`
(`01-cover` … `05-create`), all **1320×2868, RGB, no alpha** — valid for the
App Store Connect **6.9″ (iPhone 6.9″ Display)** slot. Upload these in order:

1. `01-cover` — 10Shots / *Your shared disposable camera*
2. `02-lobby` — *Everyone gets 10 shots.*
3. `03-camera` — *No previews. No retakes.*
4. `04-reveal` — *The whole roll. Together.*
5. `05-create` — *Start a roll for any night.*

Copy/narrative detail in `SCREENSHOT_COPY.md`.

---

## Pre-submission status

Done: ✅ onboarding · ✅ in-app account deletion · ✅ Sentry (device-verified) ·
✅ privacy URL (`10shots.app/privacy`) · ✅ terms URL (`10shots.app/terms`) ·
✅ app icon · ✅ this listing copy · ✅ App Review notes
(`APP_REVIEW_NOTES.md`) · ✅ Support/Marketing URLs.

Remaining before you can hit Submit:
- [x] **Screenshots** — final set in `Docs/launch/screenshots/`
- [ ] **Demo Apple ID** in ASC Sign-In Information — *mandatory*, see `APP_REVIEW_NOTES.md` → Required actions
- [ ] **Enable leaked-password protection** (Supabase → Auth toggle)
- [ ] **Upload build 1.0.0 (49)** via Xcode Organizer → select it in ASC
- [ ] **Submit to App Store Connect**

See `APP_REVIEW_NOTES.md` for the reviewer note and the demo-account setup.
