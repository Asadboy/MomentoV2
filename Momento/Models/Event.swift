//
//  Event.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  Data models for events and photos.

import Foundation
import UIKit

/// Persisted metadata that accompanies each stored photo
struct PhotoMetadata: Codable {
    let photoID: String
    let eventID: String
    let capturedAt: Date
    var capturedBy: String?
}

/// Represents a photo taken at an event
struct EventPhoto: Identifiable {
    let id: String
    let eventID: String
    let fileURL: URL
    let capturedAt: Date
    var capturedBy: String?
    var image: UIImage?

    init(
        id: String = UUID().uuidString,
        eventID: String,
        fileURL: URL,
        capturedAt: Date = .now,
        capturedBy: String? = nil,
        image: UIImage? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.fileURL = fileURL
        self.capturedAt = capturedAt
        self.capturedBy = capturedBy
        self.image = image
    }
}

/// Represents an event (a time-bound gathering where people take shots)
struct Event: Identifiable, Hashable {
    let id: String
    var name: String
    var startsAt: Date
    var endsAt: Date
    var releaseAt: Date
    var memberCount: Int
    var photoCount: Int
    var joinCode: String?
    var creatorId: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        memberCount: Int = 0,
        photoCount: Int = 0,
        joinCode: String? = nil,
        creatorId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.releaseAt = releaseAt
        self.memberCount = memberCount
        self.photoCount = photoCount
        self.joinCode = joinCode
        self.creatorId = creatorId
    }

    // MARK: - State Machine (3 states)

    enum State {
        case upcoming   // Event hasn't started yet
        case live       // Event is happening — people can take shots
        case revealed   // Event has ended — covers both "waiting for reveal" and "revealed"
    }

    /// Returns the current state based on time.
    /// - upcoming: now < startsAt
    /// - live: startsAt <= now < endsAt
    /// - revealed: now >= endsAt (includes the gap before releaseAt)
    func currentState(at now: Date = .now) -> State {
        if now >= endsAt {
            return .revealed
        } else if now >= startsAt {
            return .live
        } else {
            return .upcoming
        }
    }

    /// Whether the reveal is actually available (releaseAt has passed)
    func isRevealReady(at now: Date = .now) -> Bool {
        now >= releaseAt
    }
}

// MARK: - Supabase Bridge

extension Event {
    /// Convert from Supabase EventModel to local Event
    init(fromSupabase eventModel: EventModel) {
        self.init(
            id: eventModel.id.uuidString,
            name: eventModel.name,
            startsAt: eventModel.startsAt,
            endsAt: eventModel.endsAt,
            releaseAt: eventModel.releaseAt,
            joinCode: eventModel.joinCode,
            creatorId: eventModel.creatorId.uuidString
        )
    }
}

/// Generates sample events for preview/testing
func makeFakeEvents(now: Date = .now) -> [Event] {
    let calendar = Calendar.current

    return [
        // Upcoming — starts in 12 hours
        Event(
            name: "Joe's 26th",
            startsAt: calendar.date(byAdding: .hour, value: 12, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 44, to: now)!,
            joinCode: "JOE26"
        ),

        // Live — started 30 mins ago
        Event(
            name: "NYE House Party",
            startsAt: calendar.date(byAdding: .minute, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 6, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 30, to: now)!,
            joinCode: "NYE2025"
        ),

        // Revealed — event ended, photos revealed
        Event(
            name: "Sopranos Party",
            startsAt: calendar.date(byAdding: .hour, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: -20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
            joinCode: "SOPRANO"
        )
    ]
}
