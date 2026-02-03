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
    
    /// Sign out
    func signOut() async throws {
        try await client.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
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
    
    // MARK: - Photo Management
    
    /// Upload a photo to an event
    func uploadPhoto(image: Data, eventId: UUID) async throws -> PhotoModel {
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
            width: nil,
            height: nil,
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

    // MARK: - Photo Interactions (Like/Archive)

    /// Record a photo interaction (like or archive)
    func setPhotoInteraction(photoId: UUID, status: InteractionStatus) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Upsert: insert or update if exists
        let interaction = [
            "photo_id": AnyJSON.string(photoId.uuidString),
            "user_id": AnyJSON.string(userId.uuidString),
            "status": AnyJSON.string(status.rawValue)
        ]

        try await client
            .from("photo_interactions")
            .upsert(interaction, onConflict: "photo_id,user_id")
            .execute()

        print("✅ Photo \(status.rawValue): \(photoId.uuidString.prefix(8))")
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

        // Get user's liked interactions for these photos
        let interactions: [PhotoInteraction] = try await client
            .from("photo_interactions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "liked")
            .in("photo_id", values: photoIds)
            .execute()
            .value

        let likedPhotoIds = Set(interactions.map { $0.photoId.uuidString })

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

        let interactions: [PhotoInteraction] = try await client
            .from("photo_interactions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "liked")
            .in("photo_id", values: photoIds)
            .execute()
            .value

        return interactions.count
    }

    /// Get user's archived photos for an event
    func getArchivedPhotos(eventId: UUID) async throws -> [PhotoData] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let photos = try await getPhotos(eventId: eventId)
        let photoIds = photos.map { $0.id.uuidString }

        if photoIds.isEmpty { return [] }

        let interactions: [PhotoInteraction] = try await client
            .from("photo_interactions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "archived")
            .in("photo_id", values: photoIds)
            .execute()
            .value

        let archivedPhotoIds = Set(interactions.map { $0.photoId.uuidString })

        var archivedPhotos: [PhotoData] = []
        for photo in photos where archivedPhotoIds.contains(photo.id.uuidString) {
            let signedURL = try? await client.storage
                .from("momento-photos")
                .createSignedURL(path: photo.storagePath, expiresIn: 604800)

            archivedPhotos.append(PhotoData(
                id: photo.id.uuidString,
                url: signedURL,
                capturedAt: photo.capturedAt,
                photographerName: photo.username
            ))
        }

        return archivedPhotos.sorted { $0.capturedAt < $1.capturedAt }
    }

    // MARK: - Reveal Progress

    /// Get user's reveal progress for an event
    func getRevealProgress(eventId: UUID) async throws -> UserRevealProgress? {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let progress: [UserRevealProgress] = try await client
            .from("user_reveal_progress")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return progress.first
    }

    /// Update user's reveal progress (current position in swipe stack)
    func updateRevealProgress(eventId: UUID, lastPhotoIndex: Int, completed: Bool) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let progress = [
            "event_id": AnyJSON.string(eventId.uuidString),
            "user_id": AnyJSON.string(userId.uuidString),
            "last_photo_index": AnyJSON.integer(lastPhotoIndex),
            "completed": AnyJSON.bool(completed),
            "updated_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
        ]

        try await client
            .from("user_reveal_progress")
            .upsert(progress, onConflict: "event_id,user_id")
            .execute()

        print("✅ Progress updated: \(lastPhotoIndex), completed: \(completed)")
    }

    // MARK: - Keepsakes

    /// Get all keepsakes the user has earned
    func getUserKeepsakes() async throws -> [EarnedKeepsake] {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Get user's earned keepsakes
        let userKeepsakes: [UserKeepsake] = try await client
            .from("user_keepsakes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if userKeepsakes.isEmpty {
            return []
        }

        // Get keepsake definitions
        let keepsakeIds = userKeepsakes.map { $0.keepsakeId.uuidString }
        let keepsakes: [Keepsake] = try await client
            .from("keepsakes")
            .select()
            .in("id", values: keepsakeIds)
            .execute()
            .value

        // Get total user count for rarity calculation
        let totalUsersResponse = try await client
            .from("profiles")
            .select("id", head: true, count: .exact)
            .execute()
        let totalUsers = max(totalUsersResponse.count ?? 1, 1)

        // Get count of users who have each keepsake
        var earnedKeepsakes: [EarnedKeepsake] = []

        for userKeepsake in userKeepsakes {
            guard let keepsake = keepsakes.first(where: { $0.id == userKeepsake.keepsakeId }) else {
                continue
            }

            // Count users with this keepsake
            let countResponse = try await client
                .from("user_keepsakes")
                .select("id", head: true, count: .exact)
                .eq("keepsake_id", value: keepsake.id.uuidString)
                .execute()
            let usersWithKeepsake = countResponse.count ?? 1

            let rarityPercentage = (Double(usersWithKeepsake) / Double(totalUsers)) * 100

            earnedKeepsakes.append(EarnedKeepsake(
                id: userKeepsake.id,
                keepsake: keepsake,
                earnedAt: userKeepsake.earnedAt,
                rarityPercentage: rarityPercentage
            ))
        }

        return earnedKeepsakes.sorted { $0.earnedAt > $1.earnedAt }
    }

    /// Check if user has a keepsake for a specific event
    func hasKeepsakeForEvent(eventId: UUID) async throws -> EarnedKeepsake? {
        guard let userId = currentUser?.id else {
            return nil
        }

        // Find keepsake linked to this event
        let keepsakes: [Keepsake] = try await client
            .from("keepsakes")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        guard let keepsake = keepsakes.first else {
            return nil
        }

        // Check if user has earned it
        let userKeepsakes: [UserKeepsake] = try await client
            .from("user_keepsakes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("keepsake_id", value: keepsake.id.uuidString)
            .execute()
            .value

        guard let userKeepsake = userKeepsakes.first else {
            return nil
        }

        // Get rarity
        let totalUsersResponse = try await client
            .from("profiles")
            .select("id", head: true, count: .exact)
            .execute()
        let totalUsers = max(totalUsersResponse.count ?? 1, 1)

        let countResponse = try await client
            .from("user_keepsakes")
            .select("id", head: true, count: .exact)
            .eq("keepsake_id", value: keepsake.id.uuidString)
            .execute()
        let usersWithKeepsake = countResponse.count ?? 1

        let rarityPercentage = (Double(usersWithKeepsake) / Double(totalUsers)) * 100

        return EarnedKeepsake(
            id: userKeepsake.id,
            keepsake: keepsake,
            earnedAt: userKeepsake.earnedAt,
            rarityPercentage: rarityPercentage
        )
    }

    // MARK: - Profile Stats

    /// Get all stats for the user's profile
    func getProfileStats() async throws -> ProfileStats {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Get user profile for created_at (user number calculation)
        let profile = try await getUserProfile(userId: userId)

        // 1. Moments captured (photos taken)
        let photosResponse = try await client
            .from("photos")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
        let momentsCaptured = photosResponse.count ?? 0

        // 2. Photos loved (liked interactions)
        let likedResponse = try await client
            .from("photo_interactions")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "liked")
            .execute()
        let photosLoved = likedResponse.count ?? 0

        // 3. Reveals completed
        let revealsResponse = try await client
            .from("user_reveal_progress")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .eq("completed", value: true)
            .execute()
        let revealsCompleted = revealsResponse.count ?? 0

        // 4. Momentos shared (events joined)
        let eventsResponse = try await client
            .from("event_members")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
        let momentosShared = eventsResponse.count ?? 0

        // 5. First Momento date
        let firstEventMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("joined_at", ascending: true)
            .limit(1)
            .execute()
            .value
        let firstMomentoDate = firstEventMembers.first?.joinedAt

        // 6. Friends captured with (unique co-attendees)
        let myEventMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let myEventIds = myEventMembers.map { $0.eventId.uuidString }
        var friendsSet = Set<String>()

        if !myEventIds.isEmpty {
            let allMembers: [EventMember] = try await client
                .from("event_members")
                .select()
                .in("event_id", values: myEventIds)
                .execute()
                .value

            for member in allMembers where member.userId != userId {
                friendsSet.insert(member.userId.uuidString)
            }
        }
        let friendsCapturedWith = friendsSet.count

        // 7. Most active Momento (event with most photos by user)
        let userPhotos: [PhotoModel] = try await client
            .from("photos")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        var photoCountByEvent: [UUID: Int] = [:]
        for photo in userPhotos {
            photoCountByEvent[photo.eventId, default: 0] += 1
        }

        var mostActiveMomento: String? = nil
        if let topEventId = photoCountByEvent.max(by: { $0.value < $1.value })?.key {
            let events: [EventModel] = try await client
                .from("events")
                .select()
                .eq("id", value: topEventId.uuidString)
                .execute()
                .value
            mostActiveMomento = events.first?.name
        }

        // 8. Most recent Momento
        let recentEventMembers: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("joined_at", ascending: false)
            .limit(1)
            .execute()
            .value

        var mostRecentMomento: String? = nil
        if let recentMember = recentEventMembers.first {
            let events: [EventModel] = try await client
                .from("events")
                .select()
                .eq("id", value: recentMember.eventId.uuidString)
                .execute()
                .value
            mostRecentMomento = events.first?.name
        }

        // 9. User number (count of profiles created before this user)
        let userNumberResponse = try await client
            .from("profiles")
            .select("id", head: true, count: .exact)
            .lte("created_at", value: ISO8601DateFormatter().string(from: profile.createdAt))
            .execute()
        let userNumber = userNumberResponse.count ?? 1

        return ProfileStats(
            momentsCaptured: momentsCaptured,
            photosLoved: photosLoved,
            revealsCompleted: revealsCompleted,
            momentosShared: momentosShared,
            firstMomentoDate: firstMomentoDate,
            friendsCapturedWith: friendsCapturedWith,
            mostActiveMomento: mostActiveMomento,
            mostRecentMomento: mostRecentMomento,
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

/// Photo interaction status (liked or archived)
enum InteractionStatus: String, Codable {
    case liked
    case archived
}

/// User's interaction with a photo (like/archive)
struct PhotoInteraction: Codable, Identifiable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let status: InteractionStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
    }
}

/// User's progress through reveal swipe stack
struct UserRevealProgress: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    var lastPhotoIndex: Int
    var completed: Bool
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case lastPhotoIndex = "last_photo_index"
        case completed
        case updatedAt = "updated_at"
    }
}

// MARK: - Keepsake Models

/// A keepsake definition (badge/collectible)
struct Keepsake: Codable, Identifiable {
    let id: UUID
    let name: String
    let artworkUrl: String
    let flavourText: String
    let eventId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artworkUrl = "artwork_url"
        case flavourText = "flavour_text"
        case eventId = "event_id"
        case createdAt = "created_at"
    }
}

/// A user's earned keepsake
struct UserKeepsake: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let keepsakeId: UUID
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case keepsakeId = "keepsake_id"
        case earnedAt = "earned_at"
    }
}

/// Combined keepsake with earning info for display
struct EarnedKeepsake: Identifiable {
    let id: UUID
    let keepsake: Keepsake
    let earnedAt: Date
    let rarityPercentage: Double
}

/// User profile statistics for display
struct ProfileStats {
    // Activity stats
    let momentsCaptured: Int
    let photosLoved: Int
    let revealsCompleted: Int
    let momentosShared: Int

    // Journey stats
    let firstMomentoDate: Date?
    let friendsCapturedWith: Int
    let mostActiveMomento: String?
    let mostRecentMomento: String?

    // Identity
    let userNumber: Int
}
