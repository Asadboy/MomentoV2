//
//  MomentoAPI.swift
//  Momento
//
//  Protocol that EventStore depends on instead of reaching into
//  SupabaseManager.shared directly. The only consumer today is EventStore;
//  the protocol surface is exactly what EventStore calls — nothing more.
//
//  Benefits:
//    1. EventStore is unit-testable with a mock conforming to this protocol
//       (see MomentoTests/MockMomentoAPI.swift)
//    2. SupabaseManager can later split into per-domain services (events,
//       members, photos, likes) without touching consumers
//    3. The dependency contract is explicit and reviewable in one place
//
//  Other consumers (CreateMomentoFlow, ProfileView, sign-in screens,
//  OfflineSyncManager) still talk to SupabaseManager.shared directly. They
//  can migrate to this protocol incrementally as the need for testability or
//  swapping arises.
//

import Foundation

protocol MomentoAPI: AnyObject {
    /// Currently signed-in user's id, or nil if not authenticated.
    var currentUserId: UUID? { get }

    /// All events the current user is a member of, server-ordered.
    func getMyEvents() async throws -> [EventModel]

    /// Soft-delete an event the current user created.
    func deleteEvent(id: UUID) async throws

    func getEventMemberCount(eventId: UUID) async throws -> Int
    func getEventPhotoCount(eventId: UUID) async throws -> Int
    func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int

    func getEventMembersWithShots(eventId: UUID) async throws -> [MemberWithShots]

    func getLikedPhotoCount(eventId: UUID) async throws -> Int
    func getLikedPhotos(eventId: UUID) async throws -> [PhotoData]
    func getTotalLikeCount(eventId: UUID) async throws -> Int
}

// MARK: - SupabaseManager conformance

extension SupabaseManager: MomentoAPI {
    /// Bridges the Supabase Auth `User?` to a UUID for the protocol.
    var currentUserId: UUID? {
        currentUser?.id
    }
}
