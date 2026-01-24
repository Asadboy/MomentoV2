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

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var cardBackground: Color {
        Color(red: 0.12, green: 0.1, blue: 0.16)
    }

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
        case .processing:
            return "Photos developing"
        case .revealed:
            return "Photos ready"
        }
    }

    /// Member count text
    private var memberText: String {
        if event.memberCount == 1 {
            return "1 friend"
        } else {
            return "\(event.memberCount) friends"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Event title
            Text(event.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Timing and member info
            Text("\(timingText) \u{2022} \(memberText)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)

            // Join button
            Button {
                isJoining = true
                onJoin()
            } label: {
                HStack {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Join the momento")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [royalPurple, royalPurple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isJoining)
            .padding(.horizontal, 20)

            // Cancel button
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .disabled(isJoining)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.5), radius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(royalPurple.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        EventPreviewModal(
            event: Event(
                title: "Joe's 26th Birthday",
                coverEmoji: "",
                startsAt: Date().addingTimeInterval(3600 * 8),
                endsAt: Date().addingTimeInterval(3600 * 20),
                releaseAt: Date().addingTimeInterval(3600 * 44),
                memberCount: 8,
                photosTaken: 0
            ),
            onJoin: {},
            onCancel: {}
        )
    }
}
