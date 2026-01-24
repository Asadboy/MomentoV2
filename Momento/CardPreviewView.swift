//
//  CardPreviewView.swift
//  Momento
//
//  Debug view showing all card states for visual testing
//

import SwiftUI

struct CardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var now: Date = .now

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // Mock events for each state
    private var upcomingEvent: Event {
        Event(
            title: "Joe's 26th Birthday",
            coverEmoji: "\u{1F382}",
            startsAt: now.addingTimeInterval(3600 * 8),  // 8 hours - "Starts tonight"
            endsAt: now.addingTimeInterval(3600 * 16),
            releaseAt: now.addingTimeInterval(3600 * 40),
            memberCount: 12,
            photosTaken: 0
        )
    }

    private var almostLiveEvent: Event {
        Event(
            title: "Team Dinner",
            coverEmoji: "\u{1F37D}",
            startsAt: now.addingTimeInterval(3600 * 2),  // 2 hours - "Almost live"
            endsAt: now.addingTimeInterval(3600 * 8),
            releaseAt: now.addingTimeInterval(3600 * 32),
            memberCount: 6,
            photosTaken: 0
        )
    }

    private var liveEvent: Event {
        Event(
            title: "NYE House Party",
            coverEmoji: "\u{1F389}",
            startsAt: now.addingTimeInterval(-3600),  // Started 1 hour ago
            endsAt: now.addingTimeInterval(3600 * 5),
            releaseAt: now.addingTimeInterval(3600 * 29),
            memberCount: 28,
            photosTaken: 23
        )
    }

    private var processingEvent: Event {
        Event(
            title: "Beach Day",
            coverEmoji: "\u{1F3D6}",
            startsAt: now.addingTimeInterval(-3600 * 10),  // Started 10 hours ago
            endsAt: now.addingTimeInterval(-3600 * 2),      // Ended 2 hours ago
            releaseAt: now.addingTimeInterval(3600 * 4),    // Reveals in 4 hours
            memberCount: 8,
            photosTaken: 45
        )
    }

    private var readyToRevealEvent: Event {
        Event(
            title: "Graduation Party",
            coverEmoji: "\u{1F393}",
            startsAt: now.addingTimeInterval(-3600 * 48),
            endsAt: now.addingTimeInterval(-3600 * 40),
            releaseAt: now.addingTimeInterval(-3600 * 2),  // Released 2 hours ago
            memberCount: 35,
            photosTaken: 89,
            isRevealed: false  // User hasn't completed reveal
        )
    }

    private var revealedEvent: Event {
        Event(
            title: "Sopranos Marathon",
            coverEmoji: "\u{1F37B}",
            startsAt: now.addingTimeInterval(-3600 * 72),
            endsAt: now.addingTimeInterval(-3600 * 64),
            releaseAt: now.addingTimeInterval(-3600 * 24),
            memberCount: 7,
            photosTaken: 47,  // More photos = feels like a richer memory
            isRevealed: true
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 20) {
                        // Section header
                        Text("All Card States")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // 1a. Upcoming - Rally your crew
                        cardSection(title: "1a. Upcoming", subtitle: "8 hours away - rally your crew") {
                            PremiumEventCard(
                                event: upcomingEvent,
                                now: now,
                                userHasCompletedReveal: false,
                                likedCount: 0,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        // 1b. Upcoming - Almost time
                        cardSection(title: "1b. Almost Live", subtitle: "2 hours away - almost time!") {
                            PremiumEventCard(
                                event: almostLiveEvent,
                                now: now,
                                userHasCompletedReveal: false,
                                likedCount: 0,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        // 2. Live
                        cardSection(title: "2. Live", subtitle: "Event in progress, can take photos") {
                            PremiumEventCard(
                                event: liveEvent,
                                now: now,
                                userHasCompletedReveal: false,
                                likedCount: 0,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        // 3. Processing
                        cardSection(title: "3. Processing", subtitle: "Photos developing, waiting for reveal time") {
                            PremiumEventCard(
                                event: processingEvent,
                                now: now,
                                userHasCompletedReveal: false,
                                likedCount: 0,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        // 4. Ready to Reveal
                        cardSection(title: "4. Ready to Reveal", subtitle: "Release time passed, user hasn't swiped yet") {
                            PremiumEventCard(
                                event: readyToRevealEvent,
                                now: now,
                                userHasCompletedReveal: false,
                                likedCount: 0,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        // 5. Revealed - Premium keepsake
                        cardSection(title: "5. Revealed", subtitle: "Your memories - premium keepsake") {
                            PremiumEventCard(
                                event: revealedEvent,
                                now: now,
                                userHasCompletedReveal: true,
                                likedCount: 12,
                                onTap: {},
                                onLongPress: {}
                            )
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Card Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func cardSection(title: String, subtitle: String, @ViewBuilder card: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)

            card()
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    CardPreviewView()
}
