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
    
    // MARK: - Photo Capture State
    
    /// Controls whether the photo capture sheet is presented
    @State private var showPhotoCapture = false
    
    /// Currently selected event for photo capture
    @State private var selectedEventForPhoto: Event?
    
    // MARK: - Reveal State
    
    /// Controls whether the reveal view is presented
    @State private var showRevealView = false
    
    /// Controls whether the film roll gallery is presented (for completed reveals)
    @State private var showFilmRollGallery = false
    
    /// Currently selected event for reveal
    @State private var selectedEventForReveal: Event?
    
    /// Photos loaded for film roll gallery
    @State private var galleryPhotos: [PhotoData] = []
    
    /// Photo storage: maps event ID to array of photos (UI-only, in-memory)
    @State private var eventPhotos: [String: [EventPhoto]] = [:]

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
                        ForEach(events) { event in
                            PremiumEventCard(
                                event: event,
                                now: now,
                                onTap: {
                                    handleEventTap(event)
                                },
                                onLongPress: {
                                    showInviteSheet(for: event)
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button {
                                    showInviteSheet(for: event)
                                } label: {
                                    Label("Invite Friends", systemImage: "person.badge.plus")
                                }
                            }
                        }
                        .onDelete(perform: deleteEvents)
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
            .fullScreenCover(isPresented: $showRevealView) {
                if let event = selectedEventForReveal {
                    RevealView(event: event)
                        .environmentObject(supabaseManager)
                }
            }
            .fullScreenCover(isPresented: $showFilmRollGallery) {
                if let event = selectedEventForReveal {
                    FilmRollGalleryView(event: event, photos: galleryPhotos)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
            // Check if user has already completed the reveal experience
            if RevealStateManager.shared.hasCompletedReveal(for: event.id) {
                // Already revealed - go straight to film roll gallery
                HapticsManager.shared.light()
                selectedEventForReveal = event
                loadPhotosForGallery(event: event)
            } else {
                // First time - show the reveal experience
                HapticsManager.shared.unlock()
                selectedEventForReveal = event
                showRevealView = true
            }
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
    
    /// Load photos for gallery and show film roll view
    private func loadPhotosForGallery(event: Event) {
        Task {
            do {
                let photos = try await supabaseManager.getPhotos(for: event.id)
                await MainActor.run {
                    self.galleryPhotos = photos
                    self.showFilmRollGallery = true
                }
            } catch {
                print("❌ Failed to load photos for gallery: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load photos"
                    self.showErrorAlert = true
                }
            }
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
            
            await MainActor.run {
                events = eventModels.map { Event(fromSupabase: $0) }
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
    
    /// Joins a new event (adds it to the events list)
    /// - Parameter event: The event to join
    private func joinEvent(_ event: Event) {
        // Event has already been joined via JoinEventSheet
        // Just add it to the local list
        events.append(event)
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
            
            // Update event's photosTaken count optimistically
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].photosTaken += 1
            }
            
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
