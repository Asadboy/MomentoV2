# App Review Notes (draft)

> The "App Review Information" panel in App Store Connect lets you write a free-form note for the Apple reviewer. A good note shortens the review and reduces the odds of a rejection on a misunderstanding. This is the draft to paste in.

---

## App Review Notes (paste into App Store Connect)

```
Thanks for reviewing 10shots.

10shots is a disposable-camera-style photo app for small friend groups. The mechanic: every member of an event gets exactly 10 photos during the event window; nobody can see the photos until the event ends and a 24-hour reveal window unlocks. There is no public feed, no global directory of events, no follower system. Each event is a private, code-joined group.

— HOW TO TEST —

You can fully test the app without any special credentials:

1. Sign in with Apple, Google, or email/password (the app accepts any valid email for sign-up).
2. From the home screen, tap "Create an event."
3. Give it a name, then pick a start time within the next few minutes for fastest testing. The end time is 12 hours after start; the reveal time is 24 hours after start.
4. Once "live," tap the event card to open the camera. Take up to 10 photos.
5. To test the reveal flow without waiting 24 hours, you can create a second event with a release time a few minutes after the end time.

If you'd prefer a pre-populated demo account, please reply on this thread and we'll provide credentials.

— DATA & PRIVACY —

• Photos are stored in our Supabase project (EU region, eu-west-1).
• User accounts are managed by Supabase Auth. We do not collect names beyond a chosen username.
• We use PostHog for product analytics (no PII beyond an internal user ID, no IDFA, no advertising tracking).
• We use Sentry for crash reporting (anonymous device info, no PII).
• Photos taken within an event are visible only to other members of that event. There is no global gallery and no public sharing surface inside the app — users can share specific photos out via the system share sheet if they choose.

The Camera and Photo Library permissions are required because the app's core function is taking and (optionally) saving photos.

— ACCOUNT REQUIREMENT (Apple Guideline 5.1.1(v)) —

An account is required because each photo must be attributable to a specific person within an event for the "10 shots per person" mechanic to work, and because the reveal window depends on identifying who has revealed which event. We offer Sign in with Apple alongside Google and email.

— NO PURCHASES, NO ADS —

This version contains no in-app purchases, no subscriptions, and no advertising.

— CONTACT —

Reviewer questions: [your email here]
Production support: [support email or URL once live]
```

*Approximately 2,400 characters. App Store Connect allows up to 4,000.*

---

## Demo account (if reviewers ask)

If you want to provide a pre-seeded demo account so the reviewer doesn't have to create an event with a near-future start time:

1. Sign up a dedicated `appstore-reviewer@10shots.app` account
2. Pre-create one event with a wide live window (e.g., starts immediately, ends in 7 days, reveal 8 days from now)
3. Take 3–4 demo shots so the reveal flow has content
4. Put the credentials in the "Sign-in Information" section of App Store Connect (Apple stores these privately)

This is optional — most photo apps don't bother and rely on the "test in real time" path above. Worth doing if your first submission gets rejected for "couldn't verify the reveal flow."

---

## Things Apple commonly trips on for apps like this

| Concern | Mitigation |
|---|---|
| **5.1.1 — Sign in with Apple** | We offer it as a primary option alongside Google + email. ✓ |
| **5.1.1(v) — Account deletion** | **NOT YET WIRED.** Apple requires in-app account deletion for apps that allow account creation. Currently the user can sign out but not delete. **Add before submission** — a "Delete my account" option in ProfileView that calls a Supabase RPC to soft-delete the user and their events. |
| **1.2 — UGC moderation** | We have a per-photo "flag" mechanism (`flagPhoto`) and the user can delete their own photos. Document this in the response if reviewer asks. |
| **5.1.2 — Data minimisation** | We only request Camera + Photo Library and only use them for app function. No location, contacts, microphone, etc. |
| **2.5.13 — Sign-in for cosmetic features** | We require sign-in for the core function (events). Not a cosmetic feature. Should pass. |

**Most likely rejection cause if submitted today:** missing in-app account deletion (5.1.1(v)). Wire that before submitting — it's a half-day of work that prevents a guaranteed rejection.

---

## After submission

Apple's typical review SLA is 24–48 hours for first-time submissions, sometimes longer for new accounts or apps with UGC. Set a Slack reminder for 72 hours; if no decision by then, check the Resolution Center for messages.

If rejected, replies usually unblock in 12–24 hours. Don't argue — fix the specific concern and resubmit, even if you disagree.
