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
                VStack(spacing: 32) {
                    // Title + subtitle
                    VStack(spacing: 8) {
                        Text("When's the party?")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text("Pick when your event starts")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Compact date picker row
                    HStack {
                        Text("Starts")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        DatePicker("", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .tint(AppTheme.Colors.glowBlue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    // Timeline info card
                    VStack(spacing: 0) {
                        // Photo Window row
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Photo Window")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("12 hours")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Until \(formatDateTime(endsAt))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.35))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 20)

                        // Photos Reveal row
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Photos Reveal")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("24 hours after start")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(formatDateTime(releaseAt))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.35))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private var backgroundGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    AppTheme.Colors.bgStart,
                    AppTheme.Colors.bgEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow orb (blue + purple reveal colors)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Colors.royalPurple.opacity(0.2),
                            AppTheme.Colors.glowBlue.opacity(0.08),
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
        onNext: {},
        onBack: {}
    )
}
