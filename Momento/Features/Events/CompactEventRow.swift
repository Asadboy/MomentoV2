//
//  CompactEventRow.swift
//  Momento
//
//  Compact single-row card for past events (processing, revealed).
//  Used in the "PAST MOMENTOS" section below the featured active cards.
//

import SwiftUI

struct CompactEventRow: View {
    let event: Event
    let now: Date
    var userHasCompletedReveal: Bool = false
    var likedCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void

    // MARK: - State

    private enum RowState {
        case processing
        case readyToReveal
        case revealed
    }

    private var rowState: RowState {
        switch event.currentState(at: now) {
        case .processing:
            return .processing
        case .revealed:
            return userHasCompletedReveal ? .revealed : .readyToReveal
        default:
            return .revealed
        }
    }

    private var secondsUntilReveal: Int {
        max(0, Int(event.releaseAt.timeIntervalSince(now)))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // State icon
            stateIcon

            // Event name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                subtitle
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(rowState == .readyToReveal ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }

    // MARK: - State Icon

    @ViewBuilder
    private var stateIcon: some View {
        switch rowState {
        case .processing:
            Image(systemName: "film.stack")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.orange.opacity(0.15)))

        case .readyToReveal:
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.cyan)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.cyan.opacity(0.15)))

        case .revealed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var subtitle: some View {
        switch rowState {
        case .processing:
            Text("Developing · reveals \(formatRevealTime())")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

        case .readyToReveal:
            Text("Ready to reveal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.cyan.opacity(0.8))

        case .revealed:
            Text(likedCount > 0 ? "\(likedCount) liked" : "Tap to relive")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Time Formatting

    private func formatRevealTime() -> String {
        let hours = secondsUntilReveal / 3600
        let minutes = (secondsUntilReveal % 3600) / 60

        if hours >= 24 {
            return "in \(hours / 24)d"
        } else if hours >= 1 {
            return "in \(hours)h"
        } else if minutes >= 1 {
            return "in \(minutes)m"
        } else {
            return "any moment"
        }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    ScrollView {
        VStack(spacing: 8) {
            CompactEventRow(
                event: Event(
                    name: "Weekend Getaway",
                    coverEmoji: "\u{1F3D6}",
                    startsAt: now.addingTimeInterval(-3600 * 26),
                    endsAt: now.addingTimeInterval(-3600 * 2),
                    releaseAt: now.addingTimeInterval(3600 * 22)
                ),
                now: now,
                onTap: {},
                onLongPress: {}
            )

            CompactEventRow(
                event: Event(
                    name: "Sarah's Graduation",
                    coverEmoji: "\u{1F393}",
                    startsAt: now.addingTimeInterval(-3600 * 72),
                    endsAt: now.addingTimeInterval(-3600 * 48),
                    releaseAt: now.addingTimeInterval(-3600 * 1)
                ),
                now: now,
                onTap: {},
                onLongPress: {}
            )

            CompactEventRow(
                event: Event(
                    name: "Summer BBQ",
                    coverEmoji: "\u{1F356}",
                    startsAt: now.addingTimeInterval(-3600 * 168),
                    endsAt: now.addingTimeInterval(-3600 * 144),
                    releaseAt: now.addingTimeInterval(-3600 * 120)
                ),
                now: now,
                userHasCompletedReveal: true,
                likedCount: 14,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding(16)
    }
    .background(Color.black)
}
