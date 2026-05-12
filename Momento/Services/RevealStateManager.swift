//
//  RevealStateManager.swift
//  Momento
//
//  Tracks which events the user has completed revealing.
//
//  Storage is UserDefaults, namespaced by the current user's id so a
//  sign-in/sign-out cycle on a shared device can't leak reveal state
//  across accounts. Pre-launch this was a global key — anyone signing
//  in after another user would have inherited that user's completed
//  reveals (review finding H4).
//
//  TODO: sync to Supabase for cross-device persistence (see BACKLOG.md).
//

import Foundation

class RevealStateManager {
    static let shared = RevealStateManager()

    /// Legacy global key. Kept here as a constant so it can be cleaned
    /// up on sign-out alongside the per-user entries.
    private let legacyKey = "completedEventReveals"

    private init() {}

    // MARK: - Public API

    func hasCompletedReveal(for eventId: String) -> Bool {
        getCompletedEventIds().contains(eventId)
    }

    func markRevealCompleted(for eventId: String) {
        var completed = getCompletedEventIds()
        if !completed.contains(eventId) {
            completed.append(eventId)
            saveCompletedEventIds(completed)
            debugLog("✅ Marked reveal completed for event: \(eventId.prefix(8))…")
        }
    }

    func clearRevealCompleted(for eventId: String) {
        var completed = getCompletedEventIds()
        completed.removeAll { $0 == eventId }
        saveCompletedEventIds(completed)
        debugLog("🗑️ Cleared reveal status for event: \(eventId.prefix(8))…")
    }

    /// Clear all completed reveals for the current user, plus the legacy
    /// global key (so any data written before per-user namespacing also
    /// goes away). Safe to call when unauthenticated.
    func clearAllCompletedReveals() {
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        debugLog("🗑️ Cleared all reveal statuses")
    }

    // MARK: - Private

    /// UserDefaults key for the currently signed-in user. Falls back to
    /// the legacy global key when no user is authenticated so that any
    /// reveal-marking that happens during the brief unauth window still
    /// has somewhere to live (and gets cleaned up at sign-out anyway).
    private var currentUserKey: String {
        if let userId = SupabaseManager.shared.currentUser?.id.uuidString {
            return "\(legacyKey).\(userId)"
        }
        return legacyKey
    }

    private func getCompletedEventIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: currentUserKey) ?? []
    }

    private func saveCompletedEventIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: currentUserKey)
    }
}
