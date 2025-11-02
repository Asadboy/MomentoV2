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

struct ContentView: View {
    // MARK: - State Management
    
    /// Momentos array - manages all momentos in the app
    @State private var events: [Event] = makeFakeEvents()
    
    /// Current time for countdown updates (updated by timer)
    @State private var now: Date = .now
    
    // MARK: - Add Event Sheet State
    
    /// Controls whether the add event sheet is presented
    @State private var showAddSheet = false
    
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
                    EventRow(event: event, now: now)
                        .listRowSeparator(.hidden) // Hide default separators for card design
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear) // Transparent row background
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
            .navigationTitle("Momentos")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
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
}

#Preview { ContentView() }
