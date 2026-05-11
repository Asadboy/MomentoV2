//
//  MockMomentoAPI.swift
//  MomentoTests
//
//  In-memory mock for the MomentoAPI protocol. Lets EventStore tests drive
//  every code path without hitting the network. Each method returns canned
//  data, optionally throws a configured error, and records call counts for
//  assertions about behaviour (e.g., "did the 10s refresh skip 2/3 of ticks
//  when nothing was live?").
//

import Foundation
@testable import Momento

final class MockMomentoAPI: MomentoAPI {

    // MARK: - Configurable state

    var currentUserId: UUID?

    var myEvents: [EventModel] = []
    var myEventsError: Error?

    var memberCounts: [UUID: Int] = [:]
    var photoCounts: [UUID: Int] = [:]
    /// Keyed by "eventId:userId"
    var userPhotoCounts: [String: Int] = [:]

    var likedCounts: [UUID: Int] = [:]
    var likedPhotos: [UUID: [PhotoData]] = [:]
    var totalLikeCounts: [UUID: Int] = [:]

    var membersWithShots: [UUID: [MemberWithShots]] = [:]

    // MARK: - Call tracking

    private(set) var getMyEventsCallCount = 0
    private(set) var getEventMemberCountCallCount = 0
    private(set) var getEventPhotoCountCallCount = 0
    private(set) var getPhotoCountCallCount = 0
    private(set) var getEventMembersWithShotsCallCount = 0
    private(set) var deleteEventCalls: [UUID] = []

    // MARK: - MomentoAPI conformance

    func getMyEvents() async throws -> [EventModel] {
        getMyEventsCallCount += 1
        if let e = myEventsError { throw e }
        return myEvents
    }

    func deleteEvent(id: UUID) async throws {
        deleteEventCalls.append(id)
    }

    func getEventMemberCount(eventId: UUID) async throws -> Int {
        getEventMemberCountCallCount += 1
        return memberCounts[eventId] ?? 0
    }

    func getEventPhotoCount(eventId: UUID) async throws -> Int {
        getEventPhotoCountCallCount += 1
        return photoCounts[eventId] ?? 0
    }

    func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int {
        getPhotoCountCallCount += 1
        return userPhotoCounts["\(eventId):\(userId)"] ?? 0
    }

    func getEventMembersWithShots(eventId: UUID) async throws -> [MemberWithShots] {
        getEventMembersWithShotsCallCount += 1
        return membersWithShots[eventId] ?? []
    }

    func getLikedPhotoCount(eventId: UUID) async throws -> Int {
        likedCounts[eventId] ?? 0
    }

    func getLikedPhotos(eventId: UUID) async throws -> [PhotoData] {
        likedPhotos[eventId] ?? []
    }

    func getTotalLikeCount(eventId: UUID) async throws -> Int {
        totalLikeCounts[eventId] ?? 0
    }

    // MARK: - Test helpers

    /// Reset all call counters between assertions.
    func resetCallCounts() {
        getMyEventsCallCount = 0
        getEventMemberCountCallCount = 0
        getEventPhotoCountCallCount = 0
        getPhotoCountCallCount = 0
        getEventMembersWithShotsCallCount = 0
        deleteEventCalls.removeAll()
    }
}

// MARK: - Convenience builders

extension EventModel {
    /// Build an EventModel for tests with sensible defaults.
    static func test(
        id: UUID = UUID(),
        name: String = "Test Event",
        creatorId: UUID = UUID(),
        joinCode: String = "TEST00",
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        memberLimit: Int = 10
    ) -> EventModel {
        EventModel(
            id: id,
            name: name,
            creatorId: creatorId,
            joinCode: joinCode,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt,
            isDeleted: isDeleted,
            createdAt: createdAt,
            memberLimit: memberLimit
        )
    }
}
