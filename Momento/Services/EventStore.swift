//
//  EventStore.swift
//  Momento
//
//  Owns all event-related state and side effects for the home screen.
//
//  Lifted out of ContentView (which previously carried 27 @State properties and
//  ~400 lines of business logic). Centralising here means:
//    1. Views don't run network task groups or do optimistic-update reconciliation
//    2. Per-event hydration (members, photos, liked counts, reveal status) has
//       a single source of truth
//    3. The same store can back future screens (event detail, widgets) without
//       duplicating fetch/refresh logic
//
//  Phase 1 of the ContentView split — this commit still uses dict-per-field
//  hydration to keep the structural move faithful. Phase 4 will collapse the
//  dicts into a single HydratedEvent struct.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class EventStore: ObservableObject {

    // MARK: - Published State

    @Published var events: [Event] = []
    @Published var isLoading: Bool = true

    // Per-event hydration — keyed by event.id. Phase 4 collapses these into a
    // single [HydratedEvent].
    @Published var eventMembers: [String: [MemberWithShots]] = [:]
    @Published var revealCompletionStatus: [String: Bool] = [:]
    @Published var likedCounts: [String: Int] = [:]
    @Published var pastEventPhotos: [String: [PhotoData]] = [:]
    @Published var userPhotoCounts: [String: Int] = [:]
    @Published var totalLikeCounts: [String: Int] = [:]
    @Published var eventPhotos: [String: [EventPhoto]] = [:]

    /// Event id that was just joined — drives the 2-second green glow on the
    /// active-events card. Cleared back to nil 2s after a join.
    @Published var newlyJoinedEventId: String? = nil

    /// Error surface for the view to read and show as an alert.
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let supabase = SupabaseManager.shared
    private let sync = OfflineSyncManager.shared
    private var isRefreshing = false

    /// Tick counter for the 10s refresh timer. When nothing is live we run the
    /// real refresh every 3rd tick (~30s) to save battery — carried over from
    /// the perf optimisation in PR #6.
    private var refreshTickCount = 0

    // MARK: - Derived

    var currentUserId: String? {
        supabase.currentUser?.id.uuidString
    }

    /// Active events (live / upcoming / unrevealed) shown as featured cards.
    func activeEvents(at now: Date) -> [Event] {
        events
            .filter {
                let state = $0.currentState(at: now)
                if state == .live || state == .upcoming { return true }
                if state == .revealed && !(revealCompletionStatus[$0.id] ?? false) { return true }
                return false
            }
            .sorted { e1, e2 in
                let s1 = e1.currentState(at: now)
                let s2 = e2.currentState(at: now)
                func priority(_ s: Event.State) -> Int {
                    switch s {
                    case .live: return 0
                    case .revealed: return 1
                    case .upcoming: return 2
                    }
                }
                let p1 = priority(s1)
                let p2 = priority(s2)
                if p1 != p2 { return p1 < p2 }
                return e1.startsAt < e2.startsAt
            }
    }

    /// Past events (completed reveals) shown as compact rows.
    func pastEvents(at now: Date) -> [Event] {
        events
            .filter { e in
                e.currentState(at: now) == .revealed && (revealCompletionStatus[e.id] ?? false)
            }
            .sorted { $0.releaseAt > $1.releaseAt }
    }

    // MARK: - Load

    /// Full reload from server. Debounced so refresh storms don't pile up.
    func loadEvents() async {
        guard !isRefreshing else {
            debugLog("⏳ Already refreshing, skipping duplicate call")
            return
        }
        isRefreshing = true
        isLoading = events.isEmpty
        defer { isRefreshing = false }

        do {
            let models = try await supabase.getMyEvents()
            let loaded = models.map { Event(fromSupabase: $0) }

            // Restore reveal completion from local persistent storage first.
            var restoredRevealStatus: [String: Bool] = [:]
            for e in loaded where RevealStateManager.shared.hasCompletedReveal(for: e.id) {
                restoredRevealStatus[e.id] = true
            }

            events = loaded
            revealCompletionStatus.merge(restoredRevealStatus) { _, new in new }
            isLoading = false

            await hydrateActive(events: loaded)
            await hydrateRevealed(events: loaded, restoredRevealStatus: &restoredRevealStatus)
            await hydrateMembers(events: loaded, restoredRevealStatus: restoredRevealStatus)

            revealCompletionStatus.merge(restoredRevealStatus) { _, new in new }
            debugLog("✅ Loaded \(models.count) events")
        } catch {
            debugLog("Failed to load events: \(error)")
            isLoading = false
        }
    }

    private func hydrateActive(events loaded: [Event]) async {
        let active = loaded.filter { $0.currentState() == .live || $0.currentState() == .upcoming }
        let currentUserId = supabase.currentUser?.id

        let results = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
            for event in active {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let m = (try? await self.supabase.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.supabase.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    var u: Int? = nil
                    if let uid = currentUserId, event.currentState() == .live {
                        u = (try? await self.supabase.getPhotoCount(eventId: eventUUID, userId: uid)) ?? 0
                    }
                    return (event.id, m, p, u)
                }
            }
            var out: [(String, Int, Int, Int?)] = []
            for await r in group { out.append(r) }
            return out
        }

        for (id, m, p, u) in results {
            if let idx = events.firstIndex(where: { $0.id == id }) {
                events[idx].memberCount = m
                events[idx].photoCount = p
            }
            if let u { userPhotoCounts[id] = u }
        }
    }

    private func hydrateRevealed(events loaded: [Event], restoredRevealStatus: inout [String: Bool]) async {
        let revealed = loaded.filter { $0.currentState() == .revealed }

        let results = await withTaskGroup(of: (String, Int, [PhotoData], Int, Int, Int).self) { group in
            for event in revealed {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let count = (try? await self.supabase.getLikedPhotoCount(eventId: eventUUID)) ?? 0
                    let photos = (try? await self.supabase.getLikedPhotos(eventId: eventUUID)) ?? []
                    let totalLikes = (try? await self.supabase.getTotalLikeCount(eventId: eventUUID)) ?? 0
                    let m = (try? await self.supabase.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.supabase.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    return (event.id, count, photos, totalLikes, m, p)
                }
            }
            var out: [(String, Int, [PhotoData], Int, Int, Int)] = []
            for await r in group { out.append(r) }
            return out
        }

        var likeCounts: [String: Int] = [:]
        var pastPhotos: [String: [PhotoData]] = [:]
        for (id, count, photos, totalLikes, m, p) in results {
            likeCounts[id] = count
            pastPhotos[id] = photos
            totalLikeCounts[id] = totalLikes
            if let idx = events.firstIndex(where: { $0.id == id }) {
                events[idx].memberCount = m
                events[idx].photoCount = p
            }
            if count > 0 || RevealStateManager.shared.hasCompletedReveal(for: id) {
                restoredRevealStatus[id] = true
            }
        }

        likedCounts = likeCounts
        for (id, photos) in pastPhotos where !photos.isEmpty || pastEventPhotos[id] == nil {
            pastEventPhotos[id] = photos
        }
    }

    private func hydrateMembers(events loaded: [Event], restoredRevealStatus: [String: Bool]) async {
        let results = await withTaskGroup(of: (String, [MemberWithShots]).self) { group in
            for event in loaded where event.currentState() != .revealed || !(restoredRevealStatus[event.id] ?? false) {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let members = (try? await self.supabase.getEventMembersWithShots(eventId: eventUUID)) ?? []
                    return (event.id, members)
                }
            }
            var out: [(String, [MemberWithShots])] = []
            for await r in group { out.append(r) }
            return out
        }
        for (id, members) in results { eventMembers[id] = members }
    }

    // MARK: - Refresh tick (10s)

    /// Called by the view on every 10s timer fire. If something's live we
    /// refresh every tick; otherwise every 3rd tick (~30s).
    func refreshTick(at now: Date) async {
        refreshTickCount += 1
        let hasLive = events.contains { $0.currentState(at: now) == .live }
        guard hasLive || refreshTickCount % 3 == 0 else { return }
        await refreshCounts(now: now)
    }

    /// Silent refresh: re-fetch counts + member dots without redrawing the
    /// loading state. Used by the 10s timer.
    private func refreshCounts(now: Date) async {
        guard !events.isEmpty else { return }
        let currentUserId = supabase.currentUser?.id

        let countResults = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
            for event in events {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let m = (try? await self.supabase.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let p = (try? await self.supabase.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    var u: Int? = nil
                    if let uid = currentUserId, event.currentState() == .live {
                        u = (try? await self.supabase.getPhotoCount(eventId: eventUUID, userId: uid)) ?? 0
                    }
                    return (event.id, m, p, u)
                }
            }
            var out: [(String, Int, Int, Int?)] = []
            for await r in group { out.append(r) }
            return out
        }

        for (id, m, p, u) in countResults {
            if let idx = events.firstIndex(where: { $0.id == id }) {
                events[idx].memberCount = m
                events[idx].photoCount = p
            }
            if let u { userPhotoCounts[id] = u }
        }

        let memberResults = await withTaskGroup(of: (String, [MemberWithShots]).self) { group in
            for event in events where event.currentState() == .live || event.currentState() == .upcoming {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let members = (try? await self.supabase.getEventMembersWithShots(eventId: eventUUID)) ?? []
                    return (event.id, members)
                }
            }
            var out: [(String, [MemberWithShots])] = []
            for await r in group { out.append(r) }
            return out
        }
        for (id, members) in memberResults { eventMembers[id] = members }
    }

    // MARK: - Mutations

    func appendCreatedEvent(_ event: Event) {
        events.append(event)
    }

    /// A user just joined an event via the join sheet. Triggers the 2-second
    /// green glow on the card, then clears it.
    func joinedEvent(_ event: Event) {
        newlyJoinedEventId = event.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            events.append(event)
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
            try await supabase.deleteEvent(id: uuid)
            events.removeAll { $0.id == event.id }
        } catch {
            debugLog("Failed to delete event: \(error)")
        }
    }

    func markRevealCompleted(eventId: String) {
        revealCompletionStatus[eventId] = true
        RevealStateManager.shared.markRevealCompleted(for: eventId)
    }

    func clearRevealCompleted(eventId: String) {
        revealCompletionStatus[eventId] = nil
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

            if eventPhotos[event.id] == nil { eventPhotos[event.id] = [] }
            eventPhotos[event.id]?.append(savedPhoto)

            let queuedPhoto = try sync.queuePhoto(image: image, eventId: eventUUID)

            // Optimistic counter bump
            let eventId = event.id
            userPhotoCounts[eventId, default: 0] += 1
            let shotNumber = userPhotoCounts[eventId] ?? 1

            var props: [String: Any] = [
                "event_id": eventId,
                "user_photo_count": shotNumber
            ]
            if shotNumber == 1, let secs = AnalyticsManager.secondsSinceJoin(eventId: eventId) {
                props["seconds_since_join"] = secs
            }
            AnalyticsManager.shared.track(.shotCaptured, properties: props)

            // Bump the same user's dot row optimistically
            if let userId = supabase.currentUser?.id.uuidString,
               let memberIdx = eventMembers[eventId]?.firstIndex(where: { $0.userId == userId }) {
                let current = eventMembers[eventId]![memberIdx]
                eventMembers[eventId]![memberIdx] = MemberWithShots(
                    userId: current.userId,
                    username: current.username,
                    displayName: current.displayName,
                    avatarUrl: current.avatarUrl,
                    shotsTaken: current.shotsTaken + 1
                )
            }

            debugLog("✅ Photo captured and queued for upload: \(queuedPhoto.id)")
            debugLog("   Pending uploads: \(sync.pendingCount)")

            // Reconcile against server-truth 3s later — corrects if the upload
            // failed or another shot landed in the same window.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                guard let userId = self.supabase.currentUser?.id else { return }
                let realCount = (try? await self.supabase.getPhotoCount(eventId: eventUUID, userId: userId)) ?? 0
                await MainActor.run {
                    self.userPhotoCounts[eventId] = realCount
                    if let memberIdx = self.eventMembers[eventId]?.firstIndex(where: { $0.userId == userId.uuidString }) {
                        let current = self.eventMembers[eventId]![memberIdx]
                        self.eventMembers[eventId]![memberIdx] = MemberWithShots(
                            userId: current.userId,
                            username: current.username,
                            displayName: current.displayName,
                            avatarUrl: current.avatarUrl,
                            shotsTaken: realCount
                        )
                    }
                }
            }
        } catch {
            debugLog("❌ Failed to save photo: \(error)")
        }
    }
}
