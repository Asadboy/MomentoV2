//
//  PhotoGalleryView.swift
//  Momento
//
//  Grid gallery view for browsing revealed photos
//

import SwiftUI

struct PhotoGalleryView: View {
    let event: Event
    let photos: [PhotoData]
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhoto: PhotoData?
    @State private var showFullScreen = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if photos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photos) { photo in
                                PhotoThumbnail(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                        showFullScreen = true
                                        HapticsManager.shared.light()
                                    }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .navigationTitle(event.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(photos.count) photos")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                if let photo = selectedPhoto {
                    FullScreenPhotoView(
                        photo: photo,
                        photos: photos,
                        initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Photos")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Photos will appear here after reveal")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let photo: PhotoData
    
    var body: some View {
        GeometryReader { geo in
            if let url = photo.url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Full Screen Photo View

struct FullScreenPhotoView: View {
    let photo: PhotoData
    let photos: [PhotoData]
    let initialIndex: Int
    
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    PhotoDetailView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Close button
            VStack {
                HStack {
                    Button(action: {
                        HapticsManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 5)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Photo counter
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding()
                }
                
                Spacer()
            }
        }
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let photo: PhotoData
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            if let url = photo.url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        // Snap back if too small
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        }
                                        // Limit max zoom
                                        if scale > 4.0 {
                                            withAnimation(.spring()) {
                                                scale = 4.0
                                                lastScale = 4.0
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Failed to load")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Photo info overlay at bottom
            VStack {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 14))
                            Text(photo.photographerName ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(formatDate(photo.capturedAt))
                                .font(.caption)
                        }
                        .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    PhotoGalleryView(
        event: Event(
            id: UUID().uuidString,
            name: "Beach Party 2025",
            coverEmoji: "🏖️",
            startsAt: Date(),
            endsAt: Date(),
            releaseAt: Date(),
            joinCode: "ABC123"
        ),
        photos: [
            PhotoData(id: "1", url: URL(string: "https://picsum.photos/400/600"), capturedAt: Date(), photographerName: "Sarah"),
            PhotoData(id: "2", url: URL(string: "https://picsum.photos/400/601"), capturedAt: Date(), photographerName: "John"),
            PhotoData(id: "3", url: URL(string: "https://picsum.photos/400/602"), capturedAt: Date(), photographerName: "Mike")
        ]
    )
}

