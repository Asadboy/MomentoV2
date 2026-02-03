//
//  InviteSheet.swift
//  Momento
//
//  Created by Cursor on 09/11/2025.
//
//  Sheet for inviting friends to an event via share link or QR code
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteSheet: View {
    let event: Event
    let onDismiss: () -> Void
    
    @State private var showCopiedConfirmation = false
    @State private var qrCodeImage: UIImage?
    
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    private var inviteLink: String {
        "https://momento.app/join/\(event.joinCode ?? "INVITE")"
    }
    
    private var shareText: String {
        """
        Join my Momento "\(event.name)"! 📸
        
        Use code: \(event.joinCode ?? "INVITE")
        
        Or open: \(inviteLink)
        """
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
                        Text(event.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12))
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
                    
                    // QR Code (real, scannable)
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .frame(width: 220, height: 220)
                            
                            if let qrImage = qrCodeImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                            } else {
                                ProgressView()
                                    .tint(.black)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 4) {
                            Text("Scan to join")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Code: \(event.joinCode ?? "INVITE")")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(royalPurple)
                        }
                    }
                    .onAppear {
                        generateQRCode()
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
        
        // Create share items
        var shareItems: [Any] = [shareText]
        
        // Add QR code image if available
        if let qrImage = qrCodeImage {
            shareItems.append(qrImage)
        }
        
        // Present native share sheet
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Get the current window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // For iPad: set popover source
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - QR Code Generation
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        // Encode the invite link into the QR code
        let data = Data(inviteLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let outputImage = filter.outputImage else { return }
        
        // Scale up the QR code (it's generated very small)
        let scale: CGFloat = 10
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Convert to UIImage
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            qrCodeImage = UIImage(cgImage: cgImage)
        }
    }
}

#Preview {
    let now = Date()
    return InviteSheet(
        event: Event(
            name: "NYE House Party",
            coverEmoji: "\u{1F389}",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            joinCode: "NYE2025"
        ),
        onDismiss: {}
    )
}

