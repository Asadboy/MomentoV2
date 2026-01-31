import SwiftUI

struct CreateStep2ConfigureView: View {
    let eventName: String
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var releaseAt: Date
    @Binding var selectedFilter: PhotoFilter
    @Binding var isPremiumEnabled: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    // Accordion expansion states
    @State private var isStartsExpanded = false
    @State private var isCaptureEndsExpanded = false
    @State private var isRevealExpanded = false
    @State private var isFilterExpanded = false
    @State private var isPremiumExpanded = false

    private let premiumGold = Color(red: 0.85, green: 0.65, blue: 0.3)
    private let royalPurple = Color(red: 0.5, green: 0.0, blue: 0.8)

    // Keywords that trigger auto-expand of premium row
    private let specialKeywords = ["birthday", "bday", "wedding", "trip", "festival", "holiday", "hen", "stag", "reunion", "anniversary"]

    private var shouldAutoExpandPremium: Bool {
        let lowercaseName = eventName.lowercased()
        return specialKeywords.contains { lowercaseName.contains($0) }
    }

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
                    Text("Configure")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("\"\(eventName)\"")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Accordion rows
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. Starts
                        AccordionRow(
                            icon: "📅",
                            title: "Starts",
                            subtitle: formatDateTime(startsAt),
                            isExpanded: $isStartsExpanded
                        ) {
                            DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                        }

                        // 2. Capture ends
                        AccordionRow(
                            icon: "📷",
                            title: "Capture ends",
                            subtitle: isPremiumEnabled ? formatDateTime(endsAt) : "12 hours after start",
                            isExpanded: $isCaptureEndsExpanded
                        ) {
                            if isPremiumEnabled {
                                DatePicker("", selection: $endsAt, in: startsAt..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            } else {
                                LockedSettingView(
                                    calculatedTime: formatDateTime(startsAt.addingTimeInterval(12 * 3600)),
                                    onPremiumTapped: scrollToPremium
                                )
                            }
                        }

                        // 3. Photos reveal
                        AccordionRow(
                            icon: "✨",
                            title: "Photos reveal",
                            subtitle: isPremiumEnabled ? formatDateTime(releaseAt) : "12 hours after capture",
                            isExpanded: $isRevealExpanded
                        ) {
                            if isPremiumEnabled {
                                DatePicker("", selection: $releaseAt, in: endsAt..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            } else {
                                LockedSettingView(
                                    calculatedTime: formatDateTime(startsAt.addingTimeInterval(24 * 3600)),
                                    onPremiumTapped: scrollToPremium
                                )
                            }
                        }

                        // 4. Filter
                        AccordionRow(
                            icon: "🎨",
                            title: "Filter",
                            subtitle: selectedFilter.displayName,
                            isExpanded: $isFilterExpanded
                        ) {
                            FilterPickerView(selectedFilter: $selectedFilter)
                        }

                        // 5. Premium Momento
                        AccordionRow(
                            icon: "✦",
                            title: "Premium Momento",
                            subtitle: isPremiumEnabled ? "Enabled" : "Off",
                            isExpanded: $isPremiumExpanded
                        ) {
                            PremiumRowView(
                                isPremiumEnabled: $isPremiumEnabled,
                                onEnableTapped: {
                                    isPremiumEnabled.toggle()
                                    if isPremiumEnabled {
                                        AnalyticsManager.shared.track(.premiumEnabled, properties: [
                                            "event_name": eventName
                                        ])
                                    }
                                }
                            )
                        }
                        .onAppear {
                            // Track when premium row is viewed
                            AnalyticsManager.shared.track(.premiumRowViewed, properties: [
                                "event_name": eventName,
                                "is_special_keyword": shouldAutoExpandPremium
                            ])

                            // Auto-expand for special events
                            if shouldAutoExpandPremium {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        isPremiumExpanded = true
                                    }
                                }
                            }
                        }
                    }
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Next button
                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        if isPremiumEnabled {
                            Text("• £7.99")
                                .foregroundColor(premiumGold)
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isPremiumEnabled
                            ? premiumGold
                            : royalPurple
                    )
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: startsAt) { _, newValue in
            if !isPremiumEnabled {
                endsAt = newValue.addingTimeInterval(12 * 3600)
                releaseAt = newValue.addingTimeInterval(24 * 3600)
            }
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • h:mm a"
        return formatter.string(from: date)
    }

    private func scrollToPremium() {
        withAnimation(.spring(response: 0.3)) {
            isPremiumExpanded = true
            isCaptureEndsExpanded = false
            isRevealExpanded = false
        }
        HapticsManager.shared.light()
    }
}

#Preview {
    CreateStep2ConfigureView(
        eventName: "Asad's Birthday",
        startsAt: .constant(Date()),
        endsAt: .constant(Date().addingTimeInterval(12 * 3600)),
        releaseAt: .constant(Date().addingTimeInterval(24 * 3600)),
        selectedFilter: .constant(.br),
        isPremiumEnabled: .constant(false),
        onNext: {},
        onBack: {}
    )
}
