//
//  ContentView.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Main view controller
//  This is the main screen that orchestrates the app.
//  Delegates UI rendering to modular components (EventRow, AddEventSheet).

import SwiftUI
import UIKit

struct ContentView: View {
    // MARK: - State Management
    
    /// Supabase manager instance
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    /// Offline sync manager instance
    @StateObject private var syncManager = OfflineSyncManager.shared
    
    /// Momentos array - manages all momentos in the app
    @State private var events: [Event] = []
    
    /// Loading state for fetching events
    @State private var isLoadingEvents = true
    
    /// Current time for countdown updates (updated by timer)
    @State private var now: Date = .now
    
    // MARK: - Add Event Sheet State
    
    /// Controls whether the add event sheet is presented
    @State private var showAddSheet = false
    
    // MARK: - Join Event Sheet State

    /// Controls whether the join event sheet is presented
    @State private var showJoinSheet = false

    /// ID of event that was just joined (for glow animation)
    @State private var newlyJoinedEventId: String?

    // MARK: - Photo Capture State
    
    /// Controls whether the photo capture sheet is presented
    @State private var showPhotoCapture = false
    
    /// Currently selected event for photo capture
    @State private var selectedEventForPhoto: Event?
    
    // MARK: - Reveal State

    /// Controls whether the stack reveal view is presented
    @State private var showStackReveal = false

    /// Controls whether the liked gallery is presented (after reveal completed)
    @State private var showLikedGallery = false

    /// Currently selected event for reveal
    @State private var selectedEventForReveal: Event?
    
    /// Photo storage: maps event ID to array of photos (UI-only, in-memory)
    @State private var eventPhotos: [String: [EventPhoto]] = [:]

    /// Tracks which events the user has completed revealing (event ID -> completed)
    @State private var revealCompletionStatus: [String: Bool] = [:]

    /// Tracks liked photo count per revealed event (event ID -> count)
    @State private var likedCounts: [String: Int] = [:]

    /// Event whose invite sheet is currently presented
    @State private var eventForInvite: Event?
    
    /// Error alert state
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    /// Debounce for loading events
    @State private var isRefreshing = false
    
    /// Controls whether the settings sheet is presented
    @State private var showSettings = false
    
    
    
    // MARK: - Timer
    
    /// Timer that updates every second to refresh countdowns
    private let timer = Timer.publish(
        every: 1.0, // Update every second
        on: .main,
        in: .common
    ).autoconnect()

    // MARK: - Sorted Events

