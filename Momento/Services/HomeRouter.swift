//
//  HomeRouter.swift
//  Momento
//
//  Owns presentation state for the home screen — which sheet is open, which
//  full-screen cover is open, and any error to surface. Tap-routing
//  (handleEventTap) lives here too: deciding camera vs reveal vs liked-gallery
//  based on event state is routing, not view logic.
//
//  Phase 2 of the ContentView split — lifts 8 bool/optional @State properties
//  and ~30 lines of intent code out of the view. Two enums (HomeSheet and
//  HomeCover) make mutual exclusion structural: SwiftUI can present at most
//  one sheet and one cover at a time, exactly matching today's behaviour.
//

import Foundation
import SwiftUI

/// Sheet-style presentations (slide up from bottom, swipe-down to dismiss).
enum HomeSheet: Identifiable {
    case join(code: String?)
    case photoCapture(event: Event)
    case invite(event: Event)
    case settings

    var id: String {
        switch self {
        case .join: return "join"
        case .photoCapture(let e): return "photoCapture-\(e.id)"
        case .invite(let e): return "invite-\(e.id)"
        case .settings: return "settings"
        }
    }
}

/// Full-screen covers (no swipe-down dismiss, programmatic close only).
enum HomeCover: Identifiable {
    case create
    case stackReveal(event: Event)
    case likedGallery(event: Event)

    var id: String {
        switch self {
        case .create: return "create"
        case .stackReveal(let e): return "stackReveal-\(e.id)"
        case .likedGallery(let e): return "likedGallery-\(e.id)"
        }
    }
}

@MainActor
final class HomeRouter: ObservableObject {

    @Published var sheet: HomeSheet?
    @Published var cover: HomeCover?
    @Published var errorMessage: String?

    // MARK: - Tap routing

    /// Decide what happens when a card is tapped. Pure routing; the store is
    /// passed in so the router stays stateless beyond its presentation
    /// publishes.
    func handleEventTap(_ event: Event, now: Date, store: EventStore) {
        switch event.currentState(at: now) {
        case .upcoming:
            break

        case .live:
            sheet = .photoCapture(event: event)

        case .revealed:
            guard event.isRevealReady(at: now) else { return }
            let completed = store.hydratedEvents
                .first(where: { $0.id == event.id })?
                .userHasCompletedReveal ?? false
            if completed {
                HapticsManager.shared.light()
                cover = .likedGallery(event: event)
            } else {
                HapticsManager.shared.unlock()
                cover = .stackReveal(event: event)
            }
        }
    }

    // MARK: - Intents

    func showCreate() {
        cover = .create
    }

    func showJoin(code: String? = nil) {
        sheet = .join(code: code)
    }

    func showInvite(_ event: Event) {
        sheet = .invite(event: event)
    }

    func showSettings() {
        sheet = .settings
    }

    func showError(_ message: String) {
        errorMessage = message
    }

    func showLikedGallery(_ event: Event) {
        cover = .likedGallery(event: event)
    }

    func showStackReveal(_ event: Event) {
        cover = .stackReveal(event: event)
    }

    // MARK: - Dismissals

    func dismissSheet() { sheet = nil }
    func dismissCover() { cover = nil }
    func dismissError() { errorMessage = nil }
}
