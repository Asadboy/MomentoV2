//
//  InviteSheet.swift
//  Momento
//
//  Created by Cursor on 09/11/2025.
//
//  Sheet for inviting friends to an event via share link or QR code
//

import SwiftUI

struct InviteSheet: View {
    let event: Event
    let onDismiss: () -> Void
    
    @State private var showCopiedConfirmation = false
    
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    private var inviteLink: String {
        // TODO: Generate real invite link with backend
        "https://momento.app/join/\(event.joinCode ?? "INVITE")"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Event info header
                    VStack(spacing: 12) {
                        Text(event.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
                                Text("\(event.memberCount) members")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            
                            if let joinCode = event.joinCode {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 12))
                                    Text(joinCode)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(royalPurple)
                            }
                        }
                    }
                    .padding(.top, 32)
                    
                    // QR Code placeholder
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .frame(width: 220, height: 220)
                            
                            // TODO: Generate actual QR code
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 120, weight: .light))
                                    .foregroundColor(.black.opacity(0.8))
                                
                                Text(event.joinCode ?? "INVITE")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Text("Scan to join")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Copy link button
                        Button {
                            copyInviteLink()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: showCopiedConfirmation ? "checkmark.circle.fill" : "link.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text(showCopiedConfirmation ? "Link Copied!" : "Copy Invite Link")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(showCopiedConfirmation ? Color.green : royalPurple)
                            )
                        }
                        .animation(.spring(response: 0.3), value: showCopiedConfirmation)
                        
                        // Share button
                        Button {
                            shareInvite()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Share Invite")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(royalPurple)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyInviteLink() {
        UIPasteboard.general.string = inviteLink
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show confirmation
        showCopiedConfirmation = true
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedConfirmation = false
        }
    }
    
    private func shareInvite() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // TODO: Present native share sheet
        // For now, just copy the link
        copyInviteLink()
    }
}

#Preview {
    let now = Date()
    return InviteSheet(
        event: Event(
            title: "NYE House Party",
            coverEmoji: "\u{1F389}",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            memberCount: 28,
            photosTaken: 15,
            joinCode: "NYE2025"
        ),
        onDismiss: {}
    )
}

