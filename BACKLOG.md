# 10shots — Backlog

Active, launch-blocking work only. Anything aspirational lives in `VISION.md`.

---

## Blocking App Store submission

- [ ] **Real privacy policy URL** — replace `https://yourmomento.app/privacy` placeholder in `Momento/Features/Auth/SignInView.swift`
- [ ] **Real terms of service URL** — replace `https://yourmomento.app/terms` placeholder in `SignInView.swift`
- [ ] **App icon** — final design
- [ ] **App Store screenshots** — capture set covering create, live event with shot counter, reveal, gallery
- [ ] **App Store listing copy** — name, subtitle, keywords, description, category
- [ ] **App review notes** — explain camera permission, photo storage, why 10 shots
- [ ] **Submit to App Store Connect**

## Pending external dependency

- [ ] **Buy `10shots.app` domain**
- [ ] **Wire `10shots.app/join/<code>`** — once domain is live, point invite QR + share message at it (currently a placeholder in `Momento/Components/InviteContentView.swift`)
- [ ] **Universal Link / deep link** for `10shots.app/join/<code>` — replaces legacy `momento.app/join/` parsing in `JoinEventSheet.swift`

## Supabase / backend

- [ ] **Enable leaked-password protection** (Supabase dashboard → Auth → Password security toggle)
- [ ] **Wire `member_limit` in app** — column exists on `events` table (default null) but not yet enforced or displayed; decide UX before launch or defer
- [ ] **Audit unused indexes** — `idx_events_creator/join_code/release_at/starts_at/ends_at`, `idx_photos_pending` flagged as unused. The `join_code` one is suspicious since lookups go through a SECURITY DEFINER function; verify before dropping.

## On-device verification (developer-side QA)

- [ ] All event state transitions on device (upcoming → live → revealed)
- [ ] Create flow end-to-end
- [ ] Join flow via QR and via 6-char code
- [ ] Multi-device dot updates within 10s polling window
- [ ] Two users like the same shot → event total shows 2
- [ ] Battery / network impact of 10s polling during a long live event
- [ ] All-10-shots-used → camera locks correctly
- [ ] Offline shot capture syncs on reconnect

## Nice to have (not blocking)

- [ ] Drop polling to 30s for non-live events (currently 10s for all)
- [ ] Internal rename `CreateMomentoFlow` → `CreateEventFlow` (deferred per CLAUDE.md — internal-only churn)

---

*Anything below the App Store submission line is also fair game pre-launch but won't block ship.*
