//
//  EventPreviewModal.swift
//  Momento
//
//  Preview modal shown before joining an event
//

import SwiftUI

struct EventPreviewModal: View {
    let event: Event
    let onJoin: () -> Void
    let onCancel: () -> Void

    @State private var isJoining = false
    @State private var appeared = false

    private var cardBackground: Color { Color(white: 0.12) }

    /// Humanized timing text
    private var timingText: String {
        let now = Date()
        let state = event.currentState(at: now)

        switch state {
        case .upcoming:
            let hours = Int(event.startsAt.timeIntervalSince(now) / 3600)
            if hours <= 0 {
                return "Starting soon"
            } else if hours < 6 {
                return "Starts in \(hours)h"
            } else if hours < 12 {
                return "Starts tonight"
            } else if hours < 24 {
                return "Starts tomorrow"
            } else {
                let days = hours / 24
                return days == 1 ? "Starts tomorrow" : "Starts in \(days) days"
            }
        case .live:
            return "Live now"
        case .revealed:
            return event.isRevealReady() ? "Shots ready" : "Event ended"
        }
    }

    /// Member count text - placeholder until fetched separately
    private var memberText: String {
        return "People here"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Arrival cue - acknowledgement of the moment
            Text("You're about to join")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, 4)

            // Event title - the hero
            Text(event.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Timing and member info
            HStack(spacing: 12) {
                Label(timingText, systemImage: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Text("·")
                    .foregroundColor(.gray.opacity(0.5))

                Label(memberText, systemImage: "person.2")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .labelStyle(.titleOnly)

            // Join button - warm, inviting
            Button {
                isJoining = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onJoin()
            } label: {
                HStack {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Enter")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isJoining)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Cancel - subtle
            Button {
                onCancel()
            } label: {
                Text("Not now")
                    .font(.system(size: 15))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .disabled(isJoining)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.3), radius: 32, y: 12)
        )
        .padding(.horizontal, 28)
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        EventPreviewModal(
            event: Event(
                name: "Joe's 26th Birthday",
                startsAt: Date().addingTimeInterval(3600 * 8),
                endsAt: Date().addingTimeInterval(3600 * 20),
                releaseAt: Date().addingTimeInterval(3600 * 44)
            ),
            onJoin: {},
            onCancel: {}
        )
    }
}
