//
//  SupabaseDTOs.swift
//  Momento
//
//  Wire-format data transfer objects for Supabase tables. These are the
//  Codable shapes the Supabase SDK encodes / decodes — distinct from the
//  domain models in `Models/` which are what the app's view layer consumes.
//
//  Kept separate from `SupabaseManager` so the manager file stays focused on
//  behaviour (queries) and the DTOs can be moved or evolved without touching
//  query logic.
//

import Foundation

/// User profile row from the `profiles` table.
///
/// `displayName` is the only identity surfaced to users. `username` is
/// kept as a nullable dormant column in case @-handles are ever
/// reintroduced — see migration `20260512150000_drop_username_requirement`.
struct UserProfile: Codable {
    let id: UUID
    var username: String?
    var displayName: String
    var avatarUrl: String?
    var deviceToken: String?
    var profileSetupComplete: Bool
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case deviceToken = "device_token"
        case profileSetupComplete = "profile_setup_complete"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Event row from the `events` table.
struct EventModel: Codable, Identifiable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let joinCode: String
    let startsAt: Date
    let endsAt: Date
    let releaseAt: Date
    var isDeleted: Bool
    let createdAt: Date
    let memberLimit: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorId = "creator_id"
        case joinCode = "join_code"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case releaseAt = "release_at"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case memberLimit = "member_limit"
    }
}

/// Event membership row from the `event_members` table.
struct EventMember: Codable {
    let eventId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

/// Photo row from the `photos` table.
///
/// `capturedBy` is the photographer's display name at upload time —
/// denormalised so the reveal flow doesn't need to join `profiles`.
/// `username` is a dormant legacy column kept on the schema for old rows.
struct PhotoModel: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    let capturedAt: Date
    var capturedBy: String
    var username: String?
    var width: Int?
    var height: Int?
    var uploadStatus: String
    var isFlagged: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case capturedBy = "captured_by"
        case username
        case width
        case height
        case uploadStatus = "upload_status"
        case isFlagged = "is_flagged"
    }
}

/// A user's like on a photo, from the `photo_likes` table.
struct PhotoLike: Codable {
    let photoId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
