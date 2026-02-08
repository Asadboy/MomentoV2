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
    let eventId: String
    @Binding var isRevealed: Bool
    @Binding var isLiked: Bool
    var onRevealStarted: (() -> Void)? = nil
    var onButtonsVisible: (() -> Void)? = nil

    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showButtons = false
    @State private var buttonTimer: Timer?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

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
                // Film date + photographer
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatFilmDate(photo.capturedAt))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.21))

                        if let name = photo.photographerName {
                            Text("by \(name)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                }

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
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                PhotoShareSheet(image: image, eventId: eventId)
            }
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

            // Share button
            Button {
                loadImageForSharing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                    Text("Share")
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

    private func formatFilmDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy  HH:mm"
        return formatter.string(from: date).uppercased()
    }

    private func loadImageForSharing() {
        guard let image = loadedImage else { return }
        shareImage = image
        showShareSheet = true
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
            eventId: "preview",
            isRevealed: .constant(false),
            isLiked: .constant(false)
        )
    }
}
