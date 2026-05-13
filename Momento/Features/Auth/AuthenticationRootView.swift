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
    @State private var isCheckingProfile = false
    @State private var initialAction: OnboardingAction?

    enum AppState {
        case checkingAuth
        case needsSignIn
        case needsProfileSetup
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
                            BrandWordmark(size: 40)

                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }

                case .needsSignIn:
                    SignInView()

                case .needsProfileSetup:
                    ProfileSetupView {
                        // ProfileSetupView posts ProfileSetupCompleted on success;
                        // this closure handles the local screen transition.
                        if hasSeenOnboarding {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState = .authenticated
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState = .needsOnboarding
                            }
                        }
                    }

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
    }

    // MARK: - Auth State Checking

    private func checkAuthState() async {
        await supabaseManager.checkSession()

        await MainActor.run {
            if !supabaseManager.isAuthenticated {
                appState = .needsSignIn
            } else if let userId = supabaseManager.currentUser?.id {
                checkProfileStatus(userId: userId)
            }
        }
    }

    private func checkProfileStatus(userId: UUID) {
        // Prevent multiple simultaneous checks
        guard !isCheckingProfile else { return }

        Task {
            await MainActor.run {
                isCheckingProfile = true
            }

            do {
                let needsSetup = try await supabaseManager.needsProfileSetup(userId: userId)
                identifyUserForAnalytics(userId: userId)
                await MainActor.run {
                    if needsSetup {
                        appState = .needsProfileSetup
                    } else if hasSeenOnboarding {
                        appState = .authenticated
                    } else {
                        appState = .needsOnboarding
                    }
                    isCheckingProfile = false
                }
            } catch {
                debugLog("❌ Profile check failed (\(error)); attempting self-heal")
                // H5 self-heal: the profile row is genuinely missing.
                // The handle_new_user trigger should have created it on
                // auth.users insert, but a returning user whose row was
                // wiped (account-delete bug, schema migration, etc.)
                // would otherwise be stuck in an unrecoverable loop:
                // route to setup → setup tries to UPDATE → no row to
                // update → fail. Insert a placeholder row first so the
                // ProfileSetupView update has something to write to.
                do {
                    try await supabaseManager.createProfileIfNeeded(
                        user: supabaseManager.currentUser!
                    )
                    debugLog("✅ Self-healed missing profile row")
                } catch {
                    debugLog("❌ Self-heal failed too: \(error)")
                    AnalyticsManager.shared.trackError(
                        kind: "profile_self_heal_failed",
                        error: error
                    )
                }
                await MainActor.run {
                    appState = .needsProfileSetup
                    isCheckingProfile = false
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
                    username: profile.displayName
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
