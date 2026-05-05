//
//  CreateStep2ConfigureView.swift
//  Momento
//
//  Step 2 of Create Momento flow: Pick when the event starts
//

import SwiftUI

struct CreateStep2ConfigureView: View {
    let eventName: String
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var releaseAt: Date
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("Step 2 of 3")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))

                    Spacer()

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
                    VStack(spacing: 8) {
                        Text("When does it\nstart?")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text(eventName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Date picker — clean inline style
                    VStack(spacing: 0) {
                        DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(height: 160)
                            .clipped()
                    }
                    .padding(.horizontal, 24)

                    // Timeline summary
                    timelineSummary
                }

                Spacer()

                // Next button
                Button(action: onNext) {
                    HStack(spacing: 8) {
                        Text("Create event")
                            .font(.system(size: 17, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: startsAt) { _, newValue in
            endsAt = newValue.addingTimeInterval(12 * 3600)
            releaseAt = newValue.addingTimeInterval(24 * 3600)
        }
    }

    // MARK: - Timeline Summary

    private var timelineSummary: some View {
        HStack(spacing: 0) {
            // Start
            timelineNode(
                label: "Start",
                time: formatShortTime(startsAt),
                isActive: true
            )

            // Connector line
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            // End (photos close)
            timelineNode(
                label: "Photos close",
                time: formatShortTime(endsAt),
                isActive: false
            )

            // Connector line
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            // Reveal
            timelineNode(
                label: "Reveal",
                time: formatShortTime(releaseAt),
                isActive: false
            )
        }
        .padding(.horizontal, 32)
    }

    private func timelineNode(label: String, time: String, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.white : Color.white.opacity(0.2))
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(isActive ? 0.6 : 0.35))

            Text(time)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(isActive ? 0.8 : 0.5))
        }
        .frame(minWidth: 80)
    }

    // MARK: - Formatting

    private func formatShortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tmrw' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }
}

#Preview {
    CreateStep2ConfigureView(
        eventName: "Sopranos Party",
        startsAt: .constant(Date()),
        endsAt: .constant(Date().addingTimeInterval(12 * 3600)),
        releaseAt: .constant(Date().addingTimeInterval(24 * 3600)),
        onNext: {},
        onBack: {}
    )
}
