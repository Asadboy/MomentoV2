import SwiftUI

struct CreateStep2ConfigureView: View {
    let eventName: String
    @Binding var startsAt: Date
    @Binding var endsAt: Date
    @Binding var releaseAt: Date
    @Binding var selectedFilter: PhotoFilter
    let onNext: () -> Void
    let onBack: () -> Void

    // Glow colors (reveal palette: blue + purple)
    private let glowBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    private let glowPurple = Color(red: 0.5, green: 0.0, blue: 0.8)

    var body: some View {
        ZStack {
            backgroundGradient

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
                VStack(spacing: 28) {
                    // Title only - no subtitle
                    Text("When does it start?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    // Date/Time picker - the hero
                    ZStack {
                        // Subtle glow behind picker
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [glowBlue.opacity(0.15), glowPurple.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 200)
                            .blur(radius: 40)

                        DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                    .padding(.horizontal, 20)

                    // How it works - one calm block, no icons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text("Capture for 12 hours")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Reveal together at \(formatTime(releaseAt))")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)

                    // Filter - feels optional
                    VStack(spacing: 10) {
                        Text("Filter")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))

                        FilterPickerView(selectedFilter: $selectedFilter)
                            .padding(.horizontal, 50)
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE 'at' h:mm a"
        return formatter.string(from: date)
    }

    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow orb (blue + purple reveal colors)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glowPurple.opacity(0.2),
                            glowBlue.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 50, y: -200)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
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
