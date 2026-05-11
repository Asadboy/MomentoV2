//
//  ContentView.swift
//  Momento
//
//  Home screen. Composes the EventStore (data + side effects) with the local
//  presentation state (which sheet is open, what `now` is for the countdown
//  timer). Phase 1 of the ContentView split: ~400 lines of data work moved to
//  EventStore; this file is the view shell and the sheet plumbing. Phase 2
//  moves sheet state to a HomeRouter.
//

import SwiftUI
import UIKit

struct ContentView: View {
    /// Optional action passed from the onboarding action screen.
    var initialAction: OnboardingAction? = nil

    // MARK: - Data store

    @StateObject private var store = EventStore()

    // MARK: - Time

    /// Current time used to drive countdowns. Updated every second by `timer`.
    @State private var now: Date = .now

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    /// Fires every 10s; the store decides whether to actually refresh based on
    /// whether anything's live (every tick) or not (every 3rd tick).
    private let refreshTimer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()

    // MARK: - Presentation state (Phase 2 moves to HomeRouter)

    @State private var showAddSheet = false
    @State private var showJoinSheet = false
    @State private var pendingJoinCode: String?

    @State private var showPhotoCapture = false
    @State private var selectedEventForPhoto: Event?

    @State private var showStackReveal = false
    @State private var showLikedGallery = false
    @State private var selectedEventForReveal: Event?

    @State private var eventForInvite: Event?

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var showSettings = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    if store.isLoading {
                        Spacer()
                        ProgressView("Loading your events...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if store.hydratedEvents.isEmpty {
                        emptyState
                    } else {
                        eventList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(timer) { now = $0 }
            .task {
                AnalyticsManager.shared.track(.appOpened, properties: [
                    "has_active_event": store.hydratedEvents.contains { $0.event.currentState(at: now) == .live }
                ])
                await store.loadEvents()
            }
            .onAppear(perform: handleInitialAction)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await store.loadEvents()
                }
            }
            .onReceive(refreshTimer) { _ in
                Task { await store.refreshTick(at: now) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .receivedJoinLink)) { note in
                guard let code = note.userInfo?["code"] as? String else { return }
                pendingJoinCode = code
                showJoinSheet = true
            }
            .modifier(HomeSheets(
                store: store,
                showAddSheet: $showAddSheet,
                showJoinSheet: $showJoinSheet,
                pendingJoinCode: $pendingJoinCode,
                showPhotoCapture: $showPhotoCapture,
                selectedEventForPhoto: $selectedEventForPhoto,
                showStackReveal: $showStackReveal,
                showLikedGallery: $showLikedGallery,
                selectedEventForReveal: $selectedEventForReveal,
                eventForInvite: $eventForInvite,
                showErrorAlert: $showErrorAlert,
                errorMessage: $errorMessage,
                showSettings: $showSettings
            ))
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("10shots")
                .font(.custom("RalewayDots-Regular", size: 32))
                .foregroundColor(.white)

            Spacer()

