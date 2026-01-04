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
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo & Title
                VStack(spacing: 16) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("Momento")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Capture & Reveal Memories Together")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Sign In Buttons
                VStack(spacing: 16) {
                    // Google Sign In (Primary - working!)
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            // Google "G" logo
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningIn)
                    
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
                    .frame(height: 50)
                    .cornerRadius(12)
                    .disabled(isSigningIn)
                }
                .padding(.horizontal, 32)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Terms & Privacy
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // TODO: Show terms
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        
                        Text("and")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button("Privacy Policy") {
                            // TODO: Show privacy policy
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 32)
            }
            
            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Signing in...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Google Sign In
    
    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil
        
        print("🔵 Starting Google Sign In...")
        
        Task {
            do {
                // Get the OAuth URL from Supabase
                print("🔵 Getting OAuth URL from Supabase...")
                let url = try await supabaseManager.client.auth.getOAuthSignInURL(
                    provider: .google,
                    redirectTo: URL(string: "momento://auth/callback")
                )
                print("🔵 OAuth URL: \(url)")
                
                await MainActor.run {
                    // Create and present ASWebAuthenticationSession
                    let session = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: "momento"
                    ) { callbackURL, error in
                        print("🔵 ASWebAuthenticationSession callback fired!")
                        
                        Task { @MainActor in
                            if let error = error {
                                // User cancelled or error
                                print("🔴 Auth error: \(error)")
                                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                    print("ℹ️ User cancelled Google sign in")
                                } else {
                                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                                }
                                isSigningIn = false
                                return
                            }
                            
                            guard let callbackURL = callbackURL else {
                                print("🔴 No callback URL received!")
                                errorMessage = "No callback received"
                                isSigningIn = false
                                return
                            }
                            
                            print("🔵 Callback URL received: \(callbackURL)")
                            
                            // Handle the OAuth callback
                            do {
                                print("🔵 Parsing session from callback URL...")
                                try await supabaseManager.client.auth.session(from: callbackURL)
                                print("🔵 Session parsed, checking session...")
                                await supabaseManager.checkSession()
                                print("✅ Google sign in successful! isAuthenticated: \(supabaseManager.isAuthenticated)")
                            } catch {
                                print("🔴 Session parsing error: \(error)")
                                errorMessage = "Failed to complete sign in: \(error.localizedDescription)"
                            }
                            
                            isSigningIn = false
                        }
                    }
                    
                    session.presentationContextProvider = WebAuthPresentationContext.shared
                    session.prefersEphemeralWebBrowserSession = false
                    
                    print("🔵 Starting ASWebAuthenticationSession...")
                    if !session.start() {
                        print("🔴 Failed to start ASWebAuthenticationSession!")
                        errorMessage = "Failed to start authentication"
                        isSigningIn = false
                    } else {
                        print("🔵 ASWebAuthenticationSession started successfully")
                    }
                    
                    webAuthSession = session
                }
            } catch {
                print("🔴 Failed to get OAuth URL: \(error)")
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
                        // Navigation will happen automatically via @Published isAuthenticated
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
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
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

/// Provides the presentation anchor for ASWebAuthenticationSession
class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window from the connected scenes
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Preview

#Preview {
    SignInView()
}

