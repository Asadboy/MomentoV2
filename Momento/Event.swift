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
    var releaseAt: Date
    var memberCount: Int
    var photosTaken: Int  // Number of photos taken in this disposable camera event
    var joinCode: String?  // Optional join code for code-based joining
    var isRevealed: Bool = false
    
    init(
        id: String = UUID().uuidString,
        title: String,
        coverEmoji: String,
        releaseAt: Date,
        memberCount: Int,
        photosTaken: Int,
        joinCode: String? = nil,
        isRevealed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.coverEmoji = coverEmoji
        self.releaseAt = releaseAt
        self.memberCount = memberCount
        self.photosTaken = photosTaken
        self.joinCode = joinCode
        self.isRevealed = isRevealed
    }
    
    // Note: photos array is excluded from Hashable conformance
    // as UIImage doesn't conform to Hashable
    // In production, photos would be stored separately and referenced by ID
}

// MARK: - Supabase Bridge

extension Event {
    /// Convert from Supabase EventModel to local Event
    init(fromSupabase eventModel: EventModel) {
        self.init(
            id: eventModel.id.uuidString,
            title: eventModel.title,
            coverEmoji: "📸", // Default emoji, can be customized later
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
    [
        // Countdown state - releases in 12 hours
        Event(
            title: "Joe's 26th 🎂",
            coverEmoji: "🎂",
            releaseAt: Calendar.current.date(byAdding: .hour, value: 12, to: now)!,
            memberCount: 12,
            photosTaken: 0,
            joinCode: "JOE26"
        ),
        
        // Live state - started 30 minutes ago
        Event(
            title: "NYE House Party 🎉",
            coverEmoji: "🎉",
            releaseAt: Calendar.current.date(byAdding: .minute, value: -30, to: now)!,
            memberCount: 28,
            photosTaken: 23,
            joinCode: "NYE2025"
        ),
        
        // Revealed state - released 25 hours ago (past the 24h window)
        Event(
            title: "Asad's Sopranos Party 🧺",
            coverEmoji: "🧺",
            releaseAt: Calendar.current.date(byAdding: .hour, value: -25, to: now)!,
            memberCount: 7,
            photosTaken: 15,
            joinCode: "SOPRANO",
            isRevealed: true
        )
    ]
}
