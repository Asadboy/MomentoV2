//
//  EventStore.swift
//  Momento
//
//  Owns all event-related state and side effects for the home screen.
//
//  Lifted out of ContentView (which previously carried 27 @State properties
//  and ~400 lines of business logic). Centralising here means:
//    1. Views don't run network task groups or do optimistic-update
//       reconciliation
//    2. Per-event hydration (members, photos, liked counts, reveal status)
//       has a single source of truth
//    3. The same store can back future screens (event detail, widgets) without
//       duplicating fetch/refresh logic
//
//  Phase 4 of the ContentView split — the seven per-event dictionaries are
//  collapsed into a single [HydratedEvent]. The view layer reads
//  `hydrated.members`, `hydrated.likedCount` etc. instead of dict lookups.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class EventStore: ObservableObject {

    // MARK: - Published State

    /// Source of truth for every event the user belongs to plus all its
    /// hydration. Replaces the seven parallel dicts from Phase 1.
    @Published var hydratedEvents: [HydratedEvent] = []

    @Published var isLoading: Bool = true

    /// Event id that was just joined — drives the 2-second green glow on the
    /// active-events card. Cleared back to nil 2s after a join.
    @Published var newlyJoinedEventId: String? = nil

    /// Error surface for the view to read and show as an alert.
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let api: MomentoAPI
    private let sync = OfflineSyncManager.shared
    private var isRefreshing = false

    /// Tick counter for the 10s refresh timer. When nothing is live we run the
    /// real refresh every 3rd tick (~30s) to save battery — carried over from
    /// the perf optimisation in PR #6.
    private var refreshTickCount = 0

    // MARK: - Init

    /// Inject a `MomentoAPI` to make this store testable. Production callers
    /// rely on the default — `SupabaseManager.shared`. Tests pass a mock.
    init(api: MomentoAPI = SupabaseManager.shared) {
        self.api = api
    }

    // MARK: - Derived

    var currentUserId: String? {
        api.currentUserId?.uuidString
    }

    /// Active events (live / upcoming / unrevealed) shown as featured cards.
    func activeEvents(at now: Date) -> [HydratedEvent] {
        hydratedEvents
            .filter {
                let state = $0.event.currentState(at: now)
                if state == .live || state == .upcoming { return true }
                if state == .revealed && !$0.userHasCompletedReveal { return true }
                return false
            }
            .sorted { a, b in
                let sa = a.event.currentState(at: now)
                let sb = b.event.currentState(at: now)
                func priority(_ s: Event.State) -> Int {
                    switch s {
                    case .live: return 0
                    case .revealed: return 1
                    case .upcoming: return 2
                    }
                }
                let pa = priority(sa)
                let pb = priority(sb)
                if pa != pb { return pa < pb }
                return a.event.startsAt < b.event.startsAt
            }
    }

    /// Past events (completed reveals) shown as compact rows.
    func pastEvents(at now: Date) -> [HydratedEvent] {
        hydratedEvents
            .filter { h in
                h.event.currentState(at: now) == .revealed && h.userHasCompletedReveal
            }
            .sorted { $0.event.releaseAt > $1.event.releaseAt }
    }

    // MARK: - Mutation helpers

    /// Find the HydratedEvent by id and mutate it in place. No-op if not found.
    private func updateHydrated(_ id: String, _ mutate: (inout HydratedEvent) -> Void) {
        guard let idx = hydratedEvents.firstIndex(where: { $0.id == id }) else { return }
        mutate(&hydratedEvents[idx])
    }

    // MARK: - Load

    /// Full reload from server. Debounced so refresh storms don't pile up.
    func loadEvents() async {
        guard !isRefreshing else {
            debugLog("⏳ Already refreshing, skipping duplicate call")
            return
        }
        isRefreshing = true
        isLoading = hydratedEvents.isEmpty
        defer { isRefreshing = false }

        do {
            let models = try await api.getMyEvents()
            let loaded = models.map { Event(fromSupabase: $0) }

            // Build fresh HydratedEvents, preserving any local-only fields
            // (localPhotos and optimistic userPhotoCount) from the previous
            // hydration if the same event still exists.
            let previousById = Dictionary(uniqueKeysWithValues: hydratedEvents.map { ($0.id, $0) })
            var fresh: [HydratedEvent] = loaded.map { event in
                var h = HydratedEvent(event: event)
                if let prev = previousById[event.id] {
                    h.localPhotos = prev.localPhotos
                    h.userPhotoCount = prev.userPhotoCount
                    h.userHasCompletedReveal = prev.userHasCompletedReveal
                }
                if RevealStateManager.shared.hasCompletedReveal(for: event.id) {
                    h.userHasCompletedReveal = true
                }
                return h
            }

            hydratedEvents = fresh
            isLoading = false

            await hydrateActive(loaded: loaded)
            await hydrateRevealed(loaded: loaded)
            await hydrateMembers(loaded: loaded)

            debugLog("✅ Loaded \(models.count) events")
        } catch {
            debugLog("Failed to load events: \(error)")
            isLoading = false
        }
    }

    private func hydrateActive(loaded: [Event]) async {
        let active = loaded.filter { $0.currentState() == .live || $0.currentState() == .upcoming }
        let currentUserId = api.currentUserId

        let results = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
            for event in active {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let m = (try? await self.api.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.api.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    var u: Int? = nil
                    if let uid = currentUserId, event.currentState() == .live {
                        u = (try? await self.api.getPhotoCount(eventId: eventUUID, userId: uid)) ?? 0
                    }
                    return (event.id, m, p, u)
                }
            }
            var out: [(String, Int, Int, Int?)] = []
            for await r in group { out.append(r) }
            return out
        }

        for (id, m, p, u) in results {
            updateHydrated(id) { h in
                h.event.memberCount = m
                h.event.photoCount = p
                if let u { h.userPhotoCount = u }
            }
        }
    }

    private func hydrateRevealed(loaded: [Event]) async {
        let revealed = loaded.filter { $0.currentState() == .revealed }

        let results = await withTaskGroup(of: (String, Int, [PhotoData], Int, Int, Int).self) { group in
            for event in revealed {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let count = (try? await self.api.getLikedPhotoCount(eventId: eventUUID)) ?? 0
                    let photos = (try? await self.api.getLikedPhotos(eventId: eventUUID)) ?? []
                    let totalLikes = (try? await self.api.getTotalLikeCount(eventId: eventUUID)) ?? 0
                    let m = (try? await self.api.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.api.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    return (event.id, count, photos, totalLikes, m, p)
                }
            }
            var out: [(String, Int, [PhotoData], Int, Int, Int)] = []
            for await r in group { out.append(r) }
            return out
        }

        for (id, count, photos, totalLikes, m, p) in results {
            updateHydrated(id) { h in
                h.likedCount = count
                if !photos.isEmpty || h.likedPhotos.isEmpty {
                    h.likedPhotos = photos
                }
                h.totalLikeCount = totalLikes
                h.event.memberCount = m
                h.event.photoCount = p
                if count > 0 || RevealStateManager.shared.hasCompletedReveal(for: id) {
                    h.userHasCompletedReveal = true
                }
            }
        }
    }

    private func hydrateMembers(loaded: [Event]) async {
        let results = await withTaskGroup(of: (String, [MemberWithShots]).self) { group in
            for event in loaded {
                // Skip revealed-and-completed events; they don't need fresh member dots.
                let h = hydratedEvents.first { $0.id == event.id }
                let alreadyDone = (event.currentState() == .revealed) && (h?.userHasCompletedReveal ?? false)
                guard !alreadyDone else { continue }
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let members = (try? await self.api.getEventMembersWithShots(eventId: eventUUID)) ?? []
                    return (event.id, members)
                }
            }
            var out: [(String, [MemberWithShots])] = []
            for await r in group { out.append(r) }
            return out
        }
        for (id, members) in results {
            updateHydrated(id) { $0.members = members }
        }
    }

    // MARK: - Refresh tick (10s)

    /// Called by the view on every 10s timer fire. If something's live we
    /// refresh every tick; otherwise every 3rd tick (~30s) to save battery.
    func refreshTick(at now: Date) async {
        refreshTickCount += 1
        let hasLive = hydratedEvents.contains { $0.event.currentState(at: now) == .live }
        guard hasLive || refreshTickCount % 3 == 0 else { return }
        await refreshCounts()
    }

    /// Silent refresh: re-fetch counts + member dots without redrawing the
    /// loading state.
    private func refreshCounts() async {
        guard !hydratedEvents.isEmpty else { return }
        let currentUserId = api.currentUserId
        let snapshot = hydratedEvents.map { $0.event }

        let countResults = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
            for event in snapshot {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let m = (try? await self.api.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.api.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    var u: Int? = nil
                    if let uid = currentUserId, event.currentState() == .live {
                        u = (try? await self.api.getPhotoCount(eventId: eventUUID, userId: uid)) ?? 0
                    }
                    return (event.id, m, p, u)
                }
            }
            var out: [(String, Int, Int, Int?)] = []
            for await r in group { out.append(r) }
            return out
        }

        for (id, m, p, u) in countResults {
            updateHydrated(id) { h in
                h.event.memberCount = m
                h.event.photoCount = p
                if let u { h.userPhotoCount = u }
            }
        }

        let memberResults = await withTaskGroup(of: (String, [MemberWithShots]).self) { group in
            for event in snapshot where event.currentState() == .live || event.currentState() == .upcoming {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let members = (try? await self.api.getEventMembersWithShots(eventId: eventUUID)) ?? []
                    return (event.id, members)
                }
            }
            var out: [(String, [MemberWithShots])] = []
            for await r in group { out.append(r) }
            return out
        }
        for (id, members) in memberResults {
            updateHydrated(id) { $0.members = members }
        }
    }

    // MARK: - Mutations

    func appendCreatedEvent(_ event: Event) {
        hydratedEvents.append(HydratedEvent(event: event))
    }

    /// A user just joined an event via the join sheet. Triggers the 2-second
    /// green glow on the card, then clears it.
    func joinedEvent(_ event: Event) {
        newlyJoinedEventId = event.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            hydratedEvents.append(HydratedEvent(event: event))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.newlyJoinedEventId = nil
            }
        }
    }

    func deleteEvent(_ event: Event) async {
        guard let uuid = UUID(uuidString: event.id) else { return }
        do {
            try await api.deleteEvent(id: uuid)
            hydratedEvents.removeAll { $0.id == event.id }
        } catch {
            debugLog("Failed to delete event: \(error)")
        }
    }

    func markRevealCompleted(eventId: String) {
        updateHydrated(eventId) { $0.userHasCompletedReveal = true }
        RevealStateManager.shared.markRevealCompleted(for: eventId)
    }

    func clearRevealCompleted(eventId: String) {
        updateHydrated(eventId) { $0.userHasCompletedReveal = false }
        RevealStateManager.shared.clearRevealCompleted(for: eventId)
    }

    // MARK: - Photo capture

    /// Handles a captured photo: stores locally, queues for upload, and applies
    /// an optimistic shot-count bump. Reconciles against the server 3 seconds
    /// later once the upload has had time to settle.
    func handlePhotoCaptured(_ image: UIImage, for event: Event) {
        guard let eventUUID = UUID(uuidString: event.id) else {
            debugLog("Invalid event ID")
            return
        }

        do {
            var savedPhoto = try PhotoStorageManager.shared.save(image: image, for: event)
            savedPhoto.image = image

            let queuedPhoto = try sync.queuePhoto(image: image, eventId: eventUUID)
            let userId = api.currentUserId

            // Optimistic update — local photo, counter bump, dot bump
            updateHydrated(event.id) { h in
                h.localPhotos.append(savedPhoto)
                h.userPhotoCount += 1
                if let userId,
                   let mIdx = h.members.firstIndex(where: { $0.userId == userId.uuidString }) {
                    let m = h.members[mIdx]
                    h.members[mIdx] = MemberWithShots(
                        userId: m.userId,
                        username: m.username,
                        displayName: m.displayName,
                        avatarUrl: m.avatarUrl,
                        shotsTaken: m.shotsTaken + 1
                    )
                }
            }

            let shotNumber = hydratedEvents.first(where: { $0.id == event.id })?.userPhotoCount ?? 1
            var props: [String: Any] = [
                "event_id": event.id,
                "user_photo_count": shotNumber
            ]
            if shotNumber == 1, let secs = AnalyticsManager.secondsSinceJoin(eventId: event.id) {
                props["seconds_since_join"] = secs
            }
            AnalyticsManager.shared.track(.shotCaptured, properties: props)

            debugLog("✅ Photo captured and queued for upload: \(queuedPhoto.id)")
            debugLog("   Pending uploads: \(sync.pendingCount)")

            // Reconcile against server-truth 3s later.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                guard let userId = self.api.currentUserId else { return }
                let realCount = (try? await self.api.getPhotoCount(eventId: eventUUID, userId: userId)) ?? 0
                await MainActor.run {
                    self.updateHydrated(event.id) { h in
                        h.userPhotoCount = realCount
                        if let mIdx = h.members.firstIndex(where: { $0.userId == userId.uuidString }) {
                            let m = h.members[mIdx]
                            h.members[mIdx] = MemberWithShots(
                                userId: m.userId,
                                username: m.username,
                                displayName: m.displayName,
                                avatarUrl: m.avatarUrl,
                                shotsTaken: realCount
                            )
                        }
                    }
                }
            }
        } catch {
            debugLog("❌ Failed to save photo: \(error)")
        }
    }
}
