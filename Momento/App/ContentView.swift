//
//  ContentView.swift
//  Momento
//
//  Home screen shell. Composes EventStore (data + side effects), HomeRouter
//  (presentation state), and `now` (the 1-second countdown timer state).
//  Section views — HomeHeader, EmptyHomeView, ActiveEventsSection,
//  PastEventsSection — live in Features/Home and each take the store / router
//  / now as parameters.
//
//  This is the final shape after the four-phase split. The file is now ~120
//  lines of orchestration plus a HomePresentations modifier for sheet/cover
//  plumbing.
//

import SwiftUI
import UIKit

struct ContentView: View {
    var initialAction: OnboardingAction? = nil

    @StateObject private var store = EventStore()
    @StateObject private var router = HomeRouter()
    @StateObject private var sync = OfflineSyncManager.shared

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
                    HomeHeader(router: router)

                    UploadFailureBanner(sync: sync)
                        .animation(.easeInOut(duration: 0.25), value: sync.failedCount)

                    if store.isLoading {
                        Spacer()
                        ProgressView("Loading your events...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if store.hydratedEvents.isEmpty {
                        EmptyHomeView(router: router)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ActiveEventsSection(store: store, router: router, now: now)
                                PastEventsSection(store: store, router: router, now: now)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                        }
                        .refreshable { await store.loadEvents() }
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
            .onReceive(NotificationCenter.default.publisher(for: .receivedRevealLink)) { note in
                guard let eventId = note.userInfo?["eventId"] as? String,
                      let hydrated = store.hydratedEvents.first(where: { $0.id == eventId }) else { return }
                router.handleEventTap(hydrated.event, now: now, store: store)
            }
            .modifier(HomePresentations(store: store, router: router))
        }
    }

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

/// Drives all home-screen presentations from the router via a single
/// `.sheet(item:)` and a single `.fullScreenCover(item:)`. Mutual exclusion
/// between presentations is structural — you can't accidentally show two
/// sheets at once.
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
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { (router.errorMessage ?? store.errorMessage) != nil },
                    set: { showing in
                        if !showing {
                            router.errorMessage = nil
                            store.dismissError()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(router.errorMessage ?? store.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .join(let code):
            JoinEventSheet(
                isPresented: Binding(
                    get: { router.sheet?.id == "join" },
                    set: { if !$0 { router.dismissSheet() } }
                ),
                onJoin: { joined in store.joinedEvent(joined) },
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

    /// After any cover dismisses, refresh once so the home reflects any
    /// liked-photo / completion changes that may have happened inside.
    private func handleCoverDismiss() {
        Task { await store.loadEvents() }
    }
}

#Preview { ContentView() }
