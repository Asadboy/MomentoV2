//
//  PhotoRevealCard.swift
//  Momento
//
//  Individual photo card with flip animation for reveal experience
//

import SwiftUI

struct PhotoRevealCard: View {
    let photoURL: URL?
    let photographerName: String
    let capturedAt: Date
    let isRevealed: Bool
    let onReveal: () -> Void
    
    @State private var flipped = false
    @State private var imageLoaded = false
    
    var body: some View {
        ZStack {
            // Back of card (face down - before reveal)
            if !flipped {
                cardBack
                    .rotation3DEffect(
                        .degrees(0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Front of card (photo - after reveal)
            if flipped {
                cardFront
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .aspectRatio(3/4, contentMode: .fit) // Nice photo ratio
        .onAppear {
            // Pre-animate if already revealed
            if isRevealed {
                withAnimation(.none) {
                    flipped = true
                }
            }
        }
    }
    
    // MARK: - Card Back (Face Down)
    
    private var cardBack: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.8),
                            Color.cyan.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Shimmer effect
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 20)
            
            VStack(spacing: 20) {
                // Momento logo/icon
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Tap to Reveal")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Border glow
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
        .onTapGesture {
            revealCard()
        }
    }
    
    // MARK: - Card Front (Photo)
    
    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
            
            if let url = photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .cornerRadius(20)
                            .onAppear {
                                imageLoaded = true
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Photo unavailable")
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Info overlay at bottom (counter-rotated to fix mirror effect from card flip)
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 14))
                            Text(photographerName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatCaptureDate(capturedAt))
                                .font(.caption)
                        }
                        .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .cornerRadius(20)
            // Counter-rotate to fix mirrored text from 3D flip
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(flipped && imageLoaded ? 1.0 : 0.95)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: imageLoaded)
    }
    
    // MARK: - Helpers
    
    private func formatCaptureDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func revealCard() {
        // Trigger haptic feedback
        HapticsManager.shared.cardFlip()
        
        // Flip animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            flipped = true
        }
        
        // Callback after animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onReveal()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Unrevealed card
        PhotoRevealCard(
            photoURL: URL(string: "https://picsum.photos/400/600"),
            photographerName: "Sarah",
            capturedAt: Date().addingTimeInterval(-3600),
            isRevealed: false,
            onReveal: {
                debugLog("Card revealed!")
            }
        )
        .padding()
        
        // Revealed card
        PhotoRevealCard(
            photoURL: URL(string: "https://picsum.photos/400/601"),
            photographerName: "John",
            capturedAt: Date().addingTimeInterval(-7200),
            isRevealed: true,
            onReveal: {
                debugLog("Card already revealed!")
            }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}

