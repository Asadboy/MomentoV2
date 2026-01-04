//
//  CreateStep3ShareView.swift
//  Momento
//
//  Step 3 of Create Momento flow: Share your momento
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct CreateStep3ShareView: View {
    let momentoName: String
    let joinCode: String
    let startsAt: Date
    let onDone: () -> Void

    // Auto-calculated end time (12 hours after start)
    private var endsAt: Date {
        startsAt.addingTimeInterval(12 * 3600)
    }
    
    @State private var copiedCode = false
    @State private var showShareSheet = false
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                
                Text("Step 3 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Main content
            VStack(spacing: 32) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                }
                
                // Title
                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Share with friends to invite them")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Momento summary card
                VStack(spacing: 20) {
                    // Name
                    Text(momentoName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    // QR Code
                    if let qrImage = generateQRCode(from: joinCode) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    // Join code
                    HStack(spacing: 12) {
                        Text(joinCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(4)
                        
                        Button(action: copyCode) {
                            Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(copiedCode ? .green : .white.opacity(0.6))
                        }
                    }
                    
                    if copiedCode {
                        Text("Copied!")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                    
                    // Time info
                    Text(eventTimeDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // Share button
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Text("Share Invite")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                }
                
                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareMessage])
        }
    }
    
    private var eventTimeDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        let startDate = dateFormatter.string(from: startsAt)
        let startTime = timeFormatter.string(from: startsAt)
        let endTime = timeFormatter.string(from: endsAt)
        
        return "\(startDate) \u{2022} \(startTime) - \(endTime)"
    }
    
    private var shareMessage: String {
        """
        Join my Momento: \(momentoName)!
        
        Code: \(joinCode)
        
        Download Momento and enter the code to join.
        """
    }
    
    private func copyCode() {
        UIPasteboard.general.string = joinCode
        
        withAnimation {
            copiedCode = true
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedCode = false
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CreateStep3ShareView(
        momentoName: "Sopranos Party",
        joinCode: "SOPRAN",
        startsAt: Date(),
        onDone: {}
    )
}

