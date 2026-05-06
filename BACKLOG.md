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
- [x] **Wire `member_limit` in app** — default 10, NOT NULL, RLS-enforced cap on join; client surfaces "This event is full" error. Future monetisation tiers will write a different value per event.
- [x] **Audit unused indexes** — dropped `idx_photos_pending` (genuinely dead; nothing queries by `upload_status = 'pending'`). Kept the 5 `events` indexes: they're flagged "unused" only because the table has ~7 rows, but each covers a real query path that will activate as the table grows.

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

- [x] Drop polling to 30s for non-live events (10s when something is live, 30s otherwise)
- [ ] Internal rename `CreateMomentoFlow` → `CreateEventFlow` (deferred per CLAUDE.md — internal-only churn)

---

*Anything below the App Store submission line is also fair game pre-launch but won't block ship.*
