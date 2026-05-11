//
//  ContentView.swift
//  Momento
//
//  Home screen. Composes the EventStore (data + side effects), HomeRouter
//  (presentation state), and local `now` state for the countdown timer.
//  Phase 3 will split the body into HomeHeader, EmptyHomeView,
//  ActiveEventsSection, and PastEventsSection — this file is the thin shell
//  that wires them together.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var initialAction: OnboardingAction? = nil

    @StateObject private var store = EventStore()
    @StateObject private var router = HomeRouter()

    /// Current time used to drive countdowns. Updated every second.
    @State private var now: Date = .now

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    /// Fires every 10s; the store decides whether to actually refresh based on
    /// whether anything's live (every tick) or not (every 3rd tick).
    private let refreshTimer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()

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
                router.showJoin(code: code)
            }
            .modifier(HomePresentations(store: store, router: router))
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("10shots")
                .font(.custom("RalewayDots-Regular", size: 32))
                .foregroundColor(.white)

            Spacer()

            Button { router.showJoin() } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button { router.showSettings() } label: {
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
                    Button { router.showCreate() } label: {
                        Text("Create an event")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                    Button { router.showJoin() } label: {
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

            Button { router.showCreate() } label: {
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
                onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                onLongPress: { router.showInvite(hydrated.event) },
                onInvite: { router.showInvite(hydrated.event) }
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
                Button { router.showInvite(hydrated.event) } label: {
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
                    onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                    onLongPress: { router.showInvite(hydrated.event) }
                )
                .contextMenu {
                    Button { router.showInvite(hydrated.event) } label: {
                        Label("Invite Friends", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func handleInitialAction() {
        guard let action = initialAction else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action {
            case .create: router.showCreate()
            case .join: router.showJoin()
            }
        }
    }
}

// MARK: - Sheet + Cover plumbing

/// Single ViewModifier that drives all home-screen presentations from the
/// router. Replaces the previous wall of 8 `.sheet` / `.fullScreenCover` /
/// `.alert` modifiers driven by individual @State bools.
private struct HomePresentations: ViewModifier {
    @ObservedObject var store: EventStore
    @ObservedObject var router: HomeRouter

    func body(content: Content) -> some View {
        content
            .sheet(item: $router.sheet) { sheet in
                sheetContent(sheet)
            }
            .fullScreenCover(item: $router.cover, onDismiss: handleCoverDismiss) { cover in
                coverContent(cover)
            }
            .alert("Error",
                   isPresented: Binding(
                    get: { router.errorMessage != nil },
                    set: { if !$0 { router.errorMessage = nil } }
                   )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(router.errorMessage ?? "")
            }
    }

    // MARK: - Sheet bodies

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .join(let code):
            JoinEventSheet(
                isPresented: Binding(
                    get: { router.sheet?.id == "join" },
                    set: { if !$0 { router.dismissSheet() } }
                ),
                onJoin: { joined in
                    store.joinedEvent(joined)
                },
                initialCode: code
            )

        case .photoCapture(let event):
            PhotoCaptureSheet(
                isPresented: Binding(
                    get: { router.sheet?.id == "photoCapture-\(event.id)" },
                    set: { if !$0 { router.dismissSheet() } }
                ),
                event: event,
                onPhotoCaptured: { image, event in
                    store.handlePhotoCaptured(image, for: event)
                }
            )

        case .invite(let event):
            InviteSheet(event: event, onDismiss: { router.dismissSheet() })

        case .settings:
            ProfileView()
        }
    }

    // MARK: - Cover bodies

    @ViewBuilder
    private func coverContent(_ cover: HomeCover) -> some View {
        switch cover {
        case .create:
            CreateMomentoFlow { createdEvent in
                Task { @MainActor in
                    store.appendCreatedEvent(createdEvent)
                }
            }

        case .stackReveal(let event):
            FeedRevealView(event: event) {
                store.markRevealCompleted(eventId: event.id)
                router.cover = .likedGallery(event: event)
            }

        case .likedGallery(let event):
            LikedGalleryView(event: event) {
                store.clearRevealCompleted(eventId: event.id)
                HapticsManager.shared.unlock()
                router.cover = .stackReveal(event: event)
            }
        }
    }

    // MARK: - Cover dismiss housekeeping

    /// When the stack reveal closes naturally, sync completion state from
    /// persistent storage and refresh liked data so the past-events section
    /// updates promptly.
    private func handleCoverDismiss() {
        // The cover binding is nil by now; whatever was last shown lives only
        // as side effects.
        Task { await store.loadEvents() }
    }
}

#Preview { ContentView() }
