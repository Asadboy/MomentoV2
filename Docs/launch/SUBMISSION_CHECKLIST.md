# 10shots v1.0 — Ordered Pre-Submission Checklist

Single run-through. Do these **in order** — later steps depend on earlier ones.
All copy/values are pulled from `APP_STORE_COPY.md` and `APP_REVIEW_NOTES.md`;
this file is the driver, those are the source of truth for exact text.

> **All code/repo work is done and on `main`.** Everything below is operator
> action in Xcode, App Store Connect (ASC), the Supabase dashboard, or Vercel.

---

## 0. CRITICAL — build a fresh archive (do this first, it gates everything)

- [ ] **Do NOT submit the previously-uploaded `1.0.0 (49)`.** It predates the
      B1 content-reporting code (#58) and the #59 privacy fix. The App Review
      notes tell Apple *"every photo has an in-app Report action"* — if the
      binary lacks it, that is an instant **Guideline 1.2** rejection and a
      false statement to the reviewer.
- [ ] Confirm local `main` is current: `git -C /Users/asad/MomentoV2 fetch && git -C /Users/asad/MomentoV2 log --oneline -1 origin/main` → should be the `#61` commit or later.
- [ ] In Xcode: bump build number to **50** (keep version **1.0.0**), select
      *Any iOS Device*, **Product → Archive**.
- [ ] Xcode Organizer → **Distribute App → App Store Connect → Upload**.
      A *"Sentry.framework dSYM"* warning on upload is **benign** — not a
      failure, not a blocker. Proceed.
- [ ] Wait for the build to finish *Processing* in ASC (TestFlight tab) before
      step 6.

---

## 1. Supabase dashboard

- [ ] **Auth → Password security → enable "Leaked password protection".**
      (Tracked in BACKLOG; do before submit.)
- [ ] **Wipe beta/test data** so the reviewer and first real users don't see
      junk events/photos. Keep only what you deliberately pre-seed in step 4.

---

## 2. Vercel dashboard (not a hard Apple gate, but do it now)

- [ ] **Domains → make the apex `10shots.app` the primary domain** (currently
      `10shots.app` 307-redirects to `www`). This lets Apple validate the AASA
      at the apex so invite/Universal Links open in-app. The AASA file itself
      is already correct and live.

---

## 3. App Store Connect — App Privacy

Re-verify against the **corrected** table in `APP_STORE_COPY.md` (the #59 audit
changed it — display name moved to User ID, a Diagnostics row added, free-text
removed from analytics). For **every** data type: **Linked to identity = Yes**,
**Used for tracking = No** ("Data is not used to track you").

- [ ] Contact Info → **Email Address** — App Functionality
- [ ] User Content → **Photos or Videos** — App Functionality
- [ ] User Content → **Other User Content** (profile photo) — App Functionality
- [ ] Identifiers → **User ID** (account UUID + display name) — App Functionality, Analytics
- [ ] Usage Data → **Product Interaction** (PostHog) — Analytics
- [ ] Diagnostics → **Crash Data** (Sentry) — App Functionality
- [ ] Diagnostics → **Performance Data** (Sentry) — App Functionality
- [ ] Diagnostics → **Other Diagnostic Data** (PostHog errors) — App Functionality, Analytics
- [ ] Confirm **nothing else** is added (no Location, Contacts, Advertising, Purchases…).
- [ ] Sanity-check it doesn't contradict `https://10shots.app/privacy`.

---

## 4. Demo account (mandatory — SIWA/Google-only auth = #1 rejection cause)

- [ ] Create a fresh Apple ID (a `+review` Gmail alias is fine).
- [ ] Sign into 10shots on a device with it; onboarding display name **`App Review`**.
- [ ] Pre-seed: create one event with a wide window + take 3–4 shots; optionally
      a second event whose reveal time has already passed (gallery viewable).
- [ ] ASC → **App Review Information → Sign-In Information**: tick *Sign-in
      required*; Username = the demo Apple ID email; Password = its password;
      Notes = *"Tap 'Continue with Apple' and use these credentials."*

---

## 5. App Store Connect — metadata (paste from `APP_STORE_COPY.md`)

- [ ] **Name:** `10shots`
- [ ] **Subtitle:** `10 photos each. Reveal later.`
- [ ] **Promotional Text** / **Description** / **Keywords** / **What's New** — paste the fenced blocks
- [ ] **Support URL:** `https://10shots.app/support`
- [ ] **Marketing URL:** `https://10shots.app`
- [ ] **Primary Category:** Photo & Video · **Secondary:** Social Networking
- [ ] **Made for Kids:** No
- [ ] **Age Rating:** answer the questionnaire honestly (don't pre-pick; UGC + moderation typically lands 12+)
- [ ] **Content Rights:** no third-party content (confirm any bundled fonts/audio are licensed)
- [ ] **Export Compliance:** standard encryption (HTTPS/TLS) → **exempt**, no ERN
- [ ] **Screenshots:** upload the 5 from `Docs/launch/screenshots/` in order
      (`01-cover` → `05-create`) into the **6.9″** slot
- [ ] **App Review Notes:** paste the block from `APP_REVIEW_NOTES.md`
      (includes the closed-group + in-app Report / auto-hide paragraph)

---

## 6. Final submit

- [ ] Build **`1.0.0 (50)`** finished Processing → select it on the version page
- [ ] Re-read the App Review notes vs. the actual selected build (Report action present?)
- [ ] **Add for Review → Submit**

---

## After submission

- First-review SLA is typically 24–48h (longer for new accounts / UGC).
- If rejected: fix the specific concern, resubmit, don't argue — replies
  usually unblock in 12–24h. See `APP_REVIEW_NOTES.md` → "After submission".

---

### Already done (no action — for confidence)

B1/B2/B3 code (#58) · App Review notes paragraph · app icon (verified) ·
PostHog/privacy-label fixes (#59) · Xcode Cloud CI script (#60) ·
live Terms clause at `10shots.app/terms` (website #5) · privacy/support URLs ·
listing copy · screenshots · in-app account deletion · Sentry (device-verified).
