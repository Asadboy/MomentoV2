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
            print("✅ User session found: \(session.user.id)")
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
            print("ℹ️ No active session")
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
            firstName: nil,
            lastName: nil,
            displayName: username,
            avatarUrl: nil,
            isPremium: false,
            totalEventsJoined: 0,
            createdAt: Date(),
            updatedAt: Date()
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
    
    // MARK: - Event Management
    
    /// Create a new event with start/end times
    /// - Parameters:
    ///   - title: Event name
    ///   - startsAt: When the event begins (photos can be taken)
    ///   - endsAt: When photo-taking stops
    ///   - joinCode: Unique code for joining
    /// - Returns: The created EventModel
    func createEvent(title: String, startsAt: Date, endsAt: Date, joinCode: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            print("[createEvent] Error: User not authenticated")
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Calculate reveal time: same day as endsAt at 8pm, or 24h after if event ends late
        let calendar = Calendar.current
        var revealComponents = calendar.dateComponents([.year, .month, .day], from: endsAt)
        revealComponents.hour = 20 // 8pm
        revealComponents.minute = 0
        var releaseAt = calendar.date(from: revealComponents) ?? endsAt.addingTimeInterval(24 * 3600)
        
        // If event ends after 8pm, reveal next day at 8pm
        if endsAt > releaseAt {
            releaseAt = releaseAt.addingTimeInterval(24 * 3600)
        }
        
        print("[createEvent] Creating: \(title)")
        print("[createEvent] Starts: \(startsAt), Ends: \(endsAt), Reveals: \(releaseAt)")
        
        let event = EventModel(
            id: UUID(),
            title: title,
            creatorId: userId,
            joinCode: joinCode,
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt,
            isRevealed: false,
            memberCount: 1,
            photoCount: 0,
            createdAt: Date()
        )
        
        try await client
            .from("events")
            .insert(event)
            .execute()
        
        print("[createEvent] Event saved, adding creator as member...")
        
        // Auto-join the creator
        let member = EventMember(
            id: UUID(),
            eventId: event.id,
            userId: userId,
            joinedAt: Date(),
            invitedBy: nil,
            role: "creator"
        )
        
        try await client
            .from("event_members")
            .insert(member)
            .execute()
        
        print("[createEvent] Success: \(title) with code \(joinCode)")
        return event
    }
    
    /// Join an event with a code
    func joinEvent(code: String) async throws -> EventModel {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Find event by join code
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .eq("join_code", value: code.uppercased())
            .execute()
            .value
        
        guard let event = events.first else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found with code: \(code)"])
        }
        
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
            id: UUID(),
            eventId: event.id,
            userId: userId,
            joinedAt: Date(),
            invitedBy: nil,
            role: "member"
        )
        
        try await client
            .from("event_members")
            .insert(member)
            .execute()
        
        print("✅ Joined event: \(event.title)")
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
        
        // Get events
        let events: [EventModel] = try await client
            .from("events")
            .select()
            .in("id", values: eventIds)
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
    
    /// Delete an event (creator only)
    func deleteEvent(id: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await client
            .from("events")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("creator_id", value: userId.uuidString)
            .execute()
        
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
            username = profile.displayName ?? profile.username
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
            capturedByUsername: username,
            isRevealed: false,
            uploadStatus: "uploaded"
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
            let capturedByUsername: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case eventId = "event_id"
                case userId = "user_id"
                case storagePath = "storage_path"
                case capturedAt = "captured_at"
                case capturedByUsername = "captured_by_username"
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
                photographerName: photo.capturedByUsername ?? "Unknown"
            ))
        }
        
        print("📸 Loaded \(photoDataArray.count) photos with signed URLs")
        return photoDataArray
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
}

// MARK: - Models

struct UserProfile: Codable {
    let id: UUID
    let username: String
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var avatarUrl: String?
    var isPremium: Bool
    var totalEventsJoined: Int
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case isPremium = "is_premium"
        case totalEventsJoined = "total_events_joined"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EventModel: Codable, Identifiable {
    let id: UUID
    let title: String
    let creatorId: UUID
    let joinCode: String
    let startsAt: Date      // When event goes live (photos can be taken)
    let endsAt: Date        // When photo-taking stops
    let releaseAt: Date     // When photos are revealed (typically 24h after endsAt)
    var isRevealed: Bool
    var memberCount: Int
    var photoCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case creatorId = "creator_id"
        case joinCode = "join_code"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case releaseAt = "release_at"
        case isRevealed = "is_revealed"
        case memberCount = "member_count"
        case photoCount = "photo_count"
        case createdAt = "created_at"
    }
}

struct EventMember: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let joinedAt: Date
    var invitedBy: UUID?
    var role: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case invitedBy = "invited_by"
        case role
    }
}

struct PhotoModel: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    let capturedAt: Date
    var capturedByUsername: String?
    var isRevealed: Bool
    var uploadStatus: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case capturedByUsername = "captured_by_username"
        case isRevealed = "is_revealed"
        case uploadStatus = "upload_status"
    }
}

/// Simplified photo data for reveal UI
struct PhotoData: Identifiable {
    let id: String
    let url: URL?
    let capturedAt: Date
    let photographerName: String?
}
