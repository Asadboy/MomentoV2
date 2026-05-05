//
//  AuthenticationRootView.swift
//  Momento
//
//  Root view that handles authentication state
//

import SwiftUI

struct AuthenticationRootView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var appState: AppState = .checkingAuth
    @State private var isCheckingUsername = false
    @State private var initialAction: OnboardingAction?

    enum AppState {
        case checkingAuth
        case needsSignIn
        case needsUsername
        case needsOnboarding
        case needsAction
        case authenticated
    }

    var body: some View {
        Group {
                switch appState {
                case .checkingAuth:
                    ZStack {
                        Color.black.ignoresSafeArea()

                        VStack(spacing: 24) {
                            Text("10shots")
                                .font(.custom("RalewayDots-Regular", size: 48))
                                .foregroundColor(.white)

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }

                case .needsSignIn:
                    SignInView()

                case .needsUsername:
                    UsernameSelectionView()

                case .needsOnboarding:
                    OnboardingView {
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState = .needsAction
                        }
                    }

                case .needsAction:
                    OnboardingActionView { action in
                        initialAction = action
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState = .authenticated
                        }
                    }

                case .authenticated:
                    ContentView(initialAction: initialAction)
                }
        }
        .task {
            await checkAuthState()
        }
        .onReceive(supabaseManager.$isAuthenticated) { isAuthenticated in
            // Don't react until the initial session check is done — prevents login flash
            guard supabaseManager.hasCompletedInitialCheck else { return }

            if !isAuthenticated {
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
                    } else if hasSeenOnboarding {
                        appState = .authenticated
                    } else {
                        appState = .needsOnboarding
                    }
                    isCheckingUsername = false
                }
            } catch {
                debugLog("❌ Failed to check username status: \(error)")
                await MainActor.run {
                    appState = .needsOnboarding
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

