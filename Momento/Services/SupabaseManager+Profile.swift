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
    ///
    /// The DB trigger `handle_new_user` also runs on `auth.users` insert and
    /// creates a profile row with a random handle + `profile_setup_complete
    /// = false`. This client-side call is a safety net for the rare case
    /// where the trigger missed (e.g. an auth.users row created out-of-band).
    func createProfileIfNeeded(user: User) async throws {
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value

        if response.isEmpty {
            let randomHandle = "user_" + UUID().uuidString.prefix(8).lowercased()
            try await createProfile(userId: user.id, displayName: randomHandle)
        }
    }

    /// Insert a new profile row with a placeholder display name. The user
    /// will be routed through `ProfileSetupView` to set their real one.
    func createProfile(userId: UUID, displayName: String) async throws {
        struct NewProfile: Encodable {
            let id: UUID
            let display_name: String
            let profile_setup_complete: Bool
        }

        let profile = NewProfile(
            id: userId,
            display_name: displayName,
            profile_setup_complete: false
        )

        try await client
            .from("profiles")
            .insert(profile)
            .execute()

        debugLog("✅ Profile created (placeholder) for: \(userId.uuidString.prefix(8))")
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

    /// True when the user still needs to pick a real display name (and
    /// optionally upload an avatar). Backed by the `profile_setup_complete`
    /// column rather than pattern-matching the name — closes review H3.
    func needsProfileSetup(userId: UUID) async throws -> Bool {
        let profile = try await getUserProfile(userId: userId)
        return profile.profileSetupComplete == false
    }

    // MARK: - Profile update

    /// Set the user's display name and mark setup complete. Trims whitespace
    /// and strips any emoji scalars — display names are a typographic
    /// surface, not a TikTok handle.
    func updateDisplayName(userId: UUID, displayName: String) async throws {
        let cleaned = DisplayName.sanitise(displayName)
        guard !cleaned.isEmpty else {
            throw SupabaseError.configurationError("Display name can't be empty")
        }

        struct Update: Encodable {
            let display_name: String
            let profile_setup_complete: Bool
        }

        try await client
            .from("profiles")
            .update(Update(display_name: cleaned, profile_setup_complete: true))
            .eq("id", value: userId.uuidString)
            .execute()

        debugLog("✅ Display name set")
    }

    // MARK: - Avatar upload

    /// Upload a JPEG avatar for the current user. Each upload goes to a fresh
    /// `<userId>/<uuid>.jpg` path and the new public URL is written to
    /// `profiles.avatar_url`.
    @discardableResult
    func uploadAvatar(jpegData: Data) async throws -> String {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // PostgreSQL's auth.uid()::text returns the UUID in lowercase, but
        // Swift's UUID.uuidString is uppercase. The avatars RLS policies
        // compare the folder segment to auth.uid() as strings, so the folder
        // must be the lowercased user id to match.
        let folder = userId.uuidString.lowercased()

        // Use a UNIQUE filename per upload rather than a fixed
        // `<userId>/avatar.jpg`. Overwriting in place on the avatars bucket —
        // via upsert OR remove-then-insert — trips a storage-server row-level
        // security check that we (and the original authors) could not resolve
        // even with the owner/folder matching the policies. The symptom was
        // users getting stuck on "resource already exists" or "new row violates
        // row-level security policy" and being unable to change their photo. A
        // brand-new path is a plain INSERT, which `avatars_owner_insert` allows
        // (it's how the very first avatar uploads), so it always succeeds. The
        // changing URL also self-busts any image cache.
        let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"

        _ = try await client.storage
            .from("avatars")
            .upload(
                path,
                data: jpegData,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )

        let publicURL = try client.storage.from("avatars").getPublicURL(path: path).absoluteString

        struct AvatarUpdate: Encodable { let avatar_url: String }
        try await client
            .from("profiles")
            .update(AvatarUpdate(avatar_url: publicURL))
            .eq("id", value: userId.uuidString)
            .execute()

        // Best-effort cleanup of the user's previous avatar object(s) so the
        // bucket doesn't accumulate orphans. Non-fatal: the new avatar is
        // already live, and the remove can legitimately fail (the same bucket
        // RLS quirk) without affecting the user.
        Task { [weak self] in
            await self?.pruneOldAvatars(folder: folder, keep: path)
        }

        debugLog("✅ Avatar uploaded")
        return publicURL
    }

    /// Best-effort removal of every object in the user's avatar folder except
    /// the one just uploaded (pass nil to wipe the folder). Avatars live at
    /// random paths (see uploadAvatar), so removal must always go through a
    /// list — a fixed "<uid>/avatar.jpg" path matches nothing.
    private func pruneOldAvatars(folder: String, keep: String?) async {
        guard let files = try? await client.storage.from("avatars").list(path: folder) else { return }
        let stale: [String] = files
            .map { "\(folder)/\($0.name)" }
            .filter { $0 != keep }
        guard !stale.isEmpty else { return }
        _ = try? await client.storage.from("avatars").remove(paths: stale)
    }

    /// Remove the current user's avatar.
    func removeAvatar() async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        await pruneOldAvatars(folder: userId.uuidString.lowercased(), keep: nil)

        struct AvatarClear: Encodable { let avatar_url: String? }
        try await client
            .from("profiles")
            .update(AvatarClear(avatar_url: nil))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Account deletion

    /// Permanently delete the current user's account and all owned data.
    /// Required by Apple App Store Guideline 5.1.1(v).
    ///
    /// Sequence:
    ///   1. Enumerate Storage paths the user owns — both photos they
    ///      uploaded directly, and photos in events they created (those
    ///      cascade-delete via the events FK but Storage objects don't).
    ///   2. Batch-delete those Storage objects via the user's own DELETE
    ///      permission on storage.objects.
    ///   3. Call `delete_my_account()` RPC which atomically removes all DB
    ///      rows in dependency order and finally deletes auth.users.
    ///   4. Clear local session state (mirrors signOut).
    func deleteAccount() async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        struct PhotoPath: Decodable {
            let storagePath: String
            enum CodingKeys: String, CodingKey { case storagePath = "storage_path" }
        }
        let ownPhotos: [PhotoPath] = (try? await client
            .from("photos")
            .select("storage_path")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value) ?? []

        let createdEvents: [EventModel] = (try? await client
            .from("events")
            .select()
            .eq("creator_id", value: userId.uuidString)
            .execute()
            .value) ?? []

        var allPaths = ownPhotos.map { $0.storagePath }
        for event in createdEvents {
            let eventPhotos: [PhotoPath] = (try? await client
                .from("photos")
                .select("storage_path")
                .eq("event_id", value: event.id.uuidString)
                .execute()
                .value) ?? []
            allPaths.append(contentsOf: eventPhotos.map { $0.storagePath })
        }

        if !allPaths.isEmpty {
            do {
                _ = try await client.storage
                    .from(storageBucket)
                    .remove(paths: allPaths)
                debugLog("✅ Deleted \(allPaths.count) Storage objects")
            } catch {
                debugLog("⚠️ Storage cleanup partial-fail: \(error). Continuing with RPC.")
            }
        }

        // Avatar — best-effort wipe of the whole folder. Avatars are stored
        // at random paths, and the object serves from a public URL, so a
        // missed delete would leave the user's face up after account
        // deletion (5.1.1(v) / GDPR adjacent).
        await pruneOldAvatars(folder: userId.uuidString.lowercased(), keep: nil)

        try await client.rpc("delete_my_account").execute()

        // Mirror sign-out's full local-state clear. The shared helper
        // covers image cache, photo storage, notifications, analytics,
        // reveal state, and the offline-sync queue — all the surfaces
        // that would otherwise survive into the next sign-in.
        await clearLocalUserState()

        debugLog("✅ Account deleted")
    }

}

// MARK: - DisplayName sanitisation

/// Display-name validation rules. Kept in one place so onboarding,
/// profile edits, and any future paths agree.
enum DisplayName {
    static let minLength = 1
    static let maxLength = 30

    /// Trim whitespace and strip emoji. Returns the cleaned string.
    static func sanitise(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation && !($0.properties.isEmoji && $0.value > 0x2000) }
            .map(Character.init)
        return String(stripped).prefix(maxLength).description
    }

    /// True if the sanitised form is a valid display name.
    static func isValid(_ input: String) -> Bool {
        let cleaned = sanitise(input)
        return cleaned.count >= minLength
    }
}
