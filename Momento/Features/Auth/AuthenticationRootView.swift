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

    var body: some View {
        Group {
                switch appState {
                case .checkingAuth:
                    ZStack {
                        Color.clear
                            .momentoGlowOrb()

                        VStack(spacing: 20) {
                            ZStack {
                                Image(systemName: "camera.metering.center.weighted")
                                    .font(.system(size: 80, weight: .light))
                                    .foregroundColor(AppTheme.Colors.royalPurple)
                                    .blur(radius: 20)
                                    .opacity(0.5)

                                Image(systemName: "camera.metering.center.weighted")
                                    .font(.system(size: 80, weight: .light))
                                    .foregroundColor(.white)
                            }

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
        .task {
            await checkAuthState()
        }
        .onReceive(supabaseManager.$isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                // Always transition to sign-in when logged out (clears ContentView)
                appState = .needsSignIn
                return
            }

            // Only re-check auth if we're not already authenticated
            guard appState == .checkingAuth || appState == .needsSignIn else { return }
            Task { await checkAuthState() }
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
                    if needsUsername {
                        appState = .needsUsername
                    } else {
                        appState = .authenticated
                        identifyUserForAnalytics(userId: userId)
                    }
                    isCheckingUsername = false
                }
            } catch {
                debugLog("❌ Failed to check username status: \(error)")
                // Default to authenticated to avoid blocking user
                await MainActor.run {
                    appState = .authenticated
                    identifyUserForAnalytics(userId: userId)
                    isCheckingUsername = false
                }
            }
        }
    }

    private func identifyUserForAnalytics(userId: UUID) {
        Task {
            do {
                let profile = try await supabaseManager.getUserProfile(userId: userId)
                AnalyticsManager.shared.identify(
                    userId: userId.uuidString,
                    username: profile.username
                )
            } catch {
                debugLog("❌ Failed to identify user for analytics: \(error)")
            }
        }
    }
}

#Preview {
    AuthenticationRootView()
}

