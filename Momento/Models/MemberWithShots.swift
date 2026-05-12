//
//  MemberWithShots.swift
//  Momento
//
//  Domain model for a member of an event together with their shot count —
//  used by the people-dots card and the lobby hero roster. Lives in Models/
//  rather than SupabaseManager so it can be consumed without depending on the
//  Supabase implementation.
//

import Foundation

/// A member of an event with their shot count (for the lobby roster).
struct MemberWithShots: Identifiable, Equatable {
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let shotsTaken: Int

    var id: String { userId }

    /// Alias kept for readability at call sites.
    var name: String { displayName }
}
