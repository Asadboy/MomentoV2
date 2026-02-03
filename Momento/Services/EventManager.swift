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
    ///   - name: Event name (will be trimmed)
    ///   - emoji: Cover emoji for the event
    ///   - startsAt: When the event starts
    func addEvent(name: String, emoji: String, startsAt: Date) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Auto-calculate event times from start
        let endsAt = startsAt.addingTimeInterval(12 * 3600)  // +12 hours
        let releaseAt = startsAt.addingTimeInterval(24 * 3600) // +24 hours

        let event = Event(
            name: trimmedName,
            coverEmoji: emoji,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt
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
