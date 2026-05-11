//
//  SupabaseManager.swift
//  Momento
//
//  Core Supabase client manager — owns the SDK client, authenticated session
//  state, and the auth flows themselves (Apple / Google / email). All
//  domain-specific queries (events, members, photos, likes, profile) live in
//  per-domain `SupabaseManager+*.swift` extensions in this folder. DTOs live
//  in `SupabaseDTOs.swift`; domain models in `Models/`.
//

import Foundation
import Supabase

enum SupabaseError: LocalizedError {
    case userNotAuthenticated
    case eventNotFound
    case eventFull
    case invalidEventID
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "User not authenticated"
        case .eventNotFound: return "Event not found"
        case .eventFull: return "This event is full"
        case .invalidEventID: return "Invalid event ID"
        case .configurationError(let msg): return msg
        }
    }
}

/// Centralized Supabase client manager.
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    let storageBucket = "momento-photos"

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    /// True once the initial session check has completed (prevents login screen flash).
    @Published var hasCompletedInitialCheck = false

    private init() {
        guard SupabaseConfig.isConfigured else {
            fatalError("Supabase not configured! Check SupabaseConfig.swift")
        }

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

    /// Check if user has an existing session.
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

    /// Sign in with Apple.
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

        try await createProfileIfNeeded(user: session.user)
        return session.user
    }

    /// Sign in with Google.
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

        try await createProfileIfNeeded(user: session.user)
        return session.user
    }

    /// Handle OAuth callback URL (called from MomentoApp).
    func handleOAuthCallback(url: URL) async {
        do {
            try await client.auth.session(from: url)
            await checkSession()
            debugLog("✅ OAuth callback handled successfully")
        } catch {
            debugLog("❌ OAuth callback error: \(error)")
        }
    }

    /// Sign in with email and password.
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

    /// Sign up with email and password. Creates a profile row alongside the
    /// auth user.
    func signUpWithEmail(email: String, password: String, username: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        let user = response.user
        try await createProfile(userId: user.id, username: username)

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }

        return user
    }

    /// Sign out and clear all app-side state to prevent data leaking between
    /// accounts.
    func signOut() async throws {
        try await client.auth.signOut()

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false

            OfflineSyncManager.shared.clearQueue()
            RevealStateManager.shared.clearAllCompletedReveals()
        }

        debugLog("✅ User signed out")
    }
}
