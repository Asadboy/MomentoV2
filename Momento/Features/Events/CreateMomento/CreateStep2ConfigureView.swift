import SwiftUI

struct CreateStep2ConfigureView: View {
    let eventName: String
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var releaseAt: Date
    @Binding var selectedFilter: PhotoFilter
    let onNext: () -> Void
    let onBack: () -> Void

    // Accordion expansion states
    @State private var isStartsExpanded = false
    @State private var isFilterExpanded = false

    private let royalPurple = Color(red: 0.5, green: 0.0, blue: 0.8)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Step 2 of 3")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Title
                VStack(spacing: 8) {
                    Text("Set the vibe")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("\"\(eventName)\"")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Rows
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. Start - expandable with date picker
                        AccordionRow(
                            icon: "calendar",
                            title: "Start",
                            subtitle: formatDateTime(startsAt),
                            isExpanded: $isStartsExpanded
                        ) {
                            DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                        }

                        // 2. Capture ends - non-expandable info row
                        ConfigInfoRow(
                            icon: "camera",
                            title: "Capture ends",
                            subtitle: formatDateTime(endsAt)
                        )

                        // 3. Reveal - non-expandable info row
                        ConfigInfoRow(
                            icon: "sparkles",
                            title: "Reveal",
                            subtitle: formatDateTime(releaseAt)
                        )

                        // 4. Filter - expandable with filter picker
                        AccordionRow(
                            icon: "camera.filters",
                            title: "Filter",
                            subtitle: selectedFilter.displayName,
                            isExpanded: $isFilterExpanded
                        ) {
                            FilterPickerView(selectedFilter: $selectedFilter)
                        }
                    }
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Next button
                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(royalPurple)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: startsAt) { _, newValue in
            endsAt = newValue.addingTimeInterval(12 * 3600)
            releaseAt = newValue.addingTimeInterval(24 * 3600)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Non-expandable info row (matches AccordionRow header style without chevron or tap)

private struct ConfigInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
    }
}

#Preview {
    CreateStep2ConfigureView(
        eventName: "Asad's Birthday",
        startsAt: .constant(Date()),
        endsAt: .constant(Date().addingTimeInterval(12 * 3600)),
        releaseAt: .constant(Date().addingTimeInterval(24 * 3600)),
        selectedFilter: .constant(.br),
        onNext: {},
        onBack: {}
    )
}
