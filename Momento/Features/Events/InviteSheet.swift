//
//  InviteSheet.swift
//  Momento
//
//  Sheet for inviting friends to an event — shown on long press
//

import SwiftUI

struct InviteSheet: View {
    let event: Event
    let onDismiss: () -> Void

    @State private var hostName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    Text(event.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    InviteContentView(
                        eventName: event.name,
                        joinCode: event.joinCode ?? "",
                        startsAt: event.startsAt,
                        hostName: hostName
                    )
                }

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .task {
                await fetchHostName()
            }
        }
    }

    private func fetchHostName() async {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        do {
            let profile = try await SupabaseManager.shared.getUserProfile(userId: userId)
            await MainActor.run {
                hostName = profile.displayName ?? profile.username
            }
        } catch {
            await MainActor.run { hostName = "Host" }
        }
    }
}

#Preview {
    let now = Date()
    return InviteSheet(
        event: Event(
            name: "NYE House Party",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            joinCode: "NYE2025"
        ),
        onDismiss: {}
    )
}
