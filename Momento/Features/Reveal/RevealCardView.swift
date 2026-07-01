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
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showReportConfirm = false
    @State private var isReported = false

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isRevealed
                ? "Photo by \(photo.photographerName ?? "Unknown")"
                : "Tap to reveal next photo")
            .accessibilityAddTraits(isRevealed ? [] : .isButton)

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
            // LazyVStack retains @State for every card that has appeared, so
            // holding the decoded UIImage (~7MB at 1200px) here accumulates
            // across the whole reveal — a 50-shot event approaches 400MB and
            // an OOM kill. Release it; `.task` re-fetches from
            // ImageCacheManager when the card scrolls back on screen.
            loadedImage = nil
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
            if isReported {
                Rectangle()
                    .fill(Color(white: 0.12))
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Reported")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("This photo is hidden and under review.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
            } else if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .contextMenu {
                        Button(role: .destructive) {
                            showReportConfirm = true
                        } label: {
                            Label("Report photo", systemImage: "flag")
                        }
                    }
                    .confirmationDialog(
                        "Report this photo?",
                        isPresented: $showReportConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Report", role: .destructive) {
                            Task {
                                try? await SupabaseManager.shared.reportPhoto(
                                    id: UUID(uuidString: photo.id) ?? UUID(),
                                    reason: nil
                                )
                                await MainActor.run { isReported = true }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("It will be hidden from everyone and reviewed. This can't be undone.")
                    }
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

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                showButtons = true
            }
            onButtonsVisible?()
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
