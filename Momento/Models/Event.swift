//
//  Event.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Data model
//  This file defines the Event data structure and sample data generation.
//  Keeping data models separate ensures clear separation of concerns.

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

/// Represents an event in the app (acts like a disposable camera)
/// Conforms to Identifiable for SwiftUI list usage and Hashable for comparison
struct Event: Identifiable, Hashable {
    let id: String
    var name: String
    var coverEmoji: String
    var startsAt: Date
    var endsAt: Date
    var releaseAt: Date
    var isPremium: Bool
    var memberCount: Int
    var photoCount: Int
    var joinCode: String?
    var creatorId: String?
    var expiresAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        coverEmoji: String,
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        isPremium: Bool = false,
        memberCount: Int = 0,
        photoCount: Int = 0,
        joinCode: String? = nil,
        creatorId: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.coverEmoji = coverEmoji
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.releaseAt = releaseAt
        self.isPremium = isPremium
        self.memberCount = memberCount
        self.photoCount = photoCount
        self.joinCode = joinCode
        self.creatorId = creatorId
        self.expiresAt = expiresAt
    }

    enum State {
        case upcoming
        case live
        case processing
        case revealed
    }

    func currentState(at now: Date = .now) -> State {
        if now >= releaseAt {
            return .revealed
        } else if now >= endsAt {
            return .processing
        } else if now >= startsAt {
            return .live
        } else {
            return .upcoming
        }
    }
}

// MARK: - Supabase Bridge

extension Event {
    /// Convert from Supabase EventModel to local Event
    init(fromSupabase eventModel: EventModel) {
        self.init(
            id: eventModel.id.uuidString,
            name: eventModel.name,
            coverEmoji: "\u{1F4F8}",
            startsAt: eventModel.startsAt,
            endsAt: eventModel.endsAt,
            releaseAt: eventModel.releaseAt,
            isPremium: eventModel.isPremium,
            memberCount: eventModel.memberCount,
            photoCount: eventModel.photoCount,
            joinCode: eventModel.joinCode,
            creatorId: eventModel.creatorId.uuidString,
            expiresAt: eventModel.expiresAt
        )
    }
}

/// Generates sample events for preview/testing purposes
/// - Parameter now: Current date to base sample events on
/// - Returns: Array of sample Event objects
func makeFakeEvents(now: Date = .now) -> [Event] {
    let calendar = Calendar.current

    return [
        // Upcoming state - starts in 12 hours
        Event(
            name: "Joe's 26th",
            coverEmoji: "\u{1F382}", // cake
            startsAt: calendar.date(byAdding: .hour, value: 12, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 44, to: now)!,
            joinCode: "JOE26"
        ),

        // Live state - started 30 minutes ago, ends in 6 hours
        Event(
            name: "NYE House Party",
            coverEmoji: "\u{1F389}", // party popper
            startsAt: calendar.date(byAdding: .minute, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 6, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 30, to: now)!,
            joinCode: "NYE2025"
        ),

        // Revealed state - event ended, photos revealed
        Event(
            name: "Sopranos Party",
            coverEmoji: "\u{1F37B}", // beers
            startsAt: calendar.date(byAdding: .hour, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: -20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
            joinCode: "SOPRANO"
        )
    ]
}
