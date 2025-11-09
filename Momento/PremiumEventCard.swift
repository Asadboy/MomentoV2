//
//  PremiumEventCard.swift
//  Momento
//
//  Premium event card with 3 distinct states:
//  1. Countdown - Circular progress with time remaining
//  2. Live - Animated camera button with photo counter
//  3. Revealed - Gallery access button
//

import SwiftUI

/// Premium event card component with state-aware UI
struct PremiumEventCard: View {
    let event: Event
    let now: Date
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var showExpandedTime = false
    @State private var cameraScale: CGFloat = 1.0
    
    // MARK: - Event State
    
    private enum EventState {
        case countdown
        case live
        case revealed
    }
    
    private var eventState: EventState {
        let remaining = secondsUntil(event.releaseAt, from: now)
        if remaining > 0 {
            return .countdown
        }
        // Check if 24 hours have passed since release
        let hoursSinceRelease = now.timeIntervalSince(event.releaseAt) / 3600
        if hoursSinceRelease >= 24 {
            return .revealed
        }
        return .live
    }
    
    // MARK: - Computed Properties
    
    private func secondsUntil(_ date: Date, from reference: Date) -> Int {
        max(0, Int(date.timeIntervalSince(reference)))
    }
    
    private var remainingSeconds: Int {
        secondsUntil(event.releaseAt, from: now)
    }
    
    private var progress: Double {
        // Assume 24 hour countdown for progress calculation
        let totalSeconds = 24.0 * 3600.0
        let remaining = Double(remainingSeconds)
        return 1.0 - (remaining / totalSeconds)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    private func formatCompactTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    private var cardBackground: Color {
        Color(red: 0.12, green: 0.1, blue: 0.16)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Left: Event info
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // State-specific subtitle
                    stateSubtitle
                    
                    // Metadata badges
                    HStack(spacing: 8) {
                        // Members
                        MetadataBadge(
                            icon: "person.2.fill",
                            value: "\(event.memberCount)",
                            color: .white.opacity(0.6)
                        )
                        
                        // Photos taken (only show if > 0)
                        if event.photosTaken > 0 {
                            MetadataBadge(
                                icon: "photo.fill",
                                value: "\(event.photosTaken)",
                                color: royalPurple
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Right: State indicator (circular countdown, camera, or gallery)
                stateIndicator
                    .frame(width: 72, height: 72)
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    eventState == .live ? royalPurple.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: eventState == .live ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }
    
    // MARK: - State Indicator Views
    
    @ViewBuilder
    private var stateIndicator: some View {
        switch eventState {
        case .countdown:
            countdownIndicator
        case .live:
            cameraButton
        case .revealed:
            galleryButton
        }
    }
    
    private var countdownIndicator: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            royalPurple.opacity(0.15),
                            royalPurple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    royalPurple.opacity(0.8),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            
            // Time display
            VStack(spacing: 2) {
                if showExpandedTime {
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(royalPurple)
                } else {
                    Text(formatCompactTime(remainingSeconds))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(royalPurple)
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showExpandedTime.toggle()
            }
        }
    }
    
    private var cameraButton: some View {
        ZStack {
            // Animated background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            royalPurple.opacity(0.3),
                            royalPurple.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(cameraScale)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: cameraScale
                )
            
            // Camera icon
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(royalPurple)
                
                // Photo counter badge
                if event.photosTaken > 0 {
                    Text("\(event.photosTaken)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(royalPurple)
                        )
                }
            }
        }
        .onAppear {
            cameraScale = 1.1
        }
    }
    
    private var galleryButton: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 4) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("\(event.photosTaken)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var countdownSubtitle: String {
        let hours = remainingSeconds / 3600
        if hours >= 24 {
            let days = hours / 24
            return days == 1 ? "Starts in 1 day" : "Starts in \(days) days"
        } else if hours > 0 {
            return hours == 1 ? "Starts in 1 hour" : "Starts in \(hours) hours"
        } else {
            let minutes = remainingSeconds / 60
            return minutes <= 1 ? "Starting soon" : "Starts in \(minutes) minutes"
        }
    }
    
    @ViewBuilder
    private var stateSubtitle: some View {
        switch eventState {
        case .countdown:
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .medium))
                Text(countdownSubtitle)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
            
        case .live:
            HStack(spacing: 6) {
                Circle()
                    .fill(royalPurple)
                    .frame(width: 6, height: 6)
                Text("Live now - Tap to capture")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(royalPurple)
            
        case .revealed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("Photos revealed")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Metadata Badge Component

private struct MetadataBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Countdown state
        PremiumEventCard(
            event: Event(
                title: "Joe's 26th 🎂",
                coverEmoji: "",
                releaseAt: Date().addingTimeInterval(3600 * 12),
                memberCount: 12,
                photosTaken: 0
            ),
            now: Date(),
            onTap: {},
            onLongPress: {}
        )
        
        // Live state
        PremiumEventCard(
            event: Event(
                title: "NYE House Party 🎉",
                coverEmoji: "",
                releaseAt: Date().addingTimeInterval(-100),
                memberCount: 28,
                photosTaken: 15
            ),
            now: Date(),
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

