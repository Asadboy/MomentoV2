//
//  ProfileView.swift
//  Momento
//
//  User profile screen with stats and keepsakes
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared

    @State private var username: String?
    @State private var userNumber: Int?
    @State private var stats: ProfileStats?
    @State private var keepsakes: [EarnedKeepsake] = []
    @State private var selectedKeepsake: EarnedKeepsake?
    @State private var isLoading = true
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header section
                            headerSection

                            // Stats section
                            if let stats = stats {
                                statsSection(stats: stats)
                            }

                            // Keepsakes section (hidden if empty)
                            if !keepsakes.isEmpty {
                                keepsakesSection
                            }

                            Spacer(minLength: 40)

                            // Sign out button
                            signOutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $selectedKeepsake) { keepsake in
                KeepsakeDetailModal(keepsake: keepsake)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 20) {
            // Profile icon with glow
            ZStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(royalPurple)
                    .blur(radius: 15)
                    .opacity(0.5)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
            }

            VStack(spacing: 8) {
                // Username
                if let username = username {
                    Text("@\(username)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // User number
                if let userNumber = userNumber {
                    Text("User #\(userNumber)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Stats Section

    private func statsSection(stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACTIVITY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            StatsGridView(stats: stats)

            Text("JOURNEY")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
                .padding(.top, 8)

            JourneyStatsView(stats: stats)
        }
    }

    // MARK: - Keepsakes Section

    private var keepsakesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KEEPSAKES")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.5)

            KeepsakeGridView(
                keepsakes: keepsakes,
                selectedKeepsake: $selectedKeepsake
            )
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 12) {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isLoggingOut ? "Signing Out..." : "Sign Out")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
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
            // Load profile
            let profile = try await supabaseManager.getUserProfile(userId: userId)

            // Load stats
            let profileStats = try await supabaseManager.getProfileStats()

            // Load keepsakes
            let earnedKeepsakes = try await supabaseManager.getUserKeepsakes()

            await MainActor.run {
                self.username = profile.username
                self.userNumber = profileStats.userNumber
                self.stats = profileStats
                self.keepsakes = earnedKeepsakes
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load profile: \(error)")
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
