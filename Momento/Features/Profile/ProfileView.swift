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
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Profile icon with enhanced glow
            ZStack {
                // Outer glow
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(royalPurple)
                    .blur(radius: 25)
                    .opacity(0.4)

                // Inner glow
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(royalPurple)
                    .blur(radius: 10)
                    .opacity(0.3)

                // Main icon
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(.white.opacity(0.95))
            }

            VStack(spacing: 6) {
                // Username - prominent
                if let username = username {
                    Text("@\(username)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Member status - quiet nod, not a badge
                if let userNumber = userNumber {
                    HStack(spacing: 4) {
                        if userNumber <= 100 {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(userNumber <= 100 ? "Founding Member" : "Member #\(userNumber)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.28))
                }
            }
        }
        .padding(.vertical, 28)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("STATS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }

                Text(isLoggingOut ? "Signing Out..." : "Sign Out")
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(red: 0.15, green: 0.12, blue: 0.18))
            .foregroundColor(.white.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
