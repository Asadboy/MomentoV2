//
//  EventManager.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Event business logic
//  This manager handles all event-related operations (CRUD),
//  separating business logic from UI code for better maintainability.

import Foundation
import Combine

/// Manages event-related operations and data
/// This separates business logic from UI, making the code more modular
class EventManager: ObservableObject {
    /// Published events array - UI automatically updates when this changes
    @Published var events: [Event] = []
    
    /// Initialize with sample data
    /// - Parameter now: Current date for generating sample events
    init(now: Date = .now) {
        self.events = makeFakeEvents(now: now)
    }
    
    /// Creates a new event and adds it to the events array
    /// - Parameters:
    ///   - title: Event title (will be trimmed)
    ///   - emoji: Cover emoji for the event
    ///   - releaseAt: When the event releases
    ///   - memberCount: Number of members (optional, defaults to random)
    func addEvent(title: String, emoji: String, releaseAt: Date, memberCount: Int? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let event = Event(
            title: trimmedTitle,
            coverEmoji: emoji,
            releaseAt: releaseAt,
            memberCount: memberCount ?? Int.random(in: 2...30), // Random member count between 2-30
            photosTaken: 0, // Start with 0 photos
            joinCode: nil // No join code for manually created events
        )
        events.append(event)
    }
    
    /// Removes events at the specified indices
    /// - Parameter offsets: IndexSet of indices to remove
    func deleteEvents(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
    }
    
    /// Removes a specific event by ID
    /// - Parameter eventId: The ID of the event to remove
    func deleteEvent(withId eventId: String) {
        events.removeAll { $0.id == eventId }
    }
}