    /// Events sorted by priority: Live > Ready to Reveal > Upcoming > Revealed
    private var sortedEvents: [Event] {
        events.sorted { event1, event2 in
            let state1 = event1.currentState(at: now)
            let state2 = event2.currentState(at: now)

            // Priority: live (0) > revealed-but-not-completed (1) > upcoming (2) > revealed-completed (3)
            func priority(_ event: Event, _ state: Event.State) -> Int {
                switch state {
                case .live: return 0
                case .revealed:
                    // Check if user completed reveal
                    let completed = revealCompletionStatus[event.id] ?? false
                    return completed ? 3 : 1  // Ready to reveal vs fully revealed
                case .processing: return 1  // Same priority as ready to reveal
                case .upcoming: return 2
                }
            }

            let p1 = priority(event1, state1)
            let p2 = priority(event2, state2)

            if p1 != p2 {
                return p1 < p2
            }

            // Within same priority, sort by relevant date
            switch state1 {
            case .upcoming:
                return event1.startsAt < event2.startsAt  // Soonest first
            case .revealed:
                return event1.releaseAt > event2.releaseAt  // Most recent first
            default:
                return event1.startsAt < event2.startsAt
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen background
                backgroundGradient
                
                // Content
                if isLoadingEvents {
                    ProgressView("Loading your momentos...")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if events.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No momentos yet")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Create or join an event to get started")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(sortedEvents) { event in
                            PremiumEventCard(
                                event: event,
                                now: now,
                                userHasCompletedReveal: revealCompletionStatus[event.id] ?? false,
                                likedCount: likedCounts[event.id] ?? 0,
                                onTap: {
                                    handleEventTap(event)
                                },
                                onLongPress: {
                                    showInviteSheet(for: event)
                                }
                            )
                            .overlay {
                                if newlyJoinedEventId == event.id {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.purple.opacity(0.8),
                                                    Color.blue.opacity(0.6),
                                                    Color.cyan.opacity(0.4)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                        .shadow(color: Color.purple.opacity(0.6), radius: 12)
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: newlyJoinedEventId)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button {
                                    showInviteSheet(for: event)
                                } label: {
                                    Label("Invite Friends", systemImage: "person.badge.plus")
                                }
                            }
                        }
                        // Deletion disabled for safety
                        // .onDelete(perform: deleteEvents)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Momentos")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showJoinSheet = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, weight: .medium))
                        }
                        .tint(.white)
                        
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                        }
                        .tint(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onReceive(timer) { now = $0 }
            .task {
                // Track app opened event
                AnalyticsManager.shared.track(.appOpened, properties: [
                    "has_active_evento": !events.filter { $0.currentState(at: now) == .live }.isEmpty
                ])
                await loadEvents()
            }
            .refreshable {
                await loadEvents()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh events when app comes back to foreground (slight delay to let uploads settle)
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    await loadEvents()
                }
            }
            .fullScreenCover(isPresented: $showAddSheet) {
                CreateMomentoFlow { createdEvent in
                    events.append(createdEvent)
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinEventSheet(isPresented: $showJoinSheet) { joinedEvent in
                    joinEvent(joinedEvent)
                }
            }
            .sheet(isPresented: $showPhotoCapture) {
                Group {
                    if let event = selectedEventForPhoto {
                        PhotoCaptureSheet(
                            isPresented: $showPhotoCapture,
                            event: event,
                            onPhotoCaptured: { image, event in
                                handlePhotoCaptured(image, for: event)
                            }
                        )
                    }
                }
            }
            .sheet(item: $eventForInvite) { event in
                InviteSheet(event: event, onDismiss: { eventForInvite = nil })
            }
            .fullScreenCover(isPresented: $showStackReveal) {
                if let event = selectedEventForReveal {
                    FeedRevealView(event: event) {
                        // On complete - mark as completed and show liked gallery
                        revealCompletionStatus[event.id] = true
                        showStackReveal = false
                        showLikedGallery = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showLikedGallery) {
                if let event = selectedEventForReveal {
                    LikedGalleryView(event: event)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showSettings) {
                ProfileView()
            }
        }
    }

    // MARK: - Actions
    
    /// Handle event card tap - routes to camera, processing info, or reveal based on state
    private func handleEventTap(_ event: Event) {
        switch event.currentState(at: now) {
        case .upcoming:
            // Event hasn't started yet - show info message
            errorMessage = "This momento starts in \(formatTimeUntil(event.startsAt))"
            showErrorAlert = true
            
        case .live:
            // Event is live - open camera for photo capture
            selectedEventForPhoto = event
            showPhotoCapture = true
            
        case .processing:
            // Photos are developing - show countdown to reveal
            errorMessage = "Photos are developing! They'll be ready in \(formatTimeUntil(event.releaseAt))"
            showErrorAlert = true
            
        case .revealed:
            // Check if user has already completed the reveal swipe
            selectedEventForReveal = event
            showReveal(for: event)
        }
    }
    
    /// Format time remaining until a date
    private func formatTimeUntil(_ date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            return days == 1 ? "1 day" : "\(days) days"
        } else if hours > 0 {
            return hours == 1 ? "about 1 hour" : "about \(hours) hours"
        } else if minutes > 0 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        } else {
            return "less than a minute"
        }
    }

    /// Show appropriate reveal view based on local completion status
    private func showReveal(for event: Event) {
        let completed = revealCompletionStatus[event.id] ?? false
        if completed {
            HapticsManager.shared.light()
            showLikedGallery = true
        } else {
            HapticsManager.shared.unlock()
            showStackReveal = true
        }
    }
    
    /// Load events from Supabase (debounced to prevent duplicate requests)
    private func loadEvents() async {
        // Prevent duplicate refresh calls from cancelling each other
        guard !isRefreshing else {
            print("⏳ Already refreshing, skipping duplicate call")
            return
        }

        await MainActor.run {
            isRefreshing = true
            isLoadingEvents = events.isEmpty // Only show loading if no events yet
        }

        do {
            let eventModels = try await supabaseManager.getMyEvents()
            let loadedEvents = eventModels.map { Event(fromSupabase: $0) }

            // Fetch liked counts for revealed events
            var likeCounts: [String: Int] = [:]

            for event in loadedEvents where event.currentState() == .revealed {
                if let eventUUID = UUID(uuidString: event.id) {
                    if let count = try? await supabaseManager.getLikedPhotoCount(eventId: eventUUID) {
                        likeCounts[event.id] = count
                    }
                }
            }

            await MainActor.run {
                events = loadedEvents
                likedCounts = likeCounts
                isLoadingEvents = false
                isRefreshing = false
            }
            print("✅ Loaded \(eventModels.count) events")
        } catch {
            print("Failed to load events: \(error)")
            await MainActor.run {
                isLoadingEvents = false
                isRefreshing = false
            }
        }
    }
    

    /// Deletes momentos at specified indices
    private func deleteEvents(at offsets: IndexSet) {
        let eventsToDelete = offsets.map { events[$0] }
        
        Task {
            for event in eventsToDelete {
                guard let uuid = UUID(uuidString: event.id) else { continue }
                
                do {
                    try await supabaseManager.deleteEvent(id: uuid)
                    
                    await MainActor.run {
                        events.removeAll { $0.id == event.id }
                    }
                } catch {
                    print("Failed to delete event: \(error)")
                    // TODO: Show error to user
                }
            }
        }
    }
    
    /// Joins a new event (adds it to the events list with animation)
    private func joinEvent(_ event: Event) {
        // Set the newly joined ID before adding
        newlyJoinedEventId = event.id

        // Add to list with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            events.append(event)
        }

        // Clear the glow after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                newlyJoinedEventId = nil
            }
        }
    }
    
    /// Handles a captured photo for an event
    /// - Parameters:
    ///   - image: The captured photo
    ///   - event: The event the photo was taken for
    private func handlePhotoCaptured(_ image: UIImage, for event: Event) {
        guard let eventUUID = UUID(uuidString: event.id) else {
            print("Invalid event ID")
            return
        }
        
        do {
            // Save locally first (for immediate viewing)
            var savedPhoto = try PhotoStorageManager.shared.save(image: image, for: event)
            savedPhoto.image = image
            
            // Add photo to local storage
            if eventPhotos[event.id] == nil {
                eventPhotos[event.id] = []
            }
            eventPhotos[event.id]?.append(savedPhoto)
            
            // Queue for upload to Supabase (with offline support)
            let queuedPhoto = try syncManager.queuePhoto(image: image, eventId: eventUUID)
            
            // Photo count is now computed server-side, no local increment needed
            
            print("✅ Photo captured and queued for upload: \(queuedPhoto.id)")
            print("   Pending uploads: \(syncManager.pendingCount)")
        } catch {
            print("❌ Failed to save photo: \(error)")
        }
    }

    /// Shows the invite sheet for an event
    private func showInviteSheet(for event: Event) {
        eventForInvite = event
    }
}

#Preview { ContentView() }
