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
    @Binding var endsAt: Date
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var showStartPicker = false
    @State private var showEndPicker = false
    
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
                    
                    Text("Set when photos can be taken")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Time cards
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
                                if showStartPicker { showEndPicker = false }
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
                    
                    // Ends at
                    TimePickerCard(
                        label: "Ends",
                        date: endsAt,
                        dateText: dateFormatter.string(from: endsAt),
                        timeText: timeFormatter.string(from: endsAt),
                        isExpanded: showEndPicker,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                showEndPicker.toggle()
                                if showEndPicker { showStartPicker = false }
                            }
                        }
                    )
                    
                    if showEndPicker {
                        DatePicker("", selection: $endsAt, in: startsAt..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 20)
                
                // Duration indicator
                if !showStartPicker && !showEndPicker {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        
                        Text(durationText)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))
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
        endsAt > startsAt
    }
    
    private var durationText: String {
        let interval = endsAt.timeIntervalSince(startsAt)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m duration"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "") duration"
        } else {
            return "\(minutes) minute\(minutes > 1 ? "s" : "") duration"
        }
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
        endsAt: .constant(Date().addingTimeInterval(6 * 3600)),
        onNext: {},
        onBack: {}
    )
}

