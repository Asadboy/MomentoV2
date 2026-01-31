//
//  RevealView.swift
//  Momento
//
//  Full-screen photo reveal experience - The Momento Magic ✨
//

import SwiftUI
import Supabase

struct RevealView: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var photos: [PhotoData] = []
    @State private var currentIndex = 0
    @State private var revealedIndices: Set<Int> = []
    @State private var isLoading = true
    @State private var showConfetti = false
    @State private var allRevealed = false
    @State private var canGoNext = false
    @State private var showReactionPicker = false
    @State private var photoReactions: [String: [String: String]] = [:] // [photoId: [userId: emoji]]
    @State private var showGallery = false
    @State private var earnedKeepsake: EarnedKeepsake?
    @State private var showKeepsakeReveal = false
    @State private var showProfile = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color.purple.opacity(0.3),
                    Color.blue.opacity(0.2),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if photos.isEmpty {
                emptyView
            } else {
                VStack(spacing: 12) {
                    // Header
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Progress indicator (Stories-style segments)
                    progressView
                        .padding(.horizontal)
                    
                    Spacer(minLength: 8)
                    
                    // Main card area - takes remaining space
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            VStack(spacing: 0) {
                                PhotoRevealCard(
                                    photoURL: photo.url,
                                    photographerName: photo.photographerName ?? "Unknown",
                                    capturedAt: photo.capturedAt,
                                    isRevealed: revealedIndices.contains(index),
                                    onReveal: {
                                        handlePhotoRevealed(at: index)
                                    }
                                )
                            }
                            .padding(.horizontal, 12)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) {
                        // Hide reaction picker when changing photos
                        showReactionPicker = false
                    }
                    // Tap zones for navigation (invisible overlays on sides)
                    .overlay(
                        HStack(spacing: 0) {
                            // Left tap zone - go previous
                            Color.clear
                                .frame(width: 80)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if currentIndex > 0 {
                                        goToPrevious()
                                    }
                                }
                            
                            Spacer()
                            
                            // Right tap zone - go next
                            Color.clear
                                .frame(width: 80)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // If revealed and can go next, navigate
                                    if revealedIndices.contains(currentIndex) && currentIndex < photos.count - 1 {
                                        goToNext()
                                    }
                                }
                        }
                    )
                    
                    // Reaction area (compact, below card)
                    if let currentPhoto = photos[safe: currentIndex], revealedIndices.contains(currentIndex) {
                        reactionArea(for: currentPhoto)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            // Completion overlay
            if allRevealed {
                completionOverlay
            }

            // Keepsake reveal overlay
            if showKeepsakeReveal, let keepsake = earnedKeepsake {
                KeepsakeRevealView(
                    keepsake: keepsake,
                    onDismiss: {
                        showKeepsakeReveal = false
                        allRevealed = true
                    },
                    onViewProfile: {
                        showKeepsakeReveal = false
                        showProfile = true
                    }
                )
            }
        }
        .task {
            await loadPhotos()
        }
        .fullScreenCover(isPresented: $showGallery) {
            FilmRollGalleryView(event: event, photos: photos)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .onDisappear {
            // Mark reveal as completed if user went through all photos
            if allRevealed {
                RevealStateManager.shared.markRevealCompleted(for: event.id)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Preparing your Momentos...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Photos Yet")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Photos will appear here once uploaded")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                HapticsManager.shared.buttonPress()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(photos.count) Momentos")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Skip all button
            if !allRevealed {
                Button("Skip All") {
                    skipToEnd()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var progressView: some View {
        // Segmented progress bar (Instagram Stories style)
        HStack(spacing: 4) {
            ForEach(0..<photos.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }
    
    // MARK: - Reaction Area (Compact)
    
    private func reactionArea(for photo: PhotoData) -> some View {
        HStack(spacing: 16) {
            // Display existing reactions
            if let reactions = photoReactions[photo.id], !reactions.isEmpty {
                EmojiReactionDisplay(reactions: reactions)
            }
            
            Spacer()
            
            // Reaction picker or button
            if showReactionPicker {
                EmojiReactionPicker { emoji in
                    addReaction(emoji, to: photo.id)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showReactionPicker.toggle()
                    }
                    HapticsManager.shared.light()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 18))
                        Text("React")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                }
            }
        }
        .frame(height: 44)
    }
    
    private var completionOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                }
                .shadow(color: .purple.opacity(0.5), radius: 20)
                
                VStack(spacing: 12) {
                    Text("All Momentos Revealed!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("You've seen all \(photos.count) photos from this event")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    HapticsManager.shared.buttonPress()
                    showGallery = true
                }) {
                    Text("View Gallery")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // Close button (smaller, secondary)
                Button(action: {
                    dismiss()
                }) {
                    Text("Close")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 12)
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func loadPhotos() async {
        isLoading = true
        
        do {
            // Fetch photos for this event
            let fetchedPhotos = try await supabaseManager.getPhotos(for: event.id)
            
            await MainActor.run {
                self.photos = fetchedPhotos
                self.isLoading = false

                // Play entrance haptic
                if !fetchedPhotos.isEmpty {
                    HapticsManager.shared.unlock()

                    // Track reveal started
                    AnalyticsManager.shared.track(.revealStarted, properties: [
                        "event_id": event.id,
                        "photos_to_reveal": fetchedPhotos.count
                    ])
                }
            }
        } catch {
            print("❌ Error loading photos: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func handlePhotoRevealed(at index: Int) {
        // Mark as revealed
        revealedIndices.insert(index)
        
        // Play reveal haptic
        HapticsManager.shared.photoReveal()
        
        // Enable next button
        canGoNext = true
        
        // Check if all photos revealed
        if revealedIndices.count == photos.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completeReveal()
            }
        }
    }
    
    private func goToNext() {
        guard currentIndex < photos.count - 1 else { return }
        
        HapticsManager.shared.light()
        withAnimation {
            currentIndex += 1
            canGoNext = revealedIndices.contains(currentIndex)
        }
    }
    
    private func goToPrevious() {
        guard currentIndex > 0 else { return }
        
        HapticsManager.shared.light()
        withAnimation {
            currentIndex -= 1
            canGoNext = true // Can always go forward to already revealed photos
        }
    }
    
    private func skipToEnd() {
        HapticsManager.shared.medium()
        
        // Reveal all photos
        for index in 0..<photos.count {
            revealedIndices.insert(index)
        }
        
        // Go to last photo
        withAnimation {
            currentIndex = photos.count - 1
            canGoNext = true
        }
        
        // Show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completeReveal()
        }
    }
    
    private func completeReveal() {
        // Track reveal completed
        AnalyticsManager.shared.track(.revealCompleted, properties: [
            "event_id": event.id,
            "photos_revealed": photos.count
        ])

        // Play celebration haptic
        HapticsManager.shared.celebration()

        // Show confetti
        withAnimation {
            showConfetti = true
        }

        // Check for keepsake
        Task {
            if let eventUUID = UUID(uuidString: event.id) {
                earnedKeepsake = try? await supabaseManager.hasKeepsakeForEvent(eventId: eventUUID)
            }

            await MainActor.run {
                // Show completion overlay after confetti starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        // If there's a keepsake, show that instead of completion
                        if earnedKeepsake != nil {
                            showKeepsakeReveal = true
                        } else {
                            allRevealed = true
                        }
                    }
                }
            }
        }

        // Hide confetti after a bit
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showConfetti = false
            }
        }
    }
    
    private func addReaction(_ emoji: String, to photoId: String) {
        // Get current user ID (for now, use a placeholder)
        let userId = supabaseManager.currentUser?.id.uuidString ?? "anonymous"
        
        // Update local state
        if photoReactions[photoId] == nil {
            photoReactions[photoId] = [:]
        }
        photoReactions[photoId]?[userId] = emoji
        
        // Hide picker after selection
        withAnimation {
            showReactionPicker = false
        }
        
        // TODO: Sync to Supabase
        // For now, reactions are local only
        // Will persist to database once we add the update method
        
        print("✨ Added reaction \(emoji) to photo \(photoId)")
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    ConfettiPiece(
                        geometry: geometry,
                        index: index,
                        animate: $animate
                    )
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let geometry: GeometryProxy
    let index: Int
    @Binding var animate: Bool
    
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .pink, .orange, .cyan]
    private let size: CGFloat = 10
    
    var body: some View {
        Rectangle()
            .fill(colors[index % colors.count])
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(
                x: CGFloat.random(in: 0...geometry.size.width),
                y: yOffset
            )
            .onAppear {
                // Random starting position
                yOffset = -50
                
                // Animate falling
                withAnimation(
                    .linear(duration: Double.random(in: 2...4))
                ) {
                    yOffset = geometry.size.height + 50
                }
                
                // Animate rotation
                withAnimation(
                    .linear(duration: Double.random(in: 1...3))
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
                
                // Fade out near bottom
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.linear(duration: 1.0)) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    return RevealView(event: Event(
        id: UUID().uuidString,
        title: "Beach Party 2025",
        coverEmoji: "\u{1F3D6}",
        startsAt: now.addingTimeInterval(-48 * 3600),
        endsAt: now.addingTimeInterval(-24 * 3600),
        releaseAt: now.addingTimeInterval(-1 * 3600),
        memberCount: 5,
        photosTaken: 12,
        joinCode: "ABC123",
        isRevealed: true
    ))
    .environmentObject(SupabaseManager.shared)
}

// MARK: - Safe Array Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

