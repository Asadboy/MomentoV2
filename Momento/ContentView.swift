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
    
    /// Currently selected event for reveal
    @State private var selectedEventForReveal: Event?
    
    /// Photo storage: maps event ID to array of photos (UI-only, in-memory)
    @State private var eventPhotos: [String: [EventPhoto]] = [:]
    
    /// Event whose debug gallery is currently presented
    @State private var eventForDebugGallery: Event?
    
    /// Event whose invite sheet is currently presented
    @State private var eventForInvite: Event?
    
    /// Form state for new event creation
    @State private var newTitle = ""
    @State private var newReleaseAt = Date().addingTimeInterval(24 * 3600) // Default: 24 hours from now
    @State private var newEmoji = "??" // Default emoji
    
    // MARK: - Constants
    
    /// Available emoji choices for event covers
    private let emojiChoices = ["??", "??", "??", "??", "??", "??", "??", "??"]
    
    // MARK: - Timer
    
    /// Timer that updates every second to refresh countdowns
    private let timer = Timer.publish(
        every: 1.0, // Update every second
        on: .main,
        in: .common
    ).autoconnect()

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            // List of momentos using modular EventRow component
            ZStack {
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
                            // Show invite/share sheet
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
                        
                        Button {
                            eventForDebugGallery = event
                        } label: {
                            Label("View Debug Photos", systemImage: "photo.stack")
                        }
                    }
                        }
                        .onDelete(perform: deleteEvents)
                    }
                    .listStyle(.plain) // Plain style works better with custom card design
                    .scrollContentBackground(.hidden) // Hide default list background
                }
            }
            .background(
                // Rich dark background with subtle gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1), // Deep dark blue-black
                        Color(red: 0.08, green: 0.06, blue: 0.12)  // Slightly lighter dark purple-black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
                        Label("Join Event", systemImage: "qrcode.viewfinder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareAddDefaults()
                        showAddSheet = true
                    } label: {
                        Label("Add Momento", systemImage: "plus")
                    }
                }
            }
            // Update current time every second for countdown timers
            .onReceive(timer) { now = $0 }
            // Load events from Supabase on appear
            .task {
                await loadEvents()
            }
            // Refresh when returning from background
            .refreshable {
                await loadEvents()
            }
            // Present add event sheet using modular AddEventSheet component
            .sheet(isPresented: $showAddSheet) {
                AddEventSheet(
                    title: $newTitle,
                    releaseAt: $newReleaseAt,
                    emoji: $newEmoji,
                    emojiChoices: emojiChoices,
                    onCancel: { showAddSheet = false },
                    onSave: {
                        saveNewEvent()
                        showAddSheet = false
                    }
                )
            }
            // Present join event sheet
            .sheet(isPresented: $showJoinSheet) {
                JoinEventSheet(isPresented: $showJoinSheet) { joinedEvent in
                    joinEvent(joinedEvent)
                }
            }
            // Present photo capture sheet
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
            .sheet(item: $eventForDebugGallery) { event in
                let photosBinding = Binding<[EventPhoto]>(
                    get: { eventPhotos[event.id] ?? [] },
                    set: { eventPhotos[event.id] = $0 }
                )
                
                DebugEventGalleryView(
                    event: event,
                    photos: photosBinding,
                    onReveal: { revealPhoto($0, for: event) },
                    onDismiss: { eventForDebugGallery = nil }
                )
            }
            .sheet(item: $eventForInvite) { event in
                InviteSheet(event: event, onDismiss: { eventForInvite = nil })
            }
            // Present reveal view (full screen for immersive experience)
            .fullScreenCover(isPresented: $showRevealView) {
                if let event = selectedEventForReveal {
                    RevealView(event: event)
                        .environmentObject(supabaseManager)
                }
            }
        }
    }

    // MARK: - Actions
    
    /// Handle event card tap - routes to camera or reveal based on state
    private func handleEventTap(_ event: Event) {
        // Check if event is ready to reveal (24h+ after release)
        let hoursSinceRelease = now.timeIntervalSince(event.releaseAt) / 3600
        let isReadyToReveal = hoursSinceRelease >= 24 && !event.isRevealed
        
        if isReadyToReveal {
            // Navigate to reveal experience
            HapticsManager.shared.unlock()
            selectedEventForReveal = event
            showRevealView = true
        } else if hoursSinceRelease >= 0 && hoursSinceRelease < 24 {
            // Event is live - open camera
            selectedEventForPhoto = event
            showPhotoCapture = true
        } else {
            // Event is in countdown or already revealed - could open gallery
            if event.isRevealed {
                // Open reveal view to see photos again
                selectedEventForReveal = event
                showRevealView = true
            }
        }
    }
    
    /// Load events from Supabase
    private func loadEvents() async {
        isLoadingEvents = true
        
        do {
            let eventModels = try await supabaseManager.getMyEvents()
            
            await MainActor.run {
                events = eventModels.map { Event(fromSupabase: $0) }
                isLoadingEvents = false
            }
        } catch {
            print("Failed to load events: \(error)")
            await MainActor.run {
                isLoadingEvents = false
            }
        }
    }
    
    /// Resets form fields to default values before showing add sheet
    private func prepareAddDefaults() {
        newTitle = ""
        newReleaseAt = Date().addingTimeInterval(24 * 3600) // 24 hours from now
        newEmoji = "📸" // Default emoji
    }

    /// Saves a new event
    private func saveNewEvent() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        // Generate random 6-character join code
        let joinCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        
        Task {
            do {
                let eventModel = try await supabaseManager.createEvent(
                    title: trimmedTitle,
                    releaseAt: newReleaseAt,
                    joinCode: joinCode
                )
                
                await MainActor.run {
                    let event = Event(fromSupabase: eventModel)
                    events.append(event)
                }
            } catch {
                print("Failed to create event: \(error)")
                // TODO: Show error to user
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
    
    /// Reveals a photo and updates metadata/state
    private func revealPhoto(_ photo: EventPhoto, for event: Event) {
        do {
            try PhotoStorageManager.shared.updateRevealStatus(for: photo, isRevealed: true)
            
            guard let index = eventPhotos[event.id]?.firstIndex(where: { $0.id == photo.id }) else {
                return
            }
            
            // Load image from disk, then update state
            let image = PhotoStorageManager.shared.loadImage(for: photo)
            eventPhotos[event.id]?[index].isRevealed = true
            eventPhotos[event.id]?[index].image = image
        } catch {
            print("Failed to reveal photo: \(error)")
        }
    }
    
    /// Shows the invite sheet for an event
    private func showInviteSheet(for event: Event) {
        eventForInvite = event
    }
}

#Preview { ContentView() }
