//
//  RevealView.swift
//  Momento
//
//  Full-screen photo reveal experience - The Momento Magic ✨
//

import SwiftUI
import Supabase

/// Reveal flow phases
enum RevealFlowPhase {
    case preReveal      // Stats + "Reveal" button
    case viewing        // Photo carousel
    case complete       // "That was the night."
}

struct RevealView: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var photos: [PhotoData] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var showConfetti = false
    @State private var showGallery = false
    @State private var earnedKeepsake: EarnedKeepsake?
    @State private var showKeepsakeReveal = false
    @State private var showProfile = false
    @State private var flowPhase: RevealFlowPhase = .preReveal
    @State private var showButtons = false  // For 2-second delay
    @State private var buttonTimer: Timer?

    private var uniqueContributorCount: Int {
        Set(photos.compactMap { $0.photographerName }).count
    }

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
                // Phase-based content
                switch flowPhase {
                case .preReveal:
                    PreRevealView(
                        photoCount: photos.count,
                        contributorCount: uniqueContributorCount,
                        revealTime: event.releaseAt,
                        onReveal: startReveal
                    )
                    .transition(.opacity)

                case .viewing:
                    viewingPhaseContent
                        .transition(.opacity)

                case .complete:
                    RevealCompleteView(
                        onViewGallery: {
                            HapticsManager.shared.buttonPress()
                            showGallery = true
                        },
                        onClose: { dismiss() }
                    )
                    .transition(.opacity)
                }
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Keepsake reveal overlay
            if showKeepsakeReveal, let keepsake = earnedKeepsake {
                KeepsakeRevealView(
                    keepsake: keepsake,
                    onDismiss: {
                        showKeepsakeReveal = false
                        flowPhase = .complete
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
            buttonTimer?.invalidate()
            if flowPhase == .complete {
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

                Text("\(currentIndex + 1) of \(photos.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 30, height: 30)
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
    
    // MARK: - Viewing Phase

    private var viewingPhaseContent: some View {
        VStack(spacing: 12) {
            // Header
            headerView
                .padding(.horizontal)
                .padding(.top, 8)

            // Progress indicator
            progressView
                .padding(.horizontal)

            Spacer(minLength: 8)

            // Photo carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    PhotoViewCard(
                        photoURL: photo.url,
                        photographerName: photo.photographerName ?? "Unknown",
                        capturedAt: photo.capturedAt,
                        showButtons: showButtons,
                        onLike: { handleLike(photo) },
                        onSave: { handleSave(photo) },
                        onShare: { handleShare(photo) }
                    )
                    .padding(.horizontal, 12)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, newIndex in
                onPhotoChanged(to: newIndex)
            }
            // Detect swipe past last photo
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        // If on last photo and swiping left (to go further)
                        if currentIndex == photos.count - 1 && gesture.translation.width < -50 {
                            completeViewing()
                        }
                    }
            )

            Spacer(minLength: 20)
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
                }
            }
        } catch {
            print("❌ Error loading photos: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func startReveal() {
        // Haptic threshold
        HapticsManager.shared.revealThreshold()

        // Fade transition to viewing
        withAnimation(.easeInOut(duration: 0.5)) {
            flowPhase = .viewing
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

    private func onPhotoChanged(to index: Int) {
        // Reset button timer on each photo
        startButtonTimer()
    }

    private func completeViewing() {
        buttonTimer?.invalidate()

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        if earnedKeepsake != nil {
                            showKeepsakeReveal = true
                        } else {
                            flowPhase = .complete
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

    private func handleLike(_ photo: PhotoData) {
        HapticsManager.shared.light()
        print("Liked photo: \(photo.id)")
    }

    private func handleSave(_ photo: PhotoData) {
        HapticsManager.shared.light()
        print("Saved photo: \(photo.id)")
    }

    private func handleShare(_ photo: PhotoData) {
        HapticsManager.shared.light()
        print("Shared photo: \(photo.id)")
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

