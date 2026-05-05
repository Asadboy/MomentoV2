# 10shots — Ship Checklist

## State Machine Simplification
- [x] Remove `processing` state from `Event.swift`
- [x] Update `currentState()` to return 3 states: `upcoming`, `live`, `revealed`
- [x] Update `ContentView.swift` — remove all `processing` / `readyToReveal` references
- [x] Update `PremiumEventCard.swift` — remove processing/readyToReveal UI branches
- [x] Update `PastEventCard.swift` — remove processing state handling
- [x] Handle the gap between `endsAt` and `releaseAt` as part of `revealed` state with "Reveals in X" countdown
- [ ] Test all state transitions on device

## Remove Emoji
- [x] Remove emoji picker from `CreateMomentoFlow.swift` (check if it still exists there) — confirmed: never existed in current code
- [x] Remove `coverEmoji` from `Event.swift` model
- [x] Remove emoji display from all card components
- [x] Update create flow UI — just name + time pickers (already was this way)
- [ ] Test create flow end-to-end

## Dead Code Cleanup (partially done)
- [x] Remove `PremiumEventCard.swift` (replaced by EventCard)
- [x] Remove `processing` case from all switch statements
- [x] Remove `readyToReveal` UI code
- [x] Remove emoji-related helpers and assets (coverEmoji references)
- [x] Remove stale `member_count` / `photo_count` column reads (already bypassed in earlier bug fix commits)
- [x] Update `EventsScreenPreview.swift` for new states (removed dead preview events)

## People-Dots Card (Core Feature)
- [x] Create new `getEventMembersWithShots()` query in `SupabaseManager.swift` — joins event_members + profiles + photo counts
- [x] Create `MemberWithShots` model struct (userId, username, displayName, avatarUrl, shotsTaken)
- [x] Build new `EventCard.swift` component (replaces `PremiumEventCard.swift`)
  - [x] Event name header + state badge (countdown / LIVE / Reveals in X)
  - [x] People list rows: avatar + name + 10 dots
  - [x] Current user pinned to top
  - [x] Remaining members sorted by shots taken (descending)
  - [x] Invite button within the people list
  - [x] Tap card → open camera (live state)
  - [x] Tap card → open reveal (reveal state)
- [x] Wire into `ContentView.swift` — replace `PremiumEventCard` usage
- [x] Front-and-centre layout — active event dominates the screen, not a grid
- [x] Store `userPhotoCounts` per member (not just current user) for dot display
- [ ] Test with 1, 3, 5 people on real device

## Real-time Dot Updates
- [x] Tighten polling to 10s for live events (was 15s)
- [x] `refreshEventCounts()` fetches all member shot counts (not just current user)
- [x] Dots update on card without full reload (via `eventMembers` state + optimistic updates)
- [ ] Test: take a shot on one device, see dot fill on another within 10s

## Terminology Pass
- [x] UI strings: "momento" → "event" everywhere
- [x] UI strings: "photo" / "photos" → "shot" / "shots" everywhere
- [ ] File/class rename: `CreateMomentoFlow` → `CreateEventFlow` (deferred — low priority, internal only)
- [x] Update debug logs and analytics event names
- [x] Update any user-facing error messages
- [x] Don't rename internal code variables unless it's in UI-facing strings (save time)

## Aggregate Like Counts
- [ ] Add query: total likes across all members for an event's shots
- [ ] Add query: total shots count for event
- [ ] Display on done pile cards: "34 shots, 72 likes from 5 people"
- [ ] Ensure each member's likes count toward event total independently
- [ ] Test: 2 users like same shot = 2 likes on event total

## Done Pile
- [ ] Keep existing done pile layout (list of past events)
- [ ] Add event stats to each done card (shots, likes, people count)
- [ ] Tap → opens liked gallery (existing behaviour)
- [ ] No re-reveal — once done, gallery only

## Reveal Flow Updates
- [ ] Ensure reveal shows shots chronologically (already does)
- [ ] Ensure "Shot by [username]" is displayed (already does)
- [ ] Update terminology in reveal UI: "photo" → "shot"
- [ ] Verify like/unlike sync works (fixed in recent commits)
- [ ] After reveal completion, event moves to done pile correctly

## Polling and Performance
- [x] 10s polling during live events
- [ ] 30s polling for non-live events (currently 10s for all — acceptable for now)
- [x] `getEventMembersWithShots()` — 1 query for members+profiles, parallel count queries per member
- [ ] Test battery/network impact of 10s polling

## Rebrand to 10shots
- [ ] App Store display name → "10shots"
- [ ] Update splash/launch screen
- [ ] Update app icon (if text on icon)
- [ ] Update any in-app references to "Momento" in user-facing copy
- [ ] Update Info.plist display name

## Schema / Backend
- [ ] Add `member_limit` column to events table (default 5, for future use)
- [ ] Verify `getEventMembersWithShots()` query works in Supabase
- [ ] No other table changes needed

## Final Testing
- [ ] Create event → card appears with host avatar + 10 empty dots
- [ ] Join event → new member appears on card with empty dots
- [ ] Take shots → dots fill on card
- [ ] Other member's dots update within 10s
- [ ] Event ends → card shows "Reveals in X"
- [ ] Reveal time arrives → "Reveal your 10shots" CTA appears
- [ ] Reveal flow → chronological, shows usernames, like/skip works
- [ ] After reveal → event in done pile with stats
- [ ] Liked gallery → shows liked shots, download/share works
- [ ] Offline: take shot offline → syncs when back online
- [ ] Edge case: all 10 shots used → camera locks correctly

## App Store Submission
- [ ] Screenshots for App Store listing
- [ ] App description / subtitle
- [ ] Privacy policy URL
- [ ] App review notes
- [ ] Submit to App Store Connect
