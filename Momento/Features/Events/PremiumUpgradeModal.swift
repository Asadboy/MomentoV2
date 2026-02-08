//
//  PremiumUpgradeModal.swift
//  Momento
//
//  Dismissible premium upgrade prompt shown to hosts of free events.
//  Appears once per visit when returning from the liked gallery.
//

import SwiftUI

struct PremiumUpgradeModal: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showPurchaseError = false
    @State private var localizedPrice: String = "£7.99"

    // Reveal palette
    private let glowBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    private let glowPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
    private let glowCyan = Color(red: 0.0, green: 0.8, blue: 0.9)

    private var daysUntilExpiry: Int? {
        guard let expiresAt = event.expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
        return days.flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Spacer()

            // Event name — grounding context
            Text(event.name)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 8)

            // Core message
            Text("Keep these photos forever")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 32)

            // Info card — quiet context
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 14))
                        .foregroundColor(glowCyan.opacity(0.6))
                    Text("\(event.photoCount) photos from \(event.memberCount) people")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                }

                if let days = daysUntilExpiry {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Free photos expire in \(days) day\(days == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                        Spacer()
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "infinity")
                        .font(.system(size: 14))
                        .foregroundColor(glowCyan.opacity(0.6))
                    Text("No watermarks, no expiry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
            .padding(.horizontal, 28)

            Spacer()

            // CTA
            VStack(spacing: 20) {
                Button {
                    HapticsManager.shared.medium()
                    isPurchasing = true
                    Task {
                        do {
                            let success = try await PurchaseManager.shared.purchasePremium(for: event.id)
                            isPurchasing = false
                            if success {
                                dismiss()
                            }
                        } catch {
                            isPurchasing = false
                            purchaseError = error.localizedDescription
                            showPurchaseError = true
                            AnalyticsManager.shared.track(.premiumPurchaseFailed, properties: [
                                "event_id": event.id,
                                "reason": error.localizedDescription,
                                "source": "event_screen_modal"
                            ])
                        }
                    }
                } label: {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Keep forever — \(localizedPrice)")
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .cornerRadius(27)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 28)

                Button {
                    AnalyticsManager.shared.track(.premiumPromptDismissed, properties: [
                        "event_id": event.id,
                        "source": "event_screen_modal"
                    ])
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                }
                .disabled(isPurchasing)
            }
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // Base gradient (matches reveal + step 2)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                        Color(red: 0.08, green: 0.06, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Soft ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glowPurple.opacity(0.15),
                                glowBlue.opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 220
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 40, y: -80)
                    .blur(radius: 80)
            }
            .ignoresSafeArea()
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            AnalyticsManager.shared.track(.premiumUpgradePromptSeen, properties: [
                "event_id": event.id,
                "source": "event_screen_modal"
            ])
        }
        .task {
            if let price = await PurchaseManager.shared.getLocalizedPrice() {
                localizedPrice = price
            }
        }
        .alert("Purchase Failed", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "Something went wrong")
        }
    }

}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            PremiumUpgradeModal(
                event: Event(
                    name: "Sopranos Party",
                    coverEmoji: "\u{1F37B}",
                    startsAt: Date().addingTimeInterval(-86400 * 2),
                    endsAt: Date().addingTimeInterval(-86400),
                    releaseAt: Date().addingTimeInterval(-3600),
                    memberCount: 8,
                    photoCount: 47,
                    expiresAt: Date().addingTimeInterval(86400 * 28)
                )
            )
        }
}
