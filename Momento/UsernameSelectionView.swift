//
//  UsernameSelectionView.swift
//  Momento
//
//  Username selection screen for new users
//

import SwiftUI

struct UsernameSelectionView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var username: String = ""
    @State private var validationState: ValidationState = .idle
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var validationTask: Task<Void, Never>?

    enum ValidationState {
        case idle
        case validating
        case available
        case unavailable(String)
        case invalid(String)
    }

    // Royal purple accent (matches main app)
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        ZStack {
            // Background gradient (matches SignInView)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.08, green: 0.06, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Welcome section
                VStack(spacing: 12) {
                    Text("Thanks for using the beta love asad")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Choose your username")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)

                Spacer()

                // Input card
                VStack(spacing: 20) {
                    // Username input with validation
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(royalPurple)

                            TextField("username", text: $username)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, newValue in
                                    onUsernameChange(newValue)
                                }

                            // Validation icon
                            validationIcon
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.15, green: 0.13, blue: 0.19))
                        )

                        // Error messages
                        if case .unavailable(let msg) = validationState {
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if case .invalid(let msg) = validationState {
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Continue button
                    Button {
                        Task {
                            await submitUsername()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }

                            Text(isSubmitting ? "Setting username..." : "Continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isContinueEnabled ? Color.white : Color.white.opacity(0.1))
                        .foregroundColor(isContinueEnabled ? .black : .white.opacity(0.3))
                        .cornerRadius(14)
                    }
                    .disabled(!isContinueEnabled)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // Helper text
                Text("3-20 characters, letters, numbers, and underscores")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 24)

                // Error message from submission
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
        }
        .onDisappear {
            validationTask?.cancel()
        }
    }

    // MARK: - Validation Icon

    @ViewBuilder
    private var validationIcon: some View {
        switch validationState {
        case .idle:
            EmptyView()

        case .validating:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: royalPurple))
                .scaleEffect(0.8)

        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.green)

        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.red)

        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.orange)
        }
    }

    // MARK: - Computed Properties

    private var isContinueEnabled: Bool {
        if case .available = validationState, !isSubmitting {
            return true
        }
        return false
    }

    // MARK: - Validation Logic

    private func validateUsernameFormat(_ username: String) -> Bool {
        // Special case: Allow "JB" and "KW" as 2-letter usernames
        let uppercased = username.uppercased()
        if uppercased == "JB" || uppercased == "KW" {
            return true
        }

        // 3-20 characters for all other usernames
        guard username.count >= 3 && username.count <= 20 else { return false }

        // Alphanumeric + underscore only
        let pattern = "^[a-zA-Z0-9_]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: username.utf16.count)
        return regex?.firstMatch(in: username, range: range) != nil
    }

    private func onUsernameChange(_ newValue: String) {
        // Cancel previous validation
        validationTask?.cancel()

        // Client-side format validation (instant)
        if newValue.isEmpty {
            validationState = .idle
            return
        }

        if !validateUsernameFormat(newValue) {
            validationState = .invalid("3-20 characters, letters, numbers, and underscores only")
            return
        }

        // Server-side uniqueness check (debounced)
        validationState = .validating
        validationTask = Task {
            // 500ms debounce
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            do {
                let isAvailable = try await supabaseManager.checkUsernameAvailability(newValue)
                await MainActor.run {
                    validationState = isAvailable
                        ? .available
                        : .unavailable("Username is already taken")
                }
            } catch {
                await MainActor.run {
                    validationState = .invalid("Couldn't check availability: \(error.localizedDescription)")
                }
            }
        }
    }

    private func submitUsername() async {
        guard case .available = validationState else { return }
        guard let userId = supabaseManager.currentUser?.id else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await supabaseManager.updateUsername(userId: userId, newUsername: username)
            // Notify AuthenticationRootView to re-check and transition
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("UsernameUpdated"), object: nil)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UsernameSelectionView()
}
