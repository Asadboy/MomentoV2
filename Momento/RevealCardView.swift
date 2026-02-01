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

    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showButtons = false
    @State private var buttonTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Photo area
            ZStack {
                // Actual photo (always present, hidden by overlay when unrevealed)
                photoView

                // Grainy overlay (fades out on reveal)
                if !isRevealed {
                    unrevealedOverlay
                        .transition(.opacity)
                }

                // Metadata overlay (shows when revealed)
                if isRevealed {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = photo.photographerName {
                                    Text("@\(name)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                Text(formatTime(photo.capturedAt))
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3/4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                revealPhoto()
            }

            // Action bar (shows after delay when revealed)
            if showButtons {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .task {
            await loadImage()
            // If already revealed (e.g., liked photo), show buttons immediately
            if isRevealed {
                showButtons = true
            }
        }
        .onDisappear {
            buttonTimer?.invalidate()
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
        ZStack {
            // Film grain texture (using noise pattern)
            Canvas { context, size in
                for _ in 0..<2000 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let gray = CGFloat.random(in: 0.1...0.25)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(Color(white: gray))
                    )
                }
            }
            .background(Color(white: 0.12))

            // Tap hint
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

        withAnimation(.easeOut(duration: 0.3)) {
            isRevealed = true
        }

        // Start button delay timer
        startButtonTimer()
    }

    private func startButtonTimer() {
        showButtons = false
        buttonTimer?.invalidate()
        buttonTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                showButtons = true
            }
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
