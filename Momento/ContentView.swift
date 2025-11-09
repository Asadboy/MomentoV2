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
    
    /// Momentos array - manages all momentos in the app
    @State private var events: [Event] = makeFakeEvents()
    
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
            List {
                ForEach(events) { event in
                    PremiumEventCard(
                        event: event,
                        now: now,
                        onTap: {
                            // Open camera for taking photos at this event
                            selectedEventForPhoto = event
                            showPhotoCapture = true
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
        }
    }

    // MARK: - Actions
    
    /// Resets form fields to default values before showing add sheet
    private func prepareAddDefaults() {
        newTitle = ""
        newReleaseAt = Date().addingTimeInterval(24 * 3600) // 24 hours from now
        newEmoji = "??" // Default emoji
    }

    /// Saves a new event
    private func saveNewEvent() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let event = Event(
            title: trimmedTitle,
            coverEmoji: newEmoji,
            releaseAt: newReleaseAt,
            memberCount: Int.random(in: 2...30),
            photosTaken: 0  // Start with 0 photos, will increase as people take photos
        )
        events.append(event)
    }

    /// Deletes momentos at specified indices
    private func deleteEvents(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
    }
    
    /// Joins a new event (adds it to the events list)
    /// - Parameter event: The event to join
    private func joinEvent(_ event: Event) {
        // UI-only: Add the joined event to the list
        // In production, this would validate the join code with a backend API
        events.append(event)
    }
    
    /// Handles a captured photo for an event
    /// - Parameters:
    ///   - image: The captured photo
    ///   - event: The event the photo was taken for
    private func handlePhotoCaptured(_ image: UIImage, for event: Event) {
        do {
            var savedPhoto = try PhotoStorageManager.shared.save(image: image, for: event)
            savedPhoto.image = image
            
            // Add photo to storage
            if eventPhotos[event.id] == nil {
                eventPhotos[event.id] = []
            }
            eventPhotos[event.id]?.append(savedPhoto)
            
            // Update event's photosTaken count
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].photosTaken += 1
            }
            
            // In production, this would upload the photo to a backend API
            print("Photo captured for \(event.title). Total photos: \(eventPhotos[event.id]?.count ?? 0)")
        } catch {
            print("Failed to save photo: \(error)")
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
