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

/// A member of an event with their shot count (for people-dots card).
struct MemberWithShots: Identifiable, Equatable {
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let shotsTaken: Int

    var id: String { userId }

    /// Display name with fallback to username.
    var name: String {
        displayName ?? username
    }
}
