//
//  DebugEventGalleryView.swift
//  Momento
//
//  Created by Cursor on 09/11/2025.
//
//  Temporary gallery UI that lets us inspect locally cached photos.
//

import SwiftUI

struct DebugEventGalleryView: View {
    let event: Event
    @Binding var photos: [EventPhoto]
    let onReveal: (EventPhoto) -> Void
    let onDismiss: () -> Void
    
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(royalPurple.opacity(0.6))
                        
                        Text("No photos captured yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Use this debug gallery to reveal disposable photos during testing.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.gradient)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(photos) { photo in
                                DebugPhotoCard(photo: photo, onReveal: onReveal)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .background(Color.black.gradient)
                }
            }
            .navigationTitle("\(event.title) Debug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct DebugPhotoCard: View {
    let photo: EventPhoto
    let onReveal: (EventPhoto) -> Void
    
    private var displayImage: UIImage? {
        if let cached = photo.image {
            return cached
        }
        // Always try to load image for the greyed-out preview
        return PhotoStorageManager.shared.loadImage(for: photo)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                if let image = displayImage {
                    // Show image with opacity based on reveal state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(18)
                        .opacity(photo.isRevealed ? 1.0 : 0.3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    photo.isRevealed ? Color.white.opacity(0.2) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            // Lock icon for unrevealed photos
                            Group {
                                if !photo.isRevealed {
                                    VStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 8)
                                        
                                        Text("Tap to reveal")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 4)
                                    }
                                }
                            }
                        )
                } else {
                    // Fallback if image can't be loaded
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.2),
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 240)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Image unavailable")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .onTapGesture {
                if !photo.isRevealed {
                    // Haptic feedback on reveal
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onReveal(photo)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.capturedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(photo.capturedAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if photo.isRevealed {
                    Label("Revealed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button {
                        onReveal(photo)
                    } label: {
                        Label("Reveal", systemImage: "wand.and.stars")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.5, green: 0.0, blue: 0.8))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    let event = Event(
        title: "Test Event",
        coverEmoji: "🎉",
        releaseAt: .now,
        memberCount: 10,
        photosTaken: 2,
        joinCode: "TEST"
    )
    
    let photo = EventPhoto(
        id: UUID().uuidString,
        eventID: event.id,
        fileURL: URL(fileURLWithPath: "/tmp/photo.jpg"),
        capturedAt: .now
    )
    
    return DebugEventGalleryView(
        event: event,
        photos: .constant([photo]),
        onReveal: { _ in },
        onDismiss: {}
    )
}

