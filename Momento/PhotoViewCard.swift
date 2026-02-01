//
//  PhotoViewCard.swift
//  Momento
//
//  Simplified photo card for viewing mode (post-reveal)
//  No flip animation - photos are already revealed
//

import SwiftUI

struct PhotoViewCard: View {
    let photoURL: URL?
    let photographerName: String
    let capturedAt: Date
    let showButtons: Bool
    let onLike: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void

    @State private var imageLoaded = false

    var body: some View {
        ZStack {
            // Photo
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
                            .onAppear { imageLoaded = true }
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

            // Info overlay at bottom
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    // Photographer info
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

                    // Action buttons (fade in after delay)
                    if showButtons {
                        HStack(spacing: 24) {
                            Button(action: onLike) {
                                Image(systemName: "heart")
                                    .font(.system(size: 24))
                            }

                            Button(action: onSave) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 24))
                            }

                            Button(action: onShare) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 24))
                            }
                        }
                        .foregroundColor(.white)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
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
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .aspectRatio(3/4, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(imageLoaded ? 1.0 : 0.95)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: imageLoaded)
    }

    private func formatCaptureDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PhotoViewCard(
            photoURL: URL(string: "https://picsum.photos/400/600"),
            photographerName: "Sarah",
            capturedAt: Date(),
            showButtons: true,
            onLike: {},
            onSave: {},
            onShare: {}
        )
        .padding()
    }
}