            Button { showJoinSheet = true } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button { showSettings = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("📷")
                        .font(.system(size: 56))

                    Text("Start your first\nevent")
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
                    Button { showAddSheet = true } label: {
                        Text("Create an event")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                    Button { showJoinSheet = true } label: {
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
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                activeSection
                pastSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            await store.loadEvents()
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        let active = store.activeEvents(at: now)

        HStack {
            Text(active.isEmpty ? "NO ACTIVE EVENTS" : "CURRENT EVENTS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            Button { showAddSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }

        ForEach(active) { hydrated in
            EventHeroView(
                event: hydrated.event,
                now: now,
                members: hydrated.members,
                currentUserId: store.currentUserId,
                userHasCompletedReveal: hydrated.userHasCompletedReveal,
                onTap: { handleEventTap(hydrated.event) },
                onLongPress: { eventForInvite = hydrated.event },
                onInvite: { eventForInvite = hydrated.event }
            )
            .overlay {
                if store.newlyJoinedEventId == hydrated.id {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.green.opacity(0.6), lineWidth: 2)
                        .shadow(color: Color.green.opacity(0.4), radius: 12)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: store.newlyJoinedEventId)
            .contextMenu {
                Button {
                    eventForInvite = hydrated.event
                } label: {
                    Label("Invite Friends", systemImage: "person.badge.plus")
                }
            }
        }
    }

    @ViewBuilder
    private var pastSection: some View {
        let past = store.pastEvents(at: now)
        if !past.isEmpty {
            HStack {
                Text("PAST EVENTS")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.top, 8)

            ForEach(past) { hydrated in
                PastEventCard(
                    event: hydrated.event,
                    now: now,
                    photos: hydrated.likedPhotos,
                    totalPhotoCount: hydrated.event.photoCount,
                    totalLikeCount: hydrated.totalLikeCount,
                    memberCount: hydrated.event.memberCount,
                    onTap: { handleEventTap(hydrated.event) },
                    onLongPress: { eventForInvite = hydrated.event }
                )
                .contextMenu {
                    Button {
                        eventForInvite = hydrated.event
                    } label: {
                        Label("Invite Friends", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }

    // MARK: - Tap routing (Phase 2 moves to HomeRouter)

    private func handleEventTap(_ event: Event) {
        switch event.currentState(at: now) {
        case .upcoming:
            break
        case .live:
            selectedEventForPhoto = event
            showPhotoCapture = true
        case .revealed:
            if event.isRevealReady(at: now) {
                selectedEventForReveal = event
                let completed = store.hydratedEvents.first { $0.id == event.id }?.userHasCompletedReveal ?? false
                if completed {
                    HapticsManager.shared.light()
                    showLikedGallery = true
                } else {
                    HapticsManager.shared.unlock()
                    showStackReveal = true
                }
            }
        }
    }

    private func handleInitialAction() {
        guard let action = initialAction else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action {
            case .create: showAddSheet = true
            case .join: showJoinSheet = true
            }
        }
    }
}

// MARK: - Sheets

/// All sheet/cover/alert presentations chained as a ViewModifier so they don't
/// dominate the body. Phase 2 will replace this with a HomeRouter-driven
/// single-sheet presentation.
private struct HomeSheets: ViewModifier {
    @ObservedObject var store: EventStore

    @Binding var showAddSheet: Bool
    @Binding var showJoinSheet: Bool
    @Binding var pendingJoinCode: String?

    @Binding var showPhotoCapture: Bool
    @Binding var selectedEventForPhoto: Event?

    @Binding var showStackReveal: Bool
    @Binding var showLikedGallery: Bool
    @Binding var selectedEventForReveal: Event?

    @Binding var eventForInvite: Event?

    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String

    @Binding var showSettings: Bool

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showAddSheet) {
                CreateMomentoFlow { createdEvent in
                    Task { @MainActor in
                        store.appendCreatedEvent(createdEvent)
                    }
                }
            }
            .sheet(isPresented: $showJoinSheet, onDismiss: { pendingJoinCode = nil }) {
                JoinEventSheet(
                    isPresented: $showJoinSheet,
                    onJoin: { joined in
                        store.joinedEvent(joined)
                    },
                    initialCode: pendingJoinCode
                )
            }
            .sheet(isPresented: $showPhotoCapture) {
                Group {
                    if let event = selectedEventForPhoto {
                        PhotoCaptureSheet(
                            isPresented: $showPhotoCapture,
                            event: event,
                            onPhotoCaptured: { image, event in
                                store.handlePhotoCaptured(image, for: event)
                            }
                        )
                    }
                }
            }
            .sheet(item: $eventForInvite) { event in
                InviteSheet(event: event, onDismiss: { eventForInvite = nil })
            }
            .fullScreenCover(isPresented: $showStackReveal, onDismiss: {
                if let event = selectedEventForReveal,
                   RevealStateManager.shared.hasCompletedReveal(for: event.id) {
                    store.markRevealCompleted(eventId: event.id)
                    Task { await store.loadEvents() }
                }
            }) {
                if let event = selectedEventForReveal {
                    FeedRevealView(event: event) {
                        store.markRevealCompleted(eventId: event.id)
                        showStackReveal = false
                        showLikedGallery = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showLikedGallery) {
                if let event = selectedEventForReveal {
                    LikedGalleryView(event: event) {
                        store.clearRevealCompleted(eventId: event.id)
                        HapticsManager.shared.unlock()
                        showStackReveal = true
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

#Preview { ContentView() }
