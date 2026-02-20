//
//  ProfileView.swift
//  Momento
//
//  User profile screen with stats
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared

    @State private var username: String?
    @State private var userNumber: Int?
    @State private var stats: ProfileStats?
    @State private var isLoading = true
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .momentoBackground()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.screenH) {
                            headerSection

                            if let stats = stats {
                                statsSection(stats: stats)
                            }

                            Spacer(minLength: AppTheme.Spacing.ctaBottom)

                            signOutButton
                        }
                        .padding(.horizontal, AppTheme.Spacing.screenH)
                        .padding(.top, 20)
                        .padding(.bottom, AppTheme.Spacing.ctaBottom)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    performLogout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Profile icon with single blurred glow
            ZStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(AppTheme.Colors.royalPurple)
                    .blur(radius: 20)
                    .opacity(0.4)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
            }

            VStack(spacing: 6) {
                if let username = username {
                    Text("@\(username)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

                if let userNumber = userNumber {
                    HStack(spacing: 4) {
                        if userNumber <= 100 {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(userNumber <= 100 ? "Founding Member" : "Member #\(userNumber)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textQuaternary)
                }
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .momentoCard()
    }

    // MARK: - Stats Section

    private func statsSection(stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATS")
                .font(AppTheme.Fonts.micro)
                .foregroundColor(AppTheme.Colors.textMuted)
                .tracking(1.2)

            StatsGridView(stats: stats)
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.textSecondary))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }

                Text(isLoggingOut ? "Signing Out..." : "Sign Out")
            }
        }
        .buttonStyle(MomentoDestructiveButtonStyle())
        .disabled(isLoggingOut)
    }

    // MARK: - Data Loading

    private func loadProfileData() async {
        isLoading = true

        guard let userId = supabaseManager.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            let profile = try await supabaseManager.getUserProfile(userId: userId)
            let profileStats = try await supabaseManager.getProfileStats()

            await MainActor.run {
                self.username = profile.username
                self.userNumber = profileStats.userNumber
                self.stats = profileStats
                self.isLoading = false
            }
        } catch {
            debugLog("❌ Failed to load profile: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func performLogout() {
        isLoggingOut = true

        Task {
            do {
                try await supabaseManager.signOut()
                await MainActor.run {
                    isLoggingOut = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoggingOut = false
                    errorMessage = "Failed to sign out: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
