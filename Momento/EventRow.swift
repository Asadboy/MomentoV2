//
//  EventRow.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Event card component
//  This is a reusable, sleek event card design that displays event information.

import SwiftUI
import UIKit

/// A sleek, modern card component for displaying an Event in the list
/// Designed with a card-based layout with subtle shadows and rounded corners
struct EventRow: View {
    let event: Event
    let now: Date   // Injected time source so row updates when parent timer ticks
    
    // MARK: - Computed Properties
    
    /// Calculates seconds until release
    private func secondsUntil(_ date: Date, from reference: Date) -> Int {
        max(0, Int(date.timeIntervalSince(reference)))
    }
    
    /// Formats remaining seconds into readable string
    private func formatRemaining(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }
    
    /// Determines if the event is currently live
    private var isLive: Bool {
        secondsUntil(event.releaseAt, from: now) == 0
    }
    
    /// Gets the formatted subtitle
    private var subtitle: String {
        let remaining = secondsUntil(event.releaseAt, from: now)
        if remaining == 0 {
            return "Photos are live 🎉"
        }
        return "Releases in \(formatRemaining(remaining))"
    }
    
    // Royal purple accent color (matches app logo)
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8) // Royal purple RGB(128, 0, 204)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Camera icon badge - represents disposable camera concept
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isLive ? [royalPurple.opacity(0.3), royalPurple.opacity(0.15)] : [royalPurple.opacity(0.2), royalPurple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(royalPurple)
                
                // Emoji overlay in corner
                Text(event.coverEmoji)
                    .font(.system(size: 16))
                    .offset(x: 18, y: -18)
                    .background(
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 24, height: 24)
                    )
            }
            
            // Event information section
            VStack(alignment: .leading, spacing: 8) {
                // Event title with camera concept
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Live indicator dot (only shown when live)
                    if isLive {
                        Circle()
                            .fill(royalPurple)
                            .frame(width: 6, height: 6)
                    }
                }
                
                // Status/subtitle
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isLive ? royalPurple : .secondary)
                    .monospacedDigit()
                
                // Badges row - members and photos taken
                HStack(spacing: 8) {
                    // Members badge
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(event.memberCount)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    
                    // Photos taken badge
                    HStack(spacing: 5) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(event.photosTaken)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(royalPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(royalPurple.opacity(0.2))
                    )
                }
            }
            
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isLive ? royalPurple.opacity(0.5) : Color.primary.opacity(0.1),
                    lineWidth: isLive ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(subtitle), \(event.memberCount) members, \(event.photosTaken) photos taken")
    }
}

#Preview {
    // Lightweight preview fixture
    EventRow(
        event: Event(title: "Preview Party", coverEmoji: "🎉", releaseAt: .now.addingTimeInterval(3600), memberCount: 10, photosTaken: 7),
        now: .now
    )
}

