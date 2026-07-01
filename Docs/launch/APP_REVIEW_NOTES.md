# App Review Notes — paste-ready

> The "App Review Information" panel in App Store Connect takes a free-form
> note for the reviewer. The block below is final copy — paste it as-is.
> **Two things must be done in App Store Connect before/at submission** — see
> "Required actions" first.

---

## Required actions before submission (not optional)

1. **Demo Apple ID is mandatory.** The app only accepts Sign in with Apple and
   Sign in with Google — there is no email/password path, so the reviewer
   cannot sign in without credentials. Create a dedicated Apple ID, sign into
   10shots once on a device with it (complete onboarding, display name
   "App Review"), then enter it in **App Store Connect → App Review
   Information → Sign-In Information** (tick *Sign-in required*; Username =
   the demo Apple ID email; Password = its password; Notes = "Tap 'Continue
   with Apple' and use these credentials."). Refresh demo content before each
   submission so the reveal flow has something to show.
2. **Answer the questionnaires honestly in App Store Connect** (not in this
   doc): Age Rating, Content Rights, and Export Compliance. Guidance is in
   `APP_STORE_COPY.md` → Categorisation.

---

## App Review Notes (paste into App Store Connect)

```
Thanks for reviewing 10shots.

10shots is a disposable-camera-style photo app for small friend groups. The mechanic: every member of an event gets exactly 10 photos during the event window; nobody can see any photos until the event ends and the reveal window unlocks. There is no public feed, no global directory of events, and no follower system. Every event is a private, code-joined group.

— HOW TO SIGN IN —

10shots supports Sign in with Apple and Sign in with Google only. There is no email/password path. Please use the demo Apple ID provided in the Sign-In Information section: on the sign-in screen, tap "Continue with Apple" and enter those credentials. You are also welcome to use your own Apple ID — there is no allow-list. If you need a Google test account instead, reply on this thread and we will provide one.

— HOW TO TEST —

1. Sign in with the demo Apple ID (Sign-In Information section).
2. Complete onboarding by entering a display name (a profile photo is optional).
3. From the home screen, tap "Create an event."
4. Name it and pick a start time a few minutes out for fastest testing. End time is 12 hours after start; reveal is 24 hours after start.
5. When the event goes live, tap the event card to open the camera and take up to 10 photos.
6. To see the reveal without waiting, create a second event whose reveal time is a few minutes after its end time.

— DATA & PRIVACY —

• Photos and account data are stored in our Supabase project in the EU (Ireland, eu-west-1).
• Accounts are created via Sign in with Apple or Google. We store a user-chosen display name (shown to other members of an event) and an optional profile photo. Apple's Hide My Email relay is supported.
• PostHog is used for product analytics, tied to an internal user ID only — no IDFA, no advertising tracking, no cross-app tracking.
• Sentry is used for crash reporting (anonymous device/OS info, no photo content).
• Photos in an event are visible only to the other members of that event. There is no global gallery or public sharing surface in the app; users may share a specific photo out via the system share sheet.

Camera and Photo Library permissions are required because taking and (optionally) saving photos is the app's core function.

— CONTENT & MODERATION (Guideline 1.2) —

10shots is a closed-group app: there is no public feed and no event discovery. An event is private and joinable only via a code or invite link the creator shares directly, so photos are confined to a small, self-selected group. Every photo has an in-app Report action (long-press a shot). Reporting a photo immediately hides it from all members pending review and flags it to us for action; the reporter never sees that photo again, including after a reinstall. Users can also delete their own photos at any time. Our Terms (https://10shots.app/terms) prohibit unlawful, infringing, or objectionable content and abusive behaviour with zero tolerance, and let us remove content and suspend or terminate accounts at our discretion. There is no persistent social graph (no profiles to browse, no followers, no messaging), so the closed-group model itself serves as the blocking mechanism: an abusive user is excluded by not being invited to future events, and events themselves are time-bound and expire.

— ACCOUNT REQUIREMENT (Guideline 5.1.1(v)) —

An account is required because each photo must be attributable to a specific person within an event for the "10 shots per person" mechanic and the shared reveal to work. Account deletion is available in-app at Profile → Delete Account → confirm; it permanently removes the user's profile, their photos, events they created, their memberships, and their auth record.

— NO PURCHASES, NO ADS —

This version has no in-app purchases, no subscriptions, and no advertising.

— CONTACT —

Reviewer questions: asad.amjid@gmail.com
Production support: asad.amjid@gmail.com / https://10shots.app/support
```

*≈3,700 characters. App Store Connect allows 4,000.*

---

## Pre-seeding the demo account (recommended)

Because the reveal is the core payoff, give the reviewer something to reveal:

1. On a device signed into the demo Apple ID (display name "App Review"),
   create one event with a wide window — starts now, ends in ~7 days, reveal
   ~8 days out — and take 3–4 shots in it.
2. Optionally create a second event whose reveal time has already passed so
   the post-reveal gallery is viewable immediately.
3. Refresh this content before every resubmission.

---

## Things Apple commonly trips on for apps like this

| Concern | Status / mitigation |
|---|---|
| **5.1.1 — Sign in with Apple** | Offered as a primary option alongside Sign in with Google. No email/password path. ✓ |
| **5.1.1(v) — Account deletion** | Shipped: Profile → Delete Account → confirm; calls the `delete_my_account()` SECURITY DEFINER RPC that atomically removes photos, events created, memberships, profile, and the `auth.users` row. ✓ |
| **1.2 — UGC moderation** | Closed-group invite model (no public feed/discovery). Every photo has an in-app Report action that immediately hides the photo for everyone on report and flags it for operator review (PostHog `photo_reported`); users can also self-delete. Terms prohibit objectionable content with zero tolerance and grant content-removal/termination rights. Explained proactively in the notes above. ✓ |
| **5.1.2 — Data minimisation** | Only Camera + Photo Library requested, used solely for app function. No location, contacts, microphone. ✓ |
| **2.5.13 — Sign-in for cosmetic features** | Sign-in gates the core function (events), not a cosmetic feature. ✓ |

**Most likely rejection cause if submitted today:** the demo Apple ID in the
Sign-In Information panel being missing or not working. Verify it signs in
cleanly on a fresh device before submitting — with SIWA/Google-only auth, a
broken demo credential is a guaranteed rejection.

---

## After submission

Apple's typical first-review SLA is 24–48 hours (longer for new accounts or
UGC apps). If no decision in 72 hours, check the Resolution Center. If
rejected, fix the specific concern and resubmit — don't argue, even if you
disagree; replies usually unblock in 12–24 hours.
