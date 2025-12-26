//
//  FilmRollGalleryView.swift
//  Momento
//
//  Vintage film roll gallery - horizontal scroll like real film negatives 🎞️
//

import SwiftUI

struct FilmRollGalleryView: View {
    let event: Event
    let photos: [PhotoData]
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhotoIndex: Int = 0
    @State private var showFullScreen = false
    
    // Film strip colors
    private let filmBlack = Color(red: 0.08, green: 0.08, blue: 0.08)
    private let filmBrown = Color(red: 0.15, green: 0.12, blue: 0.10)
    private let sprocketColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    var body: some View {
        ZStack {
            // Dark film-like background
            filmBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 8)
                
                Spacer()
                
                // Film strip with photos
                filmStripView
                
                Spacer()
                
                // Photo info for selected
                if let photo = photos[safe: selectedPhotoIndex] {
                    photoInfoView(photo: photo)
                        .padding(.bottom, 30)
                }
            }
            
            // Close button overlay
            VStack {
                HStack {
                    Button(action: {
                        HapticsManager.shared.buttonPress()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(20)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoView(
                photo: photos[selectedPhotoIndex],
                photos: photos,
                initialIndex: selectedPhotoIndex
            )
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Event emoji
            Text(event.coverEmoji ?? "📸")
                .font(.system(size: 50))
            
            Text(event.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                Label("\(photos.count) photos", systemImage: "photo.stack")
                Label("\(event.memberCount) people", systemImage: "person.2")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }
    
    // MARK: - Film Strip
    
    private var filmStripView: some View {
        GeometryReader { geo in
            let photoWidth: CGFloat = geo.size.width * 0.75
            let photoHeight: CGFloat = photoWidth * 1.3
            let stripHeight: CGFloat = photoHeight + 60 // Extra for sprockets
            
            ZStack {
                // Film strip background
                RoundedRectangle(cornerRadius: 8)
                    .fill(filmBrown)
                    .frame(height: stripHeight)
                    .overlay(
                        // Film grain texture
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.03), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                
                // Sprocket holes - top
                HStack(spacing: 20) {
                    ForEach(0..<20, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sprocketColor)
                            .frame(width: 12, height: 8)
                    }
                }
                .offset(y: -stripHeight/2 + 15)
                
                // Sprocket holes - bottom
                HStack(spacing: 20) {
                    ForEach(0..<20, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sprocketColor)
                            .frame(width: 12, height: 8)
                    }
                }
                .offset(y: stripHeight/2 - 15)
                
                // Photo carousel
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // Leading spacer for centering
                            Spacer()
                                .frame(width: (geo.size.width - photoWidth) / 2 - 16)
                            
                            ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                                FilmFrameView(
                                    photo: photo,
                                    frameNumber: index + 1,
                                    isSelected: selectedPhotoIndex == index,
                                    width: photoWidth,
                                    height: photoHeight
                                )
                                .id(index)
                                .onTapGesture {
                                    if selectedPhotoIndex == index {
                                        // Double tap - open full screen
                                        showFullScreen = true
                                    } else {
                                        // First tap - select
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedPhotoIndex = index
                                        }
                                    }
                                    HapticsManager.shared.light()
                                }
                            }
                            
                            // Trailing spacer
                            Spacer()
                                .frame(width: (geo.size.width - photoWidth) / 2 - 16)
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: selectedPhotoIndex) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            proxy.scrollTo(selectedPhotoIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: stripHeight)
        }
        .frame(height: UIScreen.main.bounds.width * 0.75 * 1.3 + 60)
    }
    
    // MARK: - Photo Info
    
    private func photoInfoView(photo: PhotoData) -> some View {
        VStack(spacing: 12) {
            // Tap hint
            Text("Tap again to view full size")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            
            HStack(spacing: 24) {
                // Photographer
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                    Text(photo.photographerName ?? "Unknown")
                        .font(.system(size: 15, weight: .medium))
                }
                
                // Date
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                    Text(formatDate(photo.capturedAt))
                        .font(.system(size: 14))
                }
            }
            .foregroundColor(.white.opacity(0.8))
            
            // Frame counter
            Text("FRAME \(selectedPhotoIndex + 1) OF \(photos.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.orange.opacity(0.8))
                .padding(.top, 4)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Film Frame View

struct FilmFrameView: View {
    let photo: PhotoData
    let frameNumber: Int
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Photo container with film frame look
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: width, height: height)
                
                // Actual photo
                if let url = photo.url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width - 8, height: height - 8)
                                .clipped()
                                .cornerRadius(2)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 30))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: width - 8, height: height - 8)
                }
                
                // Frame number (like real film)
                VStack {
                    Spacer()
                    HStack {
                        Text("\(frameNumber)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                            .padding(4)
                        Spacer()
                        Text("◀ \(frameNumber)A")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.5))
                            .padding(4)
                    }
                }
                .frame(width: width, height: height)
                
                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.orange, lineWidth: 3)
                        .frame(width: width, height: height)
                }
            }
        }
        .scaleEffect(isSelected ? 1.0 : 0.9)
        .opacity(isSelected ? 1.0 : 0.7)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    FilmRollGalleryView(
        event: Event(
            id: UUID().uuidString,
            title: "Beach Party 2025",
            coverEmoji: "🏖️",
            startsAt: Date(),
            endsAt: Date(),
            releaseAt: Date(),
            memberCount: 8,
            photosTaken: 24,
            joinCode: "BEACH25",
            isRevealed: true
        ),
        photos: [
            PhotoData(id: "1", url: URL(string: "https://picsum.photos/400/600"), capturedAt: Date(), photographerName: "Sarah"),
            PhotoData(id: "2", url: URL(string: "https://picsum.photos/400/601"), capturedAt: Date(), photographerName: "John"),
            PhotoData(id: "3", url: URL(string: "https://picsum.photos/400/602"), capturedAt: Date(), photographerName: "Mike"),
            PhotoData(id: "4", url: URL(string: "https://picsum.photos/400/603"), capturedAt: Date(), photographerName: "Emma"),
            PhotoData(id: "5", url: URL(string: "https://picsum.photos/400/604"), capturedAt: Date(), photographerName: "Alex")
        ]
    )
}

