//
//  SupabaseManager+Events.swift
//  Momento
//
//  CRUD for events: create, join (via code), lookup, fetch, soft-delete,
//  restore, leave. Photo / member / like queries live in their own
//  extensions.
//

import Foundation
import Supabase

extension SupabaseManager {

    /// Create a new event. Auto-calculates ends_at (+12h) and release_at (+24h)
    /// from the start. The creator is inserted into `event_members` in the
    /// same call — this must succeed or the creator would lose their own
    /// event on next reload (see PR #11 for the RLS regression that exposed
    /// this).
    func createEvent(name: String, startsAt: Date, joinCode: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            debugLog("[createEvent] Error: User not authenticated")
            throw SupabaseError.userNotAuthenticated
        }

        let endsAt = startsAt.addingTimeInterval(12 * 3600)
        let releaseAt = startsAt.addingTimeInterval(24 * 3600)
        debugLog("[createEvent] Creating: \(name)")
        debugLog("[createEvent] Starts: \(startsAt), Ends: \(endsAt), Reveals: \(releaseAt)")

        let event = EventModel(
            id: UUID(),
            name: name,
            creatorId: userId,
            joinCode: joinCode,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt,
            isDeleted: false,
            createdAt: Date(),
            memberLimit: 10
        )

        try await client
            .from("events")
            .insert(event)
            .execute()

        debugLog("[createEvent] Event saved, adding creator as member...")

        let member = EventMember(
            eventId: event.id,
            userId: userId,
            joinedAt: Date()
        )

        try await client
            .from("event_members")
            .insert(member)
            .execute()

        debugLog("[createEvent] Success: \(name) with code \(joinCode)")
        return event
    }

    /// Join an event by code. Looks up the event, checks the user isn't
    /// already a member, pre-validates the member-limit cap (RLS enforces
    /// it server-side too but we want a friendly typed error), then inserts
    /// the membership row.
    func joinEvent(code: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        let event = try await lookupEvent(code: code)

        let existingMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: event.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if !existingMembers.isEmpty {
            debugLog("ℹ️ Already a member of this event")
            return event
        }

        let currentCount = try await getEventMemberCount(eventId: event.id)
        if currentCount >= event.memberLimit {
            debugLog("ℹ️ Event is full (\(currentCount)/\(event.memberLimit))")
            throw SupabaseError.eventFull
        }

        let member = EventMember(
            eventId: event.id,
            userId: userId,
            joinedAt: Date()
        )

        try await client
            .from("event_members")
            .insert(member)
            .execute()

        AnalyticsManager.stampJoin(eventId: event.id.uuidString)
        AnalyticsManager.shared.track(.eventJoined, properties: [
            "event_id": event.id.uuidString,
            "join_method": "code"
        ])

        debugLog("✅ Joined event: \(event.name)")
        return event
    }

    /// Look up an event by code without joining (used by the join-preview
    /// modal). Routed through a SECURITY DEFINER RPC so it doesn't
    /// enumerate the events table.
    func lookupEvent(code: String) async throws -> EventModel {
        let events: [EventModel] = try await client
            .rpc("lookup_event_by_code", params: ["lookup_code": code])
            .execute()
            .value

        guard let event = events.first else {
            throw SupabaseError.eventNotFound
        }

        return event
    }

    /// All events the current user is a member of (soft-deleted excluded).
    func getMyEvents() async throws -> [EventModel] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let eventIds = members.map { $0.eventId.uuidString }

        if eventIds.isEmpty {
            return []
        }

        let events: [EventModel] = try await client
            .from("events")
            .select()
            .in("id", values: eventIds)
            .eq("is_deleted", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value

        debugLog("✅ Fetched \(events.count) events")
        return events
    }

    /// Fetch a single event by id.
    func getEvent(id: UUID) async throws -> EventModel {
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value

        guard let event = events.first else {
            throw SupabaseError.eventNotFound
        }

        return event
    }

    /// Soft-delete an event the current user created (sets `is_deleted=true`).
    func deleteEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        try await client
            .from("events")
            .update(["is_deleted": true])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        debugLog("Soft-deleted event: \(id.uuidString.prefix(8))...")
    }

    /// Restore a previously soft-deleted event.
    func restoreEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        try await client
            .from("events")
            .update(["is_deleted": false])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        debugLog("Restored event: \(id.uuidString.prefix(8))...")
    }

    /// Leave an event (drops the current user's membership row).
    func leaveEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        try await client
            .from("event_members")
            .delete()
            .eq("event_id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        debugLog("✅ Left event")
    }
}
