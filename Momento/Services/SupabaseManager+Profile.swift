//
//  SupabaseManager+Profile.swift
//  Momento
//
//  Profile-related queries on the `profiles` table plus the aggregate
//  `getProfileStats` used by the profile screen.
//

import Foundation
import Supabase

extension SupabaseManager {

    // MARK: - Profile creation (called from auth flows)

    /// Create user profile if it doesn't exist. Called from `signInWithApple`
    /// and `signInWithGoogle` for first-time OAuth users.
    func createProfileIfNeeded(user: User) async throws {
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value

        if response.isEmpty {
            let email = user.email ?? "user"
            let username = email.components(separatedBy: "@").first ?? "user"
            let uniqueUsername = "\(username)\(Int.random(in: 1000...9999))"
            try await createProfile(userId: user.id, username: uniqueUsername)
        }
    }

    /// Insert a new profile row. Called from `signUpWithEmail` and from
    /// `createProfileIfNeeded` for OAuth users.
    func createProfile(userId: UUID, username: String) async throws {
        let profile = UserProfile(
            id: userId,
            username: username.lowercased(),
            displayName: username,
            avatarUrl: nil,
            deviceToken: nil,
            createdAt: Date()
        )

        try await client
            .from("profiles")
            .insert(profile)
            .execute()

        debugLog("✅ Profile created for user: \(username)")
    }

    // MARK: - Profile reads

    /// Get a user profile by id.
    func getUserProfile(userId: UUID) async throws -> UserProfile {
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value

        guard let profile = response.first else {
            throw SupabaseError.configurationError("Profile not found")
        }

        return profile
    }

    /// Update fields on a profile row.
    func updateProfile(userId: UUID, updates: [String: AnyJSON]) async throws {
        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()

        debugLog("✅ Profile updated")
    }

    /// True when the profile still has an auto-generated username
    /// (something ending in exactly 4 digits — see `createProfileIfNeeded`).
    func needsUsernameSelection(userId: UUID) async throws -> Bool {
        let profile = try await getUserProfile(userId: userId)
        let pattern = ".*\\d{4}$"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: profile.username.utf16.count)
        return regex.firstMatch(in: profile.username, range: range) != nil
    }

    /// True when the given username is not yet taken.
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let normalized = username.lowercased()

        let response = try await client
            .from("profiles")
            .select("username", head: true, count: .exact)
            .eq("username", value: normalized)
            .execute()

        return response.count == 0
    }

    /// Rename a user's username. Throws if the new name is already taken.
    func updateUsername(userId: UUID, newUsername: String) async throws {
        let normalized = newUsername.lowercased()

        let isAvailable = try await checkUsernameAvailability(normalized)
        guard isAvailable else {
            throw SupabaseError.configurationError("Username is already taken")
        }

        try await client
            .from("profiles")
            .update(["username": AnyJSON.string(normalized)])
            .eq("id", value: userId.uuidString)
            .execute()

        debugLog("✅ Username updated to: \(normalized)")
    }

    // MARK: - Profile Stats (used by the profile screen)

    /// Aggregate stats — events joined, hosted, photos taken, likes given,
    /// and the user's sequential signup number. All count queries run in
    /// parallel.
    func getProfileStats() async throws -> ProfileStats {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        let uid = userId.uuidString

        async let eventsJoinedTask = client
            .from("event_members")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: uid)
            .execute()

        async let eventsHostedTask = client
            .from("events")
            .select("*", head: true, count: .exact)
            .eq("creator_id", value: uid)
            .eq("is_deleted", value: false)
            .execute()

        async let photosTakenTask = client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: uid)
            .execute()

        async let photosLikedTask = client
            .from("photo_likes")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: uid)
            .execute()

        async let profileTask = client
            .from("profiles")
            .select("created_at")
            .eq("id", value: uid)
            .single()
            .execute()

        let (eventsJoinedResult, eventsHostedResult, photosTakenResult, photosLikedResult, profileResult) =
            try await (eventsJoinedTask, eventsHostedTask, photosTakenTask, photosLikedTask, profileTask)

        let eventsJoined = eventsJoinedResult.count ?? 0
        let eventsHosted = eventsHostedResult.count ?? 0
        let photosTaken = photosTakenResult.count ?? 0
        let photosLiked = photosLikedResult.count ?? 0

        // User number needs the profile created_at first.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profileData = try decoder.decode([String: String].self, from: profileResult.data)
        let createdAt = profileData["created_at"] ?? ""

        let userNumber = try await client
            .from("profiles")
            .select("*", head: true, count: .exact)
            .lte("created_at", value: createdAt)
            .execute()
            .count ?? 0

        return ProfileStats(
            eventsJoined: eventsJoined,
            eventsHosted: eventsHosted,
            photosTaken: photosTaken,
            photosLiked: photosLiked,
            userNumber: userNumber
        )
    }
}
