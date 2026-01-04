//
//  CreateStep2TimesView.swift
//  Momento
//
//  Step 2 of Create Momento flow: Set event times
//

import SwiftUI

struct CreateStep2TimesView: View {
    let momentoName: String
    @Binding var startsAt: Date
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showStartPicker = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text("Step 2 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Main content
            VStack(spacing: 40) {
                // Title
                VStack(spacing: 12) {
                    Text("When's the party?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Pick when your event starts")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Time picker
                VStack(spacing: 16) {
                    // Starts at
                    TimePickerCard(
                        label: "Starts",
                        date: startsAt,
                        dateText: dateFormatter.string(from: startsAt),
                        timeText: timeFormatter.string(from: startsAt),
                        isExpanded: showStartPicker,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                showStartPicker.toggle()
                            }
                        }
                    )

                    if showStartPicker {
                        DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 20)

                // Calculated times info
                if !showStartPicker {
                    VStack(spacing: 0) {
                        // Photo taking window
                        InfoCard(
                            icon: "camera.fill",
                            title: "Photo Window",
                            description: "12 hours",
                            detail: "Until \(dateTimeFormatter.string(from: endsAt))"
                        )

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)

                        // Reveal time
                        InfoCard(
                            icon: "clock.fill",
                            title: "Photos Reveal",
                            description: "24 hours after start",
                            detail: dateTimeFormatter.string(from: releaseAt)
                        )
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // Next button
            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(isValidTimes ? .black : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isValidTimes
                        ? Color.white
                        : Color.white.opacity(0.1)
                )
                .cornerRadius(16)
            }
            .disabled(!isValidTimes)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(backgroundGradient)
    }
    
    private var isValidTimes: Bool {
        true // Always valid since we only need start time
    }

    // Auto-calculated times
    private var endsAt: Date {
        startsAt.addingTimeInterval(12 * 3600) // +12 hours
    }

    private var releaseAt: Date {
        startsAt.addingTimeInterval(24 * 3600) // +24 hours
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Time Picker Card

struct TimePickerCard: View {
    let label: String
    let date: Date
    let dateText: String
    let timeText: String
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Label
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 50, alignment: .leading)
                
                Spacer()
                
                // Date
                HStack(spacing: 12) {
                    Text(dateText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(timeText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isExpanded ? 0.12 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(isExpanded ? 0.2 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateStep2TimesView(
        momentoName: "Sopranos Party",
        startsAt: .constant(Date()),
        onNext: {},
        onBack: {}
    )
}

