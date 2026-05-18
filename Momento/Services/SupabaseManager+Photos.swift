//
//  SupabaseManager+Photos.swift
//  Momento
//
//  Photo uploads, fetches, counts, and moderation operations.
//

import Foundation
import Supabase

extension SupabaseManager {

    /// Number of photos uploaded to an event.
    func getEventPhotoCount(eventId: UUID) async throws -> Int {
        try await client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .count ?? 0
    }

    /// Upload a photo: storage object first, then the photos row. The row
    /// denormalises the photographer's display name into `captured_by` so
    /// the reveal flow doesn't have to join `profiles`.
    func uploadPhoto(image: Data, eventId: UUID, clientUploadId: UUID? = nil, width: Int? = nil, height: Int? = nil) async throws -> PhotoModel {
        guard let userId = currentUser?.id else {
            debugLog("❌ [uploadPhoto] User not authenticated")
            throw SupabaseError.userNotAuthenticated
        }

        let capturedBy: String
        do {
            let profile = try await getUserProfile(userId: userId)
            capturedBy = profile.displayName
        } catch {
            capturedBy = "Unknown"
            debugLog("⚠️ Could not fetch display name, using 'Unknown'")
        }

        // Stable across retries when a clientUploadId is supplied so the
        // storage path and row id don't change between attempts.
        let photoId = clientUploadId ?? UUID()
        let fileName = "\(eventId.uuidString)/\(photoId.uuidString).jpg"

        debugLog("📤 Uploading \(image.count / 1024)KB to \(eventId.uuidString.prefix(8)) by \(capturedBy)...")

        _ = try await client.storage
            .from(self.storageBucket)
            .upload(
                fileName,
                data: image,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let photo = PhotoModel(
            id: photoId,
            eventId: eventId,
            userId: userId,
            storagePath: fileName,
            capturedAt: Date(),
            capturedBy: capturedBy,
            username: nil,
            width: width,
            height: height,
            uploadStatus: "uploaded",
            isFlagged: false,
            clientUploadId: clientUploadId
        )

        try await client
            .from("photos")
            .upsert(photo, onConflict: "client_upload_id", ignoreDuplicates: true)
            .execute()

        return photo
    }

    /// Raw photo rows for an event (used in admin / debugging paths).
    func getPhotos(eventId: UUID) async throws -> [PhotoModel] {
        let photos: [PhotoModel] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .is("hidden_at", value: nil)
            .order("captured_at", ascending: false)
            .execute()
            .value

        return photos
    }

    /// Number of photos a specific user has taken in a specific event.
    func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int {
        try await client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count ?? 0
    }

    /// All photos for an event with signed Storage URLs, ready for the reveal
    /// gallery to render. URLs are signed in parallel via TaskGroup.
    func getPhotos(for eventId: String) async throws -> [PhotoData] {
        guard let uuid = UUID(uuidString: eventId) else {
            throw SupabaseError.invalidEventID
        }

        let photos: [PhotoWithProfile] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: uuid.uuidString)
            .is("hidden_at", value: nil)
            .order("captured_at", ascending: true)
            .execute()
            .value

        let photoDataArray = await withTaskGroup(of: (Int, PhotoData?).self) { group in
            for (index, photo) in photos.enumerated() {
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
            for await result in group {
                if let photoData = result.1 {
                    results.append((result.0, photoData))
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        debugLog("📸 Loaded \(photoDataArray.count) photos with signed URLs")
        return photoDataArray
    }

    /// Paginated photo fetch for the reveal flow. Returns `hasMore` so the
    /// caller knows when to stop scrolling.
    func fetchPhotosForRevealPaginated(
        eventId: String,
        offset: Int = 0,
        limit: Int = 10
    ) async throws -> (photos: [PhotoData], hasMore: Bool) {
        guard let uuid = UUID(uuidString: eventId) else {
            throw SupabaseError.invalidEventID
        }

        // Fetch limit + 1 to know if there are more.
        let photos: [PhotoWithProfile] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: uuid.uuidString)
            .is("hidden_at", value: nil)
            .order("captured_at", ascending: true)
            .range(from: offset, to: offset + limit)
            .execute()
            .value

        let hasMore = photos.count > limit
        let photosToProcess = hasMore ? Array(photos.prefix(limit)) : photos

        let photoDataArray = await withTaskGroup(of: (Int, PhotoData?).self) { group in
            for (index, photo) in photosToProcess.enumerated() {
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
            for await result in group {
                if let photoData = result.1 {
                    results.append((result.0, photoData))
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        debugLog("📸 Loaded \(photoDataArray.count) photos (offset: \(offset), hasMore: \(hasMore))")
        return (photos: photoDataArray, hasMore: hasMore)
    }

    /// Delete a photo row. (RLS gates this to creator or photo owner.)
    func deletePhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        debugLog("✅ Photo deleted")
    }

    /// Mark a photo as flagged so moderation tooling can pick it up.
    func flagPhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .update(["upload_status": "flagged"])
            .eq("id", value: id.uuidString)
            .execute()

        debugLog("✅ Photo flagged")
    }

    /// Files a content report for a photo. `reporter_id` defaults to
    /// auth.uid() server-side; an AFTER INSERT trigger hides the photo
    /// for everyone on the first report (Apple Guideline 1.2).
    func reportPhoto(id: UUID, reason: String?) async throws {
        struct ReportInsert: Encodable {
            let photo_id: String
            let reason: String?
        }
        try await client
            .from("photo_reports")
            .insert(ReportInsert(photo_id: id.uuidString, reason: reason))
            .execute()

        debugLog("🚩 Photo reported")
    }
}

// MARK: - Helpers

/// Lightweight photo row used when joining profile info for reveal / gallery.
/// Reads `captured_by` (the new column) with a fallback to the legacy
/// `username` column for any rows uploaded before migration
/// `20260512150000_drop_username_requirement`.
struct PhotoWithProfile: Codable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    let capturedAt: Date
    let capturedBy: String?
    let username: String?

    var photographerName: String {
        capturedBy ?? username ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case capturedBy = "captured_by"
        case username
    }
}
