//
//  AuthenticationRootView.swift
//  Momento
//
//  Root view that handles authentication state
//

import SwiftUI

struct AuthenticationRootView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var appState: AppState = .checkingAuth
    @State private var isCheckingUsername = false

    enum AppState {
        case checkingAuth
        case needsSignIn
        case needsUsername
        case authenticated
    }

    // 🚨 DEBUG: Set to true to bypass sign-in screen for testing
    // ⚠️ REMEMBER TO SET BACK TO FALSE BEFORE PRODUCTION!
    private let DEBUG_SKIP_AUTH = false

    var body: some View {
        Group {
            if DEBUG_SKIP_AUTH {
                // 🧪 DEBUG MODE: Skip authentication entirely
                ContentView()
            } else {
                switch appState {
                case .checkingAuth:
                    // Show splash screen while checking auth
                    ZStack {
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            Image(systemName: "camera.metering.center.weighted")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.white)

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }

                case .needsSignIn:
                    SignInView()

                case .needsUsername:
                    UsernameSelectionView()

                case .authenticated:
                    ContentView()
                }
            }
        }
        .task {
            await checkAuthState()
        }
        .onReceive(supabaseManager.$isAuthenticated) { isAuthenticated in
            // Only re-check if we're not already in a stable state
            guard appState == .checkingAuth || appState == .needsSignIn else { return }

            if isAuthenticated {
                Task { await checkAuthState() }
            } else {
                appState = .needsSignIn
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UsernameUpdated"))) { _ in
            // Re-check auth state to transition from needsUsername to authenticated
            if let userId = supabaseManager.currentUser?.id {
                isCheckingUsername = false // Reset flag to allow re-check
                checkUsernameStatus(userId: userId)
            }
        }
    }

    // MARK: - Auth State Checking

    private func checkAuthState() async {
        await supabaseManager.checkSession()

        // Small delay to prevent flash
        try? await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            if !supabaseManager.isAuthenticated {
                appState = .needsSignIn
            } else if let userId = supabaseManager.currentUser?.id {
                checkUsernameStatus(userId: userId)
            }
        }
    }

    private func checkUsernameStatus(userId: UUID) {
        // Prevent multiple simultaneous checks
        guard !isCheckingUsername else { return }

        Task {
            await MainActor.run {
                isCheckingUsername = true
            }

            do {
                let needsUsername = try await supabaseManager.needsUsernameSelection(userId: userId)
                await MainActor.run {
                    appState = needsUsername ? .needsUsername : .authenticated
                    isCheckingUsername = false
                }
            } catch {
                print("❌ Failed to check username status: \(error)")
                // Default to authenticated to avoid blocking user
                await MainActor.run {
                    appState = .authenticated
                    isCheckingUsername = false
                }
            }
        }
    }
}

#Preview {
    AuthenticationRootView()
}

