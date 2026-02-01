//
//  RevealCardView.swift
//  Momento
//
//  Individual photo card for feed reveal.
//  Handles unrevealed/revealed states with tap-to-reveal animation.
//

import SwiftUI

struct RevealCardView: View {
    let photo: PhotoData
    @Binding var isRevealed: Bool
    @Binding var isLiked: Bool
    let onDownload: () -> Void
    var onRevealStarted: (() -> Void)? = nil
    var onButtonsVisible: (() -> Void)? = nil

    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showButtons = false
    @State private var buttonTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Photo area
            ZStack {
                // Actual photo (always present, hidden by overlay when unrevealed)
                photoView

                // Grainy overlay (fades out on reveal)
                if !isRevealed {
                    unrevealedOverlay
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                revealPhoto()
            }

            // Metadata + action bar - always reserve space, fade in content
            VStack(spacing: 12) {
                // Username and time
                HStack {
                    if let name = photo.photographerName {
                        Text("@\(name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text("·")
                        .opacity(0.5)
                    Text(formatTime(photo.capturedAt))
                        .font(.subheadline)
                    Spacer()
                }
                .foregroundColor(.white.opacity(0.7))

                // Action buttons
                actionBar
            }
            .padding(.top, 12)
            .opacity(showButtons ? 1 : 0)

            Spacer(minLength: 16)
        }
        .padding(.horizontal, 16)
        .task {
            await loadImage()
        }
        .onAppear {
            // Reset or restore button state when card becomes visible
            if isRevealed {
                // Already revealed - show buttons immediately, unlock scroll
                showButtons = true
                onButtonsVisible?()
            } else {
                showButtons = false
            }
        }
        .onDisappear {
            buttonTimer?.invalidate()
            buttonTimer = nil
        }
    }

    // MARK: - Subviews

    private var photoView: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoadingImage {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .overlay(ProgressView().tint(.white))
            } else {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }

    private var unrevealedOverlay: some View {
        // Solid dark overlay with centered tap hint
        Rectangle()
            .fill(Color(white: 0.12))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 32))
                    Text("Tap to reveal")
                        .font(.subheadline)
                }
                .foregroundColor(.white.opacity(0.6))
            }
    }

    private var actionBar: some View {
        HStack(spacing: 40) {
            // Like button
            Button {
                toggleLike()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isLiked ? .red : .white)
                    Text(isLiked ? "Liked" : "Like")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }

            // Download button
            Button {
                onDownload()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                    Text("Save")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func revealPhoto() {
        guard !isRevealed else { return }

        HapticsManager.shared.light()
        onRevealStarted?()

        withAnimation(.easeOut(duration: 0.3)) {
            isRevealed = true
        }

        // Start button delay timer
        startButtonTimer()
    }

    private func startButtonTimer() {
        showButtons = false
        buttonTimer?.invalidate()
        buttonTimer = nil

        // Schedule timer on main run loop
        buttonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                showButtons = true
            }
            self.onButtonsVisible?()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    private func toggleLike() {
        HapticsManager.shared.light()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
        }
    }

    private func loadImage() async {
        guard let url = photo.url else { return }
        isLoadingImage = true

        // Use cache manager
        if let cached = await ImageCacheManager.shared.image(for: url) {
            await MainActor.run {
                loadedImage = cached
                isLoadingImage = false
            }
        } else {
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        RevealCardView(
            photo: PhotoData(
                id: "test",
                url: URL(string: "https://picsum.photos/800/600"),
                capturedAt: Date(),
                photographerName: "Test User"
            ),
            isRevealed: .constant(false),
            isLiked: .constant(false),
            onDownload: {}
        )
    }
}
