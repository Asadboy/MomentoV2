//
//  SupabaseManager+Likes.swift
//  Momento
//
//  Photo-likes queries: per-user liked photos, per-user liked counts, and
//  the aggregate "total likes across all users" count used by past-event
//  done-pile stats.
//

import Foundation
import Supabase

extension SupabaseManager {

    /// Insert a like row for the current user on a photo.
    func likePhoto(photoId: UUID) async throws {
        guard let userId = currentUser?.id else { return }
        try await client
            .from("photo_likes")
            .insert(["photo_id": photoId.uuidString, "user_id": userId.uuidString])
            .execute()
    }

    /// Remove the current user's like on a photo.
    func unlikePhoto(photoId: UUID) async throws {
        guard let userId = currentUser?.id else { return }
        try await client
            .from("photo_likes")
            .delete()
            .eq("photo_id", value: photoId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Photos the current user has liked in a given event, with signed URLs.
    func getLikedPhotos(eventId: UUID) async throws -> [PhotoData] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // Lightweight row used only here. Reads captured_by (preferred)
        // with username fallback for legacy rows.
        struct PhotoRow: Decodable {
            let id: UUID
            let storagePath: String
            let capturedAt: Date
            let capturedBy: String?
            let username: String?

            var photographerName: String {
                capturedBy ?? username ?? "Unknown"
            }

            enum CodingKeys: String, CodingKey {
                case id
                case storagePath = "storage_path"
                case capturedAt = "captured_at"
                case capturedBy = "captured_by"
                case username
            }
        }

        let photos: [PhotoRow] = try await client
            .from("photos")
            .select("id, storage_path, captured_at, captured_by, username")
            .eq("event_id", value: eventId.uuidString)
            .is("hidden_at", value: nil)
            .order("captured_at", ascending: true)
            .execute()
            .value

        let photoIds = photos.map { $0.id.uuidString }
        if photoIds.isEmpty { return [] }

        let likes: [PhotoLike] = try await client
            .from("photo_likes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("photo_id", values: photoIds)
            .execute()
            .value

        let likedPhotoIds = Set(likes.map { $0.photoId.uuidString })
        let likedPhotos = photos.filter { likedPhotoIds.contains($0.id.uuidString) }

        if likedPhotos.isEmpty { return [] }

        let result = await withTaskGroup(of: (Int, PhotoData?).self) { group in
            for (index, photo) in likedPhotos.enumerated() {
                group.addTask {
                    let signedURL = try? await self.client.storage
                        .from(self.storageBucket)
                        .createSignedURL(path: photo.storagePath, expiresIn: 2592000)

                    let photoData = PhotoData(
                        id: photo.id.uuidString,
                        url: signedURL,
                        capturedAt: photo.capturedAt,
                        photographerName: photo.photographerName
                    )
                    return (index, photoData)
                }
            }

            var results: [(Int, PhotoData)] = []
            for await r in group {
                if let photoData = r.1 {
                    results.append((r.0, photoData))
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        return result
    }

    /// Count of the current user's likes within an event.
    func getLikedPhotoCount(eventId: UUID) async throws -> Int {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        struct PhotoId: Decodable { let id: UUID }
        let photos: [PhotoId] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
            .is("hidden_at", value: nil)
            .execute()
            .value

        let photoIds = photos.map { $0.id.uuidString }
        if photoIds.isEmpty { return 0 }

        return try await client
            .from("photo_likes")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .in("photo_id", values: photoIds)
            .execute()
            .count ?? 0
    }

    /// Total likes across ALL users on an event's photos. Drives the
    /// past-event done-pile aggregate count.
    func getTotalLikeCount(eventId: UUID) async throws -> Int {
        struct PhotoId: Decodable { let id: UUID }
        let photos: [PhotoId] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
            .is("hidden_at", value: nil)
            .execute()
            .value

        let photoIds = photos.map { $0.id.uuidString }
        if photoIds.isEmpty { return 0 }

        return try await client
            .from("photo_likes")
            .select("*", head: true, count: .exact)
            .in("photo_id", values: photoIds)
            .execute()
            .count ?? 0
    }
}
