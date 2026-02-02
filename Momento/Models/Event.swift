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
    var isRevealed: Bool
}

/// Represents a photo taken at an event
struct EventPhoto: Identifiable {
    let id: String
    let eventID: String
    let fileURL: URL
    let capturedAt: Date
    var isRevealed: Bool
    var capturedBy: String?
    var image: UIImage?
    
    init(
        id: String = UUID().uuidString,
        eventID: String,
        fileURL: URL,
        capturedAt: Date = .now,
        isRevealed: Bool = false,
        capturedBy: String? = nil,
        image: UIImage? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.fileURL = fileURL
        self.capturedAt = capturedAt
        self.isRevealed = isRevealed
        self.capturedBy = capturedBy
        self.image = image
    }
}

/// Represents an event in the app (acts like a disposable camera)
/// Conforms to Identifiable for SwiftUI list usage and Hashable for comparison
struct Event: Identifiable, Hashable {
    let id: String
    var title: String
    var coverEmoji: String
    var startsAt: Date      // When event goes live (photos can be taken)
    var endsAt: Date        // When photo-taking stops
    var releaseAt: Date     // When photos are revealed
    var memberCount: Int
    var photosTaken: Int    // Number of photos taken in this disposable camera event
    var joinCode: String?   // Join code for sharing
    var isRevealed: Bool = false
    
    init(
        id: String = UUID().uuidString,
        title: String,
        coverEmoji: String,
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        memberCount: Int,
        photosTaken: Int,
        joinCode: String? = nil,
        isRevealed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.coverEmoji = coverEmoji
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.releaseAt = releaseAt
        self.memberCount = memberCount
        self.photosTaken = photosTaken
        self.joinCode = joinCode
        self.isRevealed = isRevealed
    }
    
    /// Current state of the event based on time
    enum State {
        case upcoming   // Before startsAt
        case live       // Between startsAt and endsAt (photos can be taken)
        case processing // Between endsAt and releaseAt (waiting for reveal)
        case revealed   // After releaseAt or isRevealed == true
    }
    
    /// Get the current state of the event
    func currentState(at now: Date = .now) -> State {
        if isRevealed || now >= releaseAt {
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
            title: eventModel.title,
            coverEmoji: "\u{1F4F8}", // Camera emoji
            startsAt: eventModel.startsAt,
            endsAt: eventModel.endsAt,
            releaseAt: eventModel.releaseAt,
            memberCount: eventModel.memberCount,
            photosTaken: eventModel.photoCount,
            joinCode: eventModel.joinCode,
            isRevealed: eventModel.isRevealed
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
            title: "Joe's 26th",
            coverEmoji: "\u{1F382}", // cake
            startsAt: calendar.date(byAdding: .hour, value: 12, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 44, to: now)!,
            memberCount: 12,
            photosTaken: 0,
            joinCode: "JOE26"
        ),
        
        // Live state - started 30 minutes ago, ends in 6 hours
        Event(
            title: "NYE House Party",
            coverEmoji: "\u{1F389}", // party popper
            startsAt: calendar.date(byAdding: .minute, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: 6, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: 30, to: now)!,
            memberCount: 28,
            photosTaken: 23,
            joinCode: "NYE2025"
        ),
        
        // Revealed state - event ended, photos revealed
        Event(
            title: "Sopranos Party",
            coverEmoji: "\u{1F37B}", // beers
            startsAt: calendar.date(byAdding: .hour, value: -30, to: now)!,
            endsAt: calendar.date(byAdding: .hour, value: -20, to: now)!,
            releaseAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
            memberCount: 7,
            photosTaken: 15,
            joinCode: "SOPRANO",
            isRevealed: true
        )
    ]
}
