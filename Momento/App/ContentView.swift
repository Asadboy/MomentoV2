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
    // MARK: - Initial Action (from onboarding)

    /// Optional action passed from the onboarding action screen
    var initialAction: OnboardingAction? = nil

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

    /// Liked photos per revealed event (event ID -> photos) for album cards
    @State private var pastEventPhotos: [String: [PhotoData]] = [:]

    /// Tracks per-user photo count for each event (for shot counter)
    @State private var userPhotoCounts: [String: Int] = [:]


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

    /// Timer that refreshes event data (counts) every 15 seconds
    private let refreshTimer = Timer.publish(
        every: 15.0,
        on: .main,
        in: .common
    ).autoconnect()

    // MARK: - Sorted Events

    /// Active events (live/upcoming/ready-to-reveal) — shown as large featured cards
    private var activeEvents: [Event] {
        events
            .filter {
                let state = $0.currentState(at: now)
                if state == .live || state == .upcoming { return true }
                // Ready-to-reveal events get the big card treatment
                if state == .revealed && !(revealCompletionStatus[$0.id] ?? false) { return true }
                return false
            }
            .sorted { e1, e2 in
                let s1 = e1.currentState(at: now)
                let s2 = e2.currentState(at: now)
                // Priority: live > ready-to-reveal > upcoming
                func priority(_ event: Event, _ state: Event.State) -> Int {
                    switch state {
                    case .live: return 0
                    case .revealed: return 1 // ready-to-reveal
                    case .upcoming: return 2
                    default: return 3
                    }
                }
                let p1 = priority(e1, s1)
                let p2 = priority(e2, s2)
                if p1 != p2 { return p1 < p2 }
                return e1.startsAt < e2.startsAt
            }
    }

    /// Past events (processing/revealed-and-completed) — shown as compact rows
    private var pastEvents: [Event] {
        events
            .filter {
                let state = $0.currentState(at: now)
                if state == .processing { return true }
                // Only completed reveals go in past
                if state == .revealed && (revealCompletionStatus[$0.id] ?? false) { return true }
                return false
            }
            .sorted { e1, e2 in
                let s1 = e1.currentState(at: now)
                let s2 = e2.currentState(at: now)
                // Processing first, then revealed
                func priority(_ state: Event.State) -> Int {
                    switch state {
                    case .processing: return 0
                    case .revealed: return 1
                    default: return 2
                    }
                }
                let p1 = priority(s1)
                let p2 = priority(s2)
                if p1 != p2 { return p1 < p2 }
                return e1.releaseAt > e2.releaseAt
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen black background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    headerView

                    // Content
                    if isLoadingEvents {
                        Spacer()
                        ProgressView("Loading your momentos...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if events.isEmpty {
                        Spacer()
                        VStack(spacing: 32) {
                            VStack(spacing: 12) {
                                Text("📷")
                                    .font(.system(size: 56))

                                Text("Start your first\nMomento")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)

                                Text("10 shots. No retakes. Revealed together.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            }

                            VStack(spacing: 12) {
                                Button {
                                    showAddSheet = true
                                } label: {
                                    Text("Create a Momento")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.white)
                                        .cornerRadius(28)
                                }

                                Button {
                                    showJoinSheet = true
                                } label: {
                                    Text("Join with a code")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(28)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 28)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // MARK: Active Events Section (featured cards)
                                if !activeEvents.isEmpty {
                                    // Section header: CURRENT EVENTS + New
                                    HStack {
                                        Text("CURRENT EVENTS")
                                            .font(.system(size: 13, weight: .semibold))
                                            .tracking(1.5)
                                            .foregroundColor(.white.opacity(0.4))

                                        Spacer()

                                        Button {
                                            showAddSheet = true
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("New")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(.white.opacity(0.7))
                                        }
                                    }

                                    ForEach(activeEvents) { event in
                                        VStack(spacing: 6) {
                                            PremiumEventCard(
                                                event: event,
                                                now: now,
                                                userHasCompletedReveal: revealCompletionStatus[event.id] ?? false,
                                                likedCount: likedCounts[event.id] ?? 0,
                                                memberCount: event.memberCount,
                                                userPhotoCount: userPhotoCounts[event.id] ?? 0,
                                                totalPhotoCount: event.photoCount,
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
                                                        .stroke(Color.green.opacity(0.6), lineWidth: 2)
                                                        .shadow(color: Color.green.opacity(0.4), radius: 12)
                                                }
                                            }
                                            .animation(.easeInOut(duration: 0.3), value: newlyJoinedEventId)
                                            .contextMenu {
                                                Button {
                                                    showInviteSheet(for: event)
                                                } label: {
                                                    Label("Invite Friends", systemImage: "person.badge.plus")
                                                }
                                            }

                                            if event.currentState(at: now) == .live {
                                                Text("Tap card to open camera")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                        }
                                    }
                                } else {
                                    // No active events — still show New button
                                    HStack {
                                        Text("NO ACTIVE EVENTS")
                                            .font(.system(size: 13, weight: .semibold))
                                            .tracking(1.5)
                                            .foregroundColor(.white.opacity(0.4))

                                        Spacer()

                                        Button {
                                            showAddSheet = true
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("New")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }

                                // MARK: Past Events Section (compact rows)
                                if !pastEvents.isEmpty {
                                    HStack {
                                        Text("PAST MOMENTOS")
                                            .font(.system(size: 13, weight: .semibold))
                                            .tracking(1.5)
                                            .foregroundColor(.white.opacity(0.4))

                                        Spacer()
                                    }
                                    .padding(.top, 8)

                                    ForEach(pastEvents) { event in
                                        PastEventCard(
                                            event: event,
                                            now: now,
                                            photos: pastEventPhotos[event.id] ?? [],
                                            totalPhotoCount: event.photoCount,
                                            onTap: {
                                                handleEventTap(event)
                                            },
                                            onLongPress: {
                                                showInviteSheet(for: event)
                                            }
                                        )
                                        .contextMenu {
                                            Button {
                                                showInviteSheet(for: event)
                                            } label: {
                                                Label("Invite Friends", systemImage: "person.badge.plus")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await loadEvents()
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(timer) { now = $0 }
            .task {
                // Track app opened event
                AnalyticsManager.shared.track(.appOpened, properties: [
                    "has_active_event": !events.filter { $0.currentState(at: now) == .live }.isEmpty
                ])
                await loadEvents()
            }
            .onAppear {
                if let action = initialAction {
                    // Small delay so ContentView finishes layout before presenting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        switch action {
                        case .create: showAddSheet = true
                        case .join: showJoinSheet = true
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh events when app comes back to foreground (slight delay to let uploads settle)
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    await loadEvents()
                }
            }
            .onReceive(refreshTimer) { _ in
                // Silently refresh event data (counts) every 15s — no loading spinner
                Task { await refreshEventCounts() }
            }
            .fullScreenCover(isPresented: $showAddSheet) {
                CreateMomentoFlow { createdEvent in
                    Task { @MainActor in
                        events.append(createdEvent)
                    }
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
            .fullScreenCover(isPresented: $showStackReveal, onDismiss: {
                // When reveal is dismissed (any way), sync completion status from persistent storage
                if let event = selectedEventForReveal,
                   RevealStateManager.shared.hasCompletedReveal(for: event.id) {
                    revealCompletionStatus[event.id] = true
                    // Refresh liked data in background
                    Task { await loadEvents() }
                }
            }) {
                if let event = selectedEventForReveal {
                    FeedRevealView(event: event) {
                        // On complete via "View Liked Photos" button
                        revealCompletionStatus[event.id] = true
                        RevealStateManager.shared.markRevealCompleted(for: event.id)
                        showStackReveal = false
                        showLikedGallery = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showLikedGallery) {
                if let event = selectedEventForReveal {
                    LikedGalleryView(event: event) {
                        reReveal(for: event)
                    }
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

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Momento")
                .font(.custom("RalewayDots-Regular", size: 32))
                .foregroundColor(.white)

            Spacer()

            Button {
                showJoinSheet = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Actions
    
    /// Handle event card tap - routes to camera, processing info, or reveal based on state
    private func handleEventTap(_ event: Event) {
        switch event.currentState(at: now) {
        case .upcoming:
            // Event hasn't started yet — nothing to do
            break

        case .live:
            // Event is live - open camera for photo capture
            selectedEventForPhoto = event
            showPhotoCapture = true

        case .processing:
            // Photos are developing — nothing to do, card already shows countdown
            break
            
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

    /// Re-reveal: reset completion status and show reveal flow again
    private func reReveal(for event: Event) {
        revealCompletionStatus[event.id] = nil
        RevealStateManager.shared.clearRevealCompleted(for: event.id)
        selectedEventForReveal = event
        HapticsManager.shared.unlock()
        showStackReveal = true
    }
    
    /// Load events from Supabase (debounced to prevent duplicate requests)
    @MainActor private func loadEvents() async {
        // Prevent duplicate refresh calls from cancelling each other
        guard !isRefreshing else {
            debugLog("⏳ Already refreshing, skipping duplicate call")
            return
        }

        isRefreshing = true
        isLoadingEvents = events.isEmpty // Only show loading if no events yet

        do {
            let eventModels = try await supabaseManager.getMyEvents()
            let loadedEvents = eventModels.map { Event(fromSupabase: $0) }

            // Restore reveal completion from persistent storage (local, instant)
            var restoredRevealStatus: [String: Bool] = [:]
            for event in loadedEvents {
                if RevealStateManager.shared.hasCompletedReveal(for: event.id) {
                    restoredRevealStatus[event.id] = true
                }
            }

            // Show events immediately — don't wait for liked counts/photos
            events = loadedEvents
            revealCompletionStatus.merge(restoredRevealStatus) { _, new in new }
            isLoadingEvents = false

            // Compute real counts from event_members/photos tables for active events
            let currentUserId = supabaseManager.currentUser?.id
            let activeEvents = loadedEvents.filter { $0.currentState() == .live || $0.currentState() == .upcoming }
            let countResults = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
                for event in activeEvents {
                    guard let eventUUID = UUID(uuidString: event.id) else { continue }
                    group.addTask {
                        let memberCount = (try? await self.supabaseManager.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                        let photoCount = (try? await self.supabaseManager.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                        var userCount: Int? = nil
                        if let userId = currentUserId, event.currentState() == .live {
                            userCount = (try? await self.supabaseManager.getPhotoCount(eventId: eventUUID, userId: userId)) ?? 0
                        }
                        return (event.id, memberCount, photoCount, userCount)
                    }
                }
                var results: [(String, Int, Int, Int?)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            for (eventId, memberCount, photoCount, userCount) in countResults {
                if let idx = events.firstIndex(where: { $0.id == eventId }) {
                    events[idx].memberCount = memberCount
                    events[idx].photoCount = photoCount
                }
                if let userCount {
                    userPhotoCounts[eventId] = userCount
                }
            }

            // Fetch liked counts + photos for revealed events IN PARALLEL
            let revealedEvents = loadedEvents.filter { $0.currentState() == .revealed }

            let fetchResults = await withTaskGroup(of: (String, Int, [PhotoData]).self) { group in
                for event in revealedEvents {
                    guard let eventUUID = UUID(uuidString: event.id) else { continue }
                    group.addTask {
                        let count = (try? await self.supabaseManager.getLikedPhotoCount(eventId: eventUUID)) ?? 0
                        let photos = (try? await self.supabaseManager.getLikedPhotos(eventId: eventUUID)) ?? []
                        return (event.id, count, photos)
                    }
                }

                var results: [(String, Int, [PhotoData])] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            // Apply results
            var likeCounts: [String: Int] = [:]
            var pastPhotos: [String: [PhotoData]] = [:]
            for (eventId, count, photos) in fetchResults {
                likeCounts[eventId] = count
                pastPhotos[eventId] = photos
                // Restore reveal status from liked count OR persistent local state
                if count > 0 || RevealStateManager.shared.hasCompletedReveal(for: eventId) {
                    restoredRevealStatus[eventId] = true
                }
            }

            likedCounts = likeCounts
            // Merge photo data: keep existing entries, only update with non-empty fetches
            for (eventId, photos) in pastPhotos {
                if !photos.isEmpty || pastEventPhotos[eventId] == nil {
                    pastEventPhotos[eventId] = photos
                }
            }
            revealCompletionStatus.merge(restoredRevealStatus) { _, new in new }
            isRefreshing = false
            debugLog("✅ Loaded \(eventModels.count) events")
        } catch {
            debugLog("Failed to load events: \(error)")
            isLoadingEvents = false
            isRefreshing = false
        }
    }
    

    /// Silently refresh event counts from the DB without a full reload
    @MainActor private func refreshEventCounts() async {
        guard !events.isEmpty else { return }

        let currentUserId = supabaseManager.currentUser?.id

        // Compute real counts from event_members and photos tables in parallel
        let results = await withTaskGroup(of: (String, Int, Int, Int?).self) { group in
            for event in events {
                guard let eventUUID = UUID(uuidString: event.id) else { continue }
                group.addTask {
                    let memberCount = (try? await self.supabaseManager.getEventMemberCount(eventId: eventUUID)) ?? event.memberCount
                    let photoCount = (try? await self.supabaseManager.getEventPhotoCount(eventId: eventUUID)) ?? event.photoCount
                    var userCount: Int? = nil
                    if let userId = currentUserId, event.currentState() == .live {
                        userCount = (try? await self.supabaseManager.getPhotoCount(eventId: eventUUID, userId: userId)) ?? 0
                    }
                    return (event.id, memberCount, photoCount, userCount)
                }
            }
            var results: [(String, Int, Int, Int?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        for (eventId, memberCount, photoCount, userCount) in results {
            if let idx = events.firstIndex(where: { $0.id == eventId }) {
                events[idx].memberCount = memberCount
                events[idx].photoCount = photoCount
            }
            if let userCount {
                userPhotoCounts[eventId] = userCount
            }
        }
    }

    /// Deletes momentos at specified indices
    private func deleteEvents(at offsets: IndexSet) {
        let eventsToDelete = offsets.map { events[$0] }

        Task { @MainActor in
            for event in eventsToDelete {
                guard let uuid = UUID(uuidString: event.id) else { continue }

                do {
                    try await supabaseManager.deleteEvent(id: uuid)
                    events.removeAll { $0.id == event.id }
                } catch {
                    debugLog("Failed to delete event: \(error)")
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
            debugLog("Invalid event ID")
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
            
            // Optimistically increment the user's shot counter
            let eventId = event.id
            userPhotoCounts[eventId, default: 0] += 1

            debugLog("✅ Photo captured and queued for upload: \(queuedPhoto.id)")
            debugLog("   Pending uploads: \(syncManager.pendingCount)")

            // Refresh real count from server after upload settles
            // This corrects the optimistic count if the upload failed
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s for upload to complete
                if let userId = supabaseManager.currentUser?.id {
                    let realCount = (try? await supabaseManager.getPhotoCount(eventId: eventUUID, userId: userId)) ?? 0
                    await MainActor.run {
                        userPhotoCounts[eventId] = realCount
                    }
                }
            }
        } catch {
            debugLog("❌ Failed to save photo: \(error)")
        }
    }

    /// Shows the invite sheet for an event
    private func showInviteSheet(for event: Event) {
        eventForInvite = event
    }
}

#Preview { ContentView() }
