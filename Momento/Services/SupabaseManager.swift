//
//  SupabaseManager.swift
//  Momento
//
//  Singleton manager for all Supabase operations
//  Handles authentication, database queries, and storage
//

import Foundation
import Supabase

enum SupabaseError: LocalizedError {
    case userNotAuthenticated
    case eventNotFound
    case invalidEventID
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "User not authenticated"
        case .eventNotFound: return "Event not found"
        case .invalidEventID: return "Invalid event ID"
        case .configurationError(let msg): return msg
        }
    }
}

/// Centralized Supabase client manager
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    private let storageBucket = "momento-photos"

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    /// True once the initial session check has completed (prevents login screen flash)
    @Published var hasCompletedInitialCheck = false
    
    private init() {
        // Validate configuration
        guard SupabaseConfig.isConfigured else {
            fatalError("Supabase not configured! Check SupabaseConfig.swift")
        }
        
        // Initialize Supabase client with OAuth redirect
        client = SupabaseClient(
            supabaseURL: {
                guard let url = URL(string: SupabaseConfig.supabaseURL) else {
                    fatalError("Invalid Supabase URL: '\(SupabaseConfig.supabaseURL)'. Check SupabaseConfig.swift")
                }
                return url
            }(),
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: URL(string: "momento://auth/callback")
                )
            )
        )
        
        debugLog("✅ Supabase configured successfully")
        debugLog("📍 URL: \(SupabaseConfig.supabaseURL)")
    }
    
    // MARK: - Session Management
    
    /// Check if user has an existing session
    func checkSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.currentUser = session.user
                self.isAuthenticated = true
                self.hasCompletedInitialCheck = true
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.hasCompletedInitialCheck = true
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        await MainActor.run {
            self.currentUser = session.user
            self.isAuthenticated = true
        }
        
        // Create profile if doesn't exist
        try await createProfileIfNeeded(user: session.user)

        return session.user
    }

    /// Sign in with Google
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        
        await MainActor.run {
            self.currentUser = session.user
            self.isAuthenticated = true
        }
        
        // Create profile if doesn't exist
        try await createProfileIfNeeded(user: session.user)

        return session.user
    }

    /// Handle OAuth callback URL (called from MomentoApp)
    func handleOAuthCallback(url: URL) async {
        do {
            try await client.auth.session(from: url)
            await checkSession()
            debugLog("✅ OAuth callback handled successfully")
        } catch {
            debugLog("❌ OAuth callback error: \(error)")
        }
    }
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws -> User {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        await MainActor.run {
            self.currentUser = session.user
            self.isAuthenticated = true
        }
        
        return session.user
    }
    
    /// Sign up with email and password
    func signUpWithEmail(email: String, password: String, username: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        let user = response.user
        
        // Create profile
        try await createProfile(userId: user.id, username: username)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
        
        return user
    }
    
    /// Sign out and clear all app state
    func signOut() async throws {
        try await client.auth.signOut()

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false

            // Clear all singleton state to prevent data leaking between accounts
            OfflineSyncManager.shared.clearQueue()
            RevealStateManager.shared.clearAllCompletedReveals()
        }

        debugLog("✅ User signed out")
    }
    
    // MARK: - Profile Management
    
    /// Create user profile if it doesn't exist
    private func createProfileIfNeeded(user: User) async throws {
        // Check if profile exists
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .execute()
            .value
        
        if response.isEmpty {
            // Generate username from email
            let email = user.email ?? "user"
            let username = email.components(separatedBy: "@").first ?? "user"
            let uniqueUsername = "\(username)\(Int.random(in: 1000...9999))"
            
            try await createProfile(userId: user.id, username: uniqueUsername)
        }
    }
    
    /// Create user profile
    private func createProfile(userId: UUID, username: String) async throws {
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
    
    /// Get user profile
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
    
    /// Update user profile
    func updateProfile(userId: UUID, updates: [String: AnyJSON]) async throws {
        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()

        debugLog("✅ Profile updated")
    }

    /// Check if user needs to set their username (has auto-generated username)
    func needsUsernameSelection(userId: UUID) async throws -> Bool {
        let profile = try await getUserProfile(userId: userId)

        // Pattern: auto-generated usernames end with exactly 4 digits
        let pattern = ".*\\d{4}$"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: profile.username.utf16.count)

        return regex.firstMatch(in: profile.username, range: range) != nil
    }

    /// Check if a username is available (unique in database)
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let normalized = username.lowercased()

        let response = try await client
            .from("profiles")
            .select("username", head: true, count: .exact)
            .eq("username", value: normalized)
            .execute()

        return response.count == 0
    }

    /// Update user's username (only if current username is auto-generated)
    func updateUsername(userId: UUID, newUsername: String) async throws {
        let normalized = newUsername.lowercased()

        // Verify uniqueness
        let isAvailable = try await checkUsernameAvailability(normalized)
        guard isAvailable else {
            throw SupabaseError.configurationError("Username is already taken")
        }

        // Update profile
        try await client
            .from("profiles")
            .update(["username": AnyJSON.string(normalized)])
            .eq("id", value: userId.uuidString)
            .execute()

        debugLog("✅ Username updated to: \(normalized)")
    }

    // MARK: - Event Management
    
    /// Create a new event (auto-calculates end and reveal times)
    /// - Parameters:
    ///   - name: Event name
    ///   - startsAt: When the event begins (photos accepted for 12h, reveal at 24h)
    ///   - joinCode: Unique code for joining
    /// - Returns: The created EventModel
    func createEvent(name: String, startsAt: Date, joinCode: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            debugLog("[createEvent] Error: User not authenticated")
            throw SupabaseError.userNotAuthenticated
        }

        // Auto-calculate event times from start
        let endsAt = startsAt.addingTimeInterval(12 * 3600)  // +12 hours
        let releaseAt = startsAt.addingTimeInterval(24 * 3600) // +24 hours
        debugLog("[createEvent] Creating: \(name)")
        debugLog("[createEvent] Starts: \(startsAt), Ends: \(endsAt), Reveals: \(releaseAt)")

        let event = EventModel(
            id: UUID(),
            name: name,
            creatorId: userId,
            joinCode: joinCode,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt,
            isDeleted: false,
            createdAt: Date()
        )
        
        try await client
            .from("events")
            .insert(event)
            .execute()
        
        debugLog("[createEvent] Event saved, adding creator as member...")
        
        // Auto-join the creator (non-fatal — a DB trigger may have already added them)
        let member = EventMember(
            eventId: event.id,
            userId: userId,
            joinedAt: Date()
        )

        do {
            try await client
                .from("event_members")
                .insert(member)
                .execute()
        } catch {
            debugLog("[createEvent] Member insert failed (likely already exists): \(error)")
        }
        
        debugLog("[createEvent] Success: \(name) with code \(joinCode)")
        return event
    }
    
    /// Join an event with a code (uses secure RPC for lookup)
    func joinEvent(code: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // Find event by join code using secure RPC
        let event = try await lookupEvent(code: code)

        // Check if already a member
        let existingMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: event.id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if !existingMembers.isEmpty {
            debugLog("ℹ️ Already a member of this event")
            return event
        }

        // Join the event
        let member = EventMember(
            eventId: event.id,
            userId: userId,
            joinedAt: Date()
        )

        try await client
            .from("event_members")
            .insert(member)
            .execute()

        // Track successful join
        AnalyticsManager.shared.track(.eventJoined, properties: [
            "event_id": event.id.uuidString,
            "join_method": "code"
        ])

        debugLog("✅ Joined event: \(event.name)")
        return event
    }

    /// Lookup an event by code without joining (for preview)
    /// Uses secure RPC function - only returns event if exact code matches
    func lookupEvent(code: String) async throws -> EventModel {
        // Use secure RPC to lookup event by code
        // This prevents enumeration of all events
        let events: [EventModel] = try await client
            .rpc("lookup_event_by_code", params: ["lookup_code": code])
            .execute()
            .value

        guard let event = events.first else {
            throw SupabaseError.eventNotFound
        }

        return event
    }

    /// Get all events the user is a member of
    func getMyEvents() async throws -> [EventModel] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }
        
        // Get event IDs from event_members
        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        let eventIds = members.map { $0.eventId.uuidString }
        
        if eventIds.isEmpty {
            return []
        }
        
        // Get events (excluding soft-deleted ones)
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .in("id", values: eventIds)
            .eq("is_deleted", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        debugLog("✅ Fetched \(events.count) events")
        return events
    }
    
    /// Get a single event by ID
    func getEvent(id: UUID) async throws -> EventModel {
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .eq("id", value: id.uuidString)
            .execute()
            .value
        
        guard let event = events.first else {
            throw SupabaseError.eventNotFound
        }
        
        return event
    }
    
    /// Soft-delete an event (creator only) - marks as deleted instead of removing
    func deleteEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        try await client
            .from("events")
            .update(["is_deleted": true])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        debugLog("Soft-deleted event: \(id.uuidString.prefix(8))...")
    }

    /// Restore a soft-deleted event
    func restoreEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        try await client
            .from("events")
            .update(["is_deleted": false])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        debugLog("Restored event: \(id.uuidString.prefix(8))...")
        
        debugLog("✅ Event deleted")
    }
    
    /// Leave an event
    func leaveEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }
        
        try await client
            .from("event_members")
            .delete()
            .eq("event_id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        debugLog("✅ Left event")
    }
    
    // MARK: - Event Counts (computed from related tables)

    /// Get the number of members in an event (computed from event_members table)
    func getEventMemberCount(eventId: UUID) async throws -> Int {
        try await client
            .from("event_members")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .count ?? 0
    }

    /// Get the number of photos in an event (computed from photos table)
    func getEventPhotoCount(eventId: UUID) async throws -> Int {
        try await client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .count ?? 0
    }

    // MARK: - Members With Shots (People-Dots Card)

    /// Fetch all members of an event with their profile info and shot counts.
    /// Returns members sorted: current user first, then by shots taken descending.
    func getEventMembersWithShots(eventId: UUID) async throws -> [MemberWithShots] {
        guard let currentUserId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // 1. Get member user IDs for this event
        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        if members.isEmpty { return [] }

        // 2. Fetch profiles and photo counts per member in parallel
        let results = try await withThrowingTaskGroup(of: MemberWithShots?.self) { group in
            for member in members {
                group.addTask {
                    let profile = try? await self.getUserProfile(userId: member.userId)
                    let count = (try? await self.getPhotoCount(eventId: eventId, userId: member.userId)) ?? 0
                    guard let profile else { return nil }
                    return MemberWithShots(
                        userId: member.userId.uuidString,
                        username: profile.username,
                        displayName: profile.displayName,
                        avatarUrl: profile.avatarUrl,
                        shotsTaken: count
                    )
                }
            }

            var memberShots: [MemberWithShots] = []
            for try await result in group {
                if let member = result {
                    memberShots.append(member)
                }
            }
            return memberShots
        }

        var memberShots = results
        debugLog("[MembersWithShots] Event \(eventId.uuidString.prefix(8)): \(members.count) members, \(memberShots.count) with profiles")

        // 4. Sort: current user first, then by shots descending
        memberShots.sort { a, b in
            if a.userId == currentUserId.uuidString { return true }
            if b.userId == currentUserId.uuidString { return false }
            return a.shotsTaken > b.shotsTaken
        }

        return memberShots
    }

    // MARK: - Photo Management

    /// Upload a photo to an event
    func uploadPhoto(image: Data, eventId: UUID, width: Int? = nil, height: Int? = nil) async throws -> PhotoModel {
        guard let userId = currentUser?.id else {
            debugLog("❌ [uploadPhoto] User not authenticated")
            throw SupabaseError.userNotAuthenticated
        }
        
        // Get user's username for photo attribution
        let username: String
        do {
            let profile = try await getUserProfile(userId: userId)
            // Use username (e.g., "Asad") not displayName (e.g., "Asad Amjid")
            username = profile.username
        } catch {
            username = "Unknown"
            debugLog("⚠️ Could not fetch username, using 'Unknown'")
        }
        
        // Generate unique filename
        let photoId = UUID()
        let fileName = "\(eventId.uuidString)/\(photoId.uuidString).jpg"
        
        debugLog("📤 Uploading \(image.count / 1024)KB to \(eventId.uuidString.prefix(8)) by \(username)...")
        
        // Upload to storage
        _ = try await client.storage
            .from(self.storageBucket)
            .upload(
                fileName,
                data: image,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        // Create photo record with storage path and username
        let photo = PhotoModel(
            id: photoId,
            eventId: eventId,
            userId: userId,
            storagePath: fileName,
            capturedAt: Date(),
            username: username,
            width: width,
            height: height,
            uploadStatus: "uploaded",
            isFlagged: false
        )
        
        try await client
            .from("photos")
            .insert(photo)
            .execute()
        
        return photo
    }
    
    /// Get photos for an event
    func getPhotos(eventId: UUID) async throws -> [PhotoModel] {
        let photos: [PhotoModel] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .order("captured_at", ascending: false)
            .execute()
            .value
        
        return photos
    }

    /// Get the number of photos a user has taken for a specific event
    func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int {
        try await client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count ?? 0
    }

    /// Lightweight photo row used when joining profile info for reveal/gallery
    private struct PhotoWithProfile: Codable {
        let id: UUID
        let eventId: UUID
        let userId: UUID
        let storagePath: String
        let capturedAt: Date
        let username: String?

        enum CodingKeys: String, CodingKey {
            case id
            case eventId = "event_id"
            case userId = "user_id"
            case storagePath = "storage_path"
            case capturedAt = "captured_at"
            case username
        }
    }

    /// Get photos for an event (String ID overload for convenience)
    func getPhotos(for eventId: String) async throws -> [PhotoData] {
        guard let uuid = UUID(uuidString: eventId) else {
            throw SupabaseError.invalidEventID
        }

        let photos: [PhotoWithProfile] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: uuid.uuidString)
            .order("captured_at", ascending: true)
            .execute()
            .value
        
        // Convert to PhotoData with signed storage URLs in parallel
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
                        photographerName: photo.username ?? "Unknown"
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

    /// Fetch photos for reveal with pagination
    /// - Parameters:
    ///   - eventId: The event ID string
    ///   - offset: Starting index (0-based)
    ///   - limit: Number of photos to fetch (default 10)
    /// - Returns: Tuple of (photos, hasMore)
    func fetchPhotosForRevealPaginated(
        eventId: String,
        offset: Int = 0,
        limit: Int = 10
    ) async throws -> (photos: [PhotoData], hasMore: Bool) {
        guard let uuid = UUID(uuidString: eventId) else {
            throw SupabaseError.invalidEventID
        }

        // Fetch limit + 1 to know if there are more
        let photos: [PhotoWithProfile] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: uuid.uuidString)
            .order("captured_at", ascending: true)
            .range(from: offset, to: offset + limit)
            .execute()
            .value

        let hasMore = photos.count > limit
        let photosToProcess = hasMore ? Array(photos.prefix(limit)) : photos

        // Generate signed URLs in parallel for speed
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
                        photographerName: photo.username ?? "Unknown"
                    )
                    return (index, photoData)
                }
            }

            // Collect results maintaining order
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

    /// Delete a photo (creator or photo owner)
    func deletePhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        debugLog("✅ Photo deleted")
    }
    
    /// Flag a photo for moderation (updates upload_status)
    func flagPhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .update(["upload_status": "flagged"])
            .eq("id", value: id.uuidString)
            .execute()
        
        debugLog("✅ Photo flagged")
    }
    
    // MARK: - Real-time Subscriptions

    // MARK: - Photo Likes

    /// Like a photo
    func likePhoto(photoId: UUID) async throws {
        guard let userId = currentUser?.id else { return }
        try await client
            .from("photo_likes")
            .insert(["photo_id": photoId.uuidString, "user_id": userId.uuidString])
            .execute()
    }

    /// Unlike a photo
    func unlikePhoto(photoId: UUID) async throws {
        guard let userId = currentUser?.id else { return }
        try await client
            .from("photo_likes")
            .delete()
            .eq("photo_id", value: photoId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    /// Get user's liked photos for an event
    func getLikedPhotos(eventId: UUID) async throws -> [PhotoData] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // Get photo IDs + storage paths for this event (lightweight query)
        struct PhotoRow: Decodable {
            let id: UUID
            let storagePath: String
            let capturedAt: Date
            let username: String?

            enum CodingKeys: String, CodingKey {
                case id
                case storagePath = "storage_path"
                case capturedAt = "captured_at"
                case username
            }
        }

        let photos: [PhotoRow] = try await client
            .from("photos")
            .select("id, storage_path, captured_at, username")
            .eq("event_id", value: eventId.uuidString)
            .order("captured_at", ascending: true)
            .execute()
            .value

        let photoIds = photos.map { $0.id.uuidString }
        if photoIds.isEmpty { return [] }

        // Get user's likes for these photos
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

        // Sign URLs in parallel (like fetchPhotosForRevealPaginated does)
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
                        photographerName: photo.username
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

    /// Get count of user's liked photos for an event
    func getLikedPhotoCount(eventId: UUID) async throws -> Int {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        // Get photo IDs for this event (lightweight — only IDs, no full rows)
        struct PhotoId: Decodable { let id: UUID }
        let photos: [PhotoId] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        let photoIds = photos.map { $0.id.uuidString }
        if photoIds.isEmpty { return 0 }

        // Count likes using HEAD request
        return try await client
            .from("photo_likes")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .in("photo_id", values: photoIds)
            .execute()
            .count ?? 0
    }

    /// Get total likes across ALL users for an event's photos
    func getTotalLikeCount(eventId: UUID) async throws -> Int {
        struct PhotoId: Decodable { let id: UUID }
        let photos: [PhotoId] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
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

    // MARK: - Profile Stats

    /// Get all stats for the user's profile
    func getProfileStats() async throws -> ProfileStats {
        guard let userId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        let uid = userId.uuidString

        // Run all independent count queries in parallel
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

        // Await all in parallel
        let (eventsJoinedResult, eventsHostedResult, photosTakenResult, photosLikedResult, profileResult) =
            try await (eventsJoinedTask, eventsHostedTask, photosTakenTask, photosLikedTask, profileTask)

        let eventsJoined = eventsJoinedResult.count ?? 0
        let eventsHosted = eventsHostedResult.count ?? 0
        let photosTaken = photosTakenResult.count ?? 0
        let photosLiked = photosLikedResult.count ?? 0

        // User number needs the profile created_at first
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

// MARK: - Models

struct UserProfile: Codable {
    let id: UUID
    let username: String
    var displayName: String?
    var avatarUrl: String?
    var deviceToken: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case deviceToken = "device_token"
        case createdAt = "created_at"
    }
}

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
    }
}

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

struct PhotoModel: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    let capturedAt: Date
    var username: String
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
        case username
        case width
        case height
        case uploadStatus = "upload_status"
        case isFlagged = "is_flagged"
    }
}

/// Simplified photo data for reveal UI
struct PhotoData: Identifiable {
    let id: String
    let url: URL?
    let capturedAt: Date
    let photographerName: String?
}

/// A user's like on a photo
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

/// A member of an event with their shot count (for people-dots card)
struct MemberWithShots: Identifiable {
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let shotsTaken: Int

    var id: String { userId }

    /// Display name with fallback to username
    var name: String {
        displayName ?? username
    }
}

/// User profile statistics for display
struct ProfileStats {
    let eventsJoined: Int
    let eventsHosted: Int
    let photosTaken: Int
    let photosLiked: Int
    let userNumber: Int
}
