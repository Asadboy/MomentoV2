//
//  SupabaseManager.swift
//  Momento
//
//  Singleton manager for all Supabase operations
//  Handles authentication, database queries, and storage
//

import Foundation
import Supabase

/// Centralized Supabase client manager
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        // Validate configuration
        guard SupabaseConfig.isConfigured else {
            fatalError("Supabase not configured! Check SupabaseConfig.swift")
        }
        
        // Initialize Supabase client with OAuth redirect
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: URL(string: "momento://auth/callback")
                )
            )
        )
        
        // Check for existing session
        Task {
            await checkSession()
        }
        
        print("✅ Supabase configured successfully")
        print("📍 URL: \(SupabaseConfig.supabaseURL)")
    }
    
    // MARK: - Session Management
    
    /// Check if user has an existing session
    func checkSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.currentUser = session.user
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
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
            print("✅ OAuth callback handled successfully")
        } catch {
            print("❌ OAuth callback error: \(error)")
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

        print("✅ User signed out")
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
        
        print("✅ Profile created for user: \(username)")
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
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
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

        print("✅ Profile updated")
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
            throw NSError(
                domain: "SupabaseManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Username is already taken"]
            )
        }

        // Update profile
        try await client
            .from("profiles")
            .update(["username": AnyJSON.string(normalized)])
            .eq("id", value: userId.uuidString)
            .execute()

        print("✅ Username updated to: \(normalized)")
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
            print("[createEvent] Error: User not authenticated")
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Auto-calculate event times from start
        let endsAt = startsAt.addingTimeInterval(12 * 3600)  // +12 hours
        let releaseAt = startsAt.addingTimeInterval(24 * 3600) // +24 hours
        let expiresAt = releaseAt.addingTimeInterval(30 * 24 * 3600) // +30 days (launch grace period)

        print("[createEvent] Creating: \(name)")
        print("[createEvent] Starts: \(startsAt), Ends: \(endsAt), Reveals: \(releaseAt)")

        let event = EventModel(
            id: UUID(),
            name: name,
            creatorId: userId,
            joinCode: joinCode,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt,
            isPremium: false,
            isDeleted: false,
            memberCount: 0,
            photoCount: 0,
            expiresAt: expiresAt,
            premiumPurchasedAt: nil,
            premiumTransactionId: nil,
            createdAt: Date()
        )
        
        try await client
            .from("events")
            .insert(event)
            .execute()
        
        print("[createEvent] Event saved, adding creator as member...")
        
        // Auto-join the creator
        let member = EventMember(
            eventId: event.id,
            userId: userId,
            joinedAt: Date()
        )
        
        try await client
            .from("event_members")
            .insert(member)
            .execute()
        
        print("[createEvent] Success: \(name) with code \(joinCode)")
        return event
    }
    
    /// Join an event with a code (uses secure RPC for lookup)
    func joinEvent(code: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
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
            print("ℹ️ Already a member of this event")
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
        AnalyticsManager.shared.track(.momentoJoined, properties: [
            "event_id": event.id.uuidString,
            "join_method": "code"
        ])

        print("✅ Joined event: \(event.name)")
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
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No event found with code: \(code)"])
        }

        return event
    }

    /// Get all events the user is a member of
    func getMyEvents() async throws -> [EventModel] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
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
        
        print("✅ Fetched \(events.count) events")
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
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }
        
        return event
    }
    
    /// Soft-delete an event (creator only) - marks as deleted instead of removing
    func deleteEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await client
            .from("events")
            .update(["is_deleted": true])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        print("Soft-deleted event: \(id.uuidString.prefix(8))...")
    }

    /// Restore a soft-deleted event
    func restoreEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await client
            .from("events")
            .update(["is_deleted": false])
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()

        print("Restored event: \(id.uuidString.prefix(8))...")
        
        print("✅ Event deleted")
    }
    
    /// Leave an event
    func leaveEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await client
            .from("event_members")
            .delete()
            .eq("event_id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Left event")
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

    // MARK: - Photo Management

    /// Upload a photo to an event
    func uploadPhoto(image: Data, eventId: UUID, width: Int? = nil, height: Int? = nil) async throws -> PhotoModel {
        guard let userId = currentUser?.id else {
            print("❌ [uploadPhoto] User not authenticated")
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get user's username for photo attribution
        let username: String
        do {
            let profile = try await getUserProfile(userId: userId)
            // Use username (e.g., "Asad") not displayName (e.g., "Asad Amjid")
            username = profile.username
        } catch {
            username = "Unknown"
            print("⚠️ Could not fetch username, using 'Unknown'")
        }
        
        // Photo limit check - disabled for beta testing
        // TODO: Re-enable with premium tier check after beta
        
        // Generate unique filename
        let photoId = UUID()
        let fileName = "\(eventId.uuidString)/\(photoId.uuidString).jpg"
        
        print("📤 Uploading \(image.count / 1024)KB to \(eventId.uuidString.prefix(8)) by \(username)...")
        
        // Upload to storage
        _ = try await client.storage
            .from("momento-photos")
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
    
    /// Get photos for an event (String ID overload for convenience)
    func getPhotos(for eventId: String) async throws -> [PhotoData] {
        guard let uuid = UUID(uuidString: eventId) else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event ID"])
        }
        
        // Fetch photos with user profile info
        struct PhotoWithProfile: Codable {
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
        
        let photos: [PhotoWithProfile] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: uuid.uuidString)
            .order("captured_at", ascending: true)
            .execute()
            .value
        
        // Convert to PhotoData with signed storage URLs (bucket is private)
        var photoDataArray: [PhotoData] = []
        
        for photo in photos {
            // Get signed URL for photo (expires in 7 days)
            let signedURL = try? await client.storage
                .from("momento-photos")
                .createSignedURL(path: photo.storagePath, expiresIn: 604800)
            
            photoDataArray.append(PhotoData(
                id: photo.id.uuidString,
                url: signedURL,
                capturedAt: photo.capturedAt,
                photographerName: photo.username ?? "Unknown"
            ))
        }

        print("📸 Loaded \(photoDataArray.count) photos with signed URLs")
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
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event ID"])
        }

        struct PhotoWithProfile: Decodable {
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
                        .from("momento-photos")
                        .createSignedURL(path: photo.storagePath, expiresIn: 604800)

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

        print("📸 Loaded \(photoDataArray.count) photos (offset: \(offset), hasMore: \(hasMore))")
        return (photos: photoDataArray, hasMore: hasMore)
    }

    /// Delete a photo (creator or photo owner)
    func deletePhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        print("✅ Photo deleted")
    }
    
    /// Flag a photo for moderation (updates upload_status)
    func flagPhoto(id: UUID) async throws {
        try await client
            .from("photos")
            .update(["upload_status": "flagged"])
            .eq("id", value: id.uuidString)
            .execute()
        
        print("✅ Photo flagged")
    }
    
    // MARK: - Real-time Subscriptions

    /// Subscribe to event updates (member count, photo count, reveal status)
    /// TODO: Fix RealtimeV2 API once we have proper documentation
    func subscribeToEvent(eventId: UUID) -> AsyncStream<EventModel> {
        // Temporarily disabled - RealtimeV2 API has changed
        // Not critical for reveal system testing
        AsyncStream { continuation in
            // Return empty stream for now
            continuation.finish()
        }
    }

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
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Get photos for this event that user has liked
        let photos = try await getPhotos(eventId: eventId)
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

        // Filter and convert to PhotoData with signed URLs
        var likedPhotos: [PhotoData] = []
        for photo in photos where likedPhotoIds.contains(photo.id.uuidString) {
            let signedURL = try? await client.storage
                .from("momento-photos")
                .createSignedURL(path: photo.storagePath, expiresIn: 604800)

            likedPhotos.append(PhotoData(
                id: photo.id.uuidString,
                url: signedURL,
                capturedAt: photo.capturedAt,
                photographerName: photo.username
            ))
        }

        return likedPhotos.sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Get count of user's liked photos for an event
    func getLikedPhotoCount(eventId: UUID) async throws -> Int {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let photos = try await getPhotos(eventId: eventId)
        let photoIds = photos.map { $0.id.uuidString }

        if photoIds.isEmpty { return 0 }

        let likes: [PhotoLike] = try await client
            .from("photo_likes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("photo_id", values: photoIds)
            .execute()
            .value

        return likes.count
    }

    // MARK: - Profile Stats

    /// Get all stats for the user's profile
    func getProfileStats() async throws -> ProfileStats {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "MomentoError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }

        // Events joined
        let eventsJoined = try await client
            .from("event_members")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count ?? 0

        // Photos taken
        let photosTaken = try await client
            .from("photos")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count ?? 0

        // Photos liked
        let photosLiked = try await client
            .from("photo_likes")
            .select("*", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .count ?? 0

        // User number
        let profile = try await client
            .from("profiles")
            .select("created_at")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profileData = try decoder.decode([String: String].self, from: profile.data)
        let createdAt = profileData["created_at"] ?? ""

        let userNumber = try await client
            .from("profiles")
            .select("*", head: true, count: .exact)
            .lte("created_at", value: createdAt)
            .execute()
            .count ?? 0

        return ProfileStats(
            eventsJoined: eventsJoined,
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
    var isPremium: Bool
    var isDeleted: Bool
    var memberCount: Int
    var photoCount: Int
    var expiresAt: Date?
    var premiumPurchasedAt: Date?
    var premiumTransactionId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creatorId = "creator_id"
        case joinCode = "join_code"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case releaseAt = "release_at"
        case isPremium = "is_premium"
        case isDeleted = "is_deleted"
        case memberCount = "member_count"
        case photoCount = "photo_count"
        case expiresAt = "expires_at"
        case premiumPurchasedAt = "premium_purchased_at"
        case premiumTransactionId = "premium_transaction_id"
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

/// User profile statistics for display
struct ProfileStats {
    let eventsJoined: Int
    let photosTaken: Int
    let photosLiked: Int
    let userNumber: Int
}
