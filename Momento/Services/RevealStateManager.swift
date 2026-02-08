//
//  RevealStateManager.swift
//  Momento
//
//  Tracks which events the user has completed revealing
//  NOTE: Currently stores locally in UserDefaults. 
//  TODO: Sync to Supabase for cross-device persistence (see BACKLOG.md)
//

import Foundation

class RevealStateManager {
    static let shared = RevealStateManager()
    
    private let completedRevealsKey = "completedEventReveals"
    
    private init() {}
    
    /// Check if user has completed revealing an event
    func hasCompletedReveal(for eventId: String) -> Bool {
        let completed = getCompletedEventIds()
        return completed.contains(eventId)
    }
    
    /// Mark an event as having completed reveal
    func markRevealCompleted(for eventId: String) {
        var completed = getCompletedEventIds()
        if !completed.contains(eventId) {
            completed.append(eventId)
            saveCompletedEventIds(completed)
            debugLog("✅ Marked reveal completed for event: \(eventId.prefix(8))...")
        }
    }
    
    /// Clear completed status for an event (for testing)
    func clearRevealCompleted(for eventId: String) {
        var completed = getCompletedEventIds()
        completed.removeAll { $0 == eventId }
        saveCompletedEventIds(completed)
        debugLog("🗑️ Cleared reveal status for event: \(eventId.prefix(8))...")
    }
    
    /// Clear all completed reveals (for testing)
    func clearAllCompletedReveals() {
        UserDefaults.standard.removeObject(forKey: completedRevealsKey)
        debugLog("🗑️ Cleared all reveal statuses")
    }
    
    // MARK: - Private
    
    private func getCompletedEventIds() -> [String] {
        return UserDefaults.standard.stringArray(forKey: completedRevealsKey) ?? []
    }
    
    private func saveCompletedEventIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: completedRevealsKey)
    }
}

