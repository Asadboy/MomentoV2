//
//  SignInView.swift
//  Momento
//
//  Authentication screen with Apple/Google Sign In
//

import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit

struct SignInView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @State private var webAuthSession: ASWebAuthenticationSession?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + tagline
                VStack(spacing: 12) {
                    Text("10shots")
                        .font(.custom("RalewayDots-Regular", size: 72))
                        .foregroundColor(.white)

                    Text("Your shared disposable camera")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                // Sign In Buttons
                VStack(spacing: 12) {
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(28)
                    .disabled(isSigningIn)

                    // Google Sign In
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20, weight: .medium))

                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(isSigningIn)
                }
                .padding(.horizontal, 24)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .multilineTextAlignment(.center)
                }

                // Terms & Privacy
                VStack(spacing: 6) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))

                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://yourmomento.app/terms")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text("and")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.25))

                        Link("Privacy Policy", destination: URL(string: "https://yourmomento.app/privacy")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
            }

            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Signing in...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Google Sign In

    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil

        debugLog("🔵 Starting Google Sign In...")

        Task {
            do {
                debugLog("🔵 Getting OAuth URL from Supabase...")
                let url = try supabaseManager.client.auth.getOAuthSignInURL(
                    provider: .google,
                    redirectTo: URL(string: "momento://auth/callback")
                )
                debugLog("🔵 OAuth URL: \(url)")

                await MainActor.run {
                    let session = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: "momento"
                    ) { callbackURL, error in
                        debugLog("🔵 ASWebAuthenticationSession callback fired!")

                        Task { @MainActor in
                            if let error = error {
                                debugLog("🔴 Auth error: \(error)")
                                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                    debugLog("ℹ️ User cancelled Google sign in")
                                } else {
                                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                                }
                                isSigningIn = false
                                return
                            }

                            guard let callbackURL = callbackURL else {
                                debugLog("🔴 No callback URL received!")
                                errorMessage = "No callback received"
                                isSigningIn = false
                                return
                            }

                            debugLog("🔵 Callback URL received: \(callbackURL)")

                            do {
                                debugLog("🔵 Parsing session from callback URL...")
                                try await supabaseManager.client.auth.session(from: callbackURL)
                                debugLog("🔵 Session parsed, checking session...")
                                await supabaseManager.checkSession()
                                debugLog("✅ Google sign in successful! isAuthenticated: \(supabaseManager.isAuthenticated)")
                            } catch {
                                debugLog("🔴 Session parsing error: \(error)")
                                errorMessage = "Failed to complete sign in: \(error.localizedDescription)"
                            }

                            isSigningIn = false
                        }
                    }

                    session.presentationContextProvider = WebAuthPresentationContext.shared
                    session.prefersEphemeralWebBrowserSession = false

                    debugLog("🔵 Starting ASWebAuthenticationSession...")
                    if !session.start() {
                        debugLog("🔴 Failed to start ASWebAuthenticationSession!")
                        errorMessage = "Failed to start authentication"
                        isSigningIn = false
                    } else {
                        debugLog("🔵 ASWebAuthenticationSession started successfully")
                    }

                    webAuthSession = session
                }
            } catch {
                debugLog("🔴 Failed to get OAuth URL: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to start Google sign in: \(error.localizedDescription)"
                    isSigningIn = false
                }
            }
        }
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Unable to fetch identity token"
                return
            }

            isSigningIn = true

            Task {
                do {
                    _ = try await supabaseManager.signInWithApple(
                        idToken: idTokenString,
                        nonce: nonce
                    )

                    await MainActor.run {
                        isSigningIn = false
                    }
                } catch {
                    await MainActor.run {
                        isSigningIn = false
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Functions

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        // Fallback to UUID-based nonce instead of crashing
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
    }

    return String(nonce)
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()

    return hashString
}

// MARK: - Web Auth Presentation Context

class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

#Preview {
    SignInView()
}
