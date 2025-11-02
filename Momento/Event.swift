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

/// Represents a photo taken at an event
struct EventPhoto: Identifiable {
    let id: String = UUID().uuidString
    let image: UIImage
    let takenAt: Date
    
    init(image: UIImage, takenAt: Date = .now) {
        self.image = image
        self.takenAt = takenAt
    }
}

/// Represents an event in the app (acts like a disposable camera)
/// Conforms to Identifiable for SwiftUI list usage and Hashable for comparison
struct Event: Identifiable, Hashable {
    let id: String = UUID().uuidString
    var title: String
    var coverEmoji: String
    var releaseAt: Date
    var memberCount: Int
    var photosTaken: Int  // Number of photos taken in this disposable camera event
    var joinCode: String?  // Optional join code for code-based joining
    
    // Note: photos array is excluded from Hashable conformance
    // as UIImage doesn't conform to Hashable
    // In production, photos would be stored separately and referenced by ID
}

/// Generates sample events for preview/testing purposes
/// - Parameter now: Current date to base sample events on
/// - Returns: Array of sample Event objects
func makeFakeEvents(now: Date = .now) -> [Event] {
    [
        Event(title: "Joe's 26th",  coverEmoji: "🎂",
              releaseAt: Calendar.current.date(byAdding: .hour, value: 24, to: now)!,
              memberCount: 12, photosTaken: 8, joinCode: "JOE26"),
        Event(title: "NYE House Party", coverEmoji: "🎉",
              releaseAt: Calendar.current.date(byAdding: .minute, value: 90, to: now)!,
              memberCount: 28, photosTaken: 23, joinCode: "NYE2025"),
        Event(title: "Asad's Sopranos Party", coverEmoji: "🧺",
              releaseAt: Calendar.current.date(byAdding: .day, value: 2, to: now)!,
              memberCount: 7, photosTaken: 5, joinCode: "SOPRANO")
    ]
}
