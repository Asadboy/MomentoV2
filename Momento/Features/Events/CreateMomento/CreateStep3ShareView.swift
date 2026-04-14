//
//  CreateStep3ShareView.swift
//  Momento
//
//  Step 3 of Create Momento flow: invite screen
//

import SwiftUI

struct CreateStep3ShareView: View {
    let momentoName: String
    let joinCode: String
    let startsAt: Date
    let hostName: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Step 3 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Invite your\npeople")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("Scan or share the code below")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }

                InviteContentView(
                    eventName: momentoName,
                    joinCode: joinCode,
                    startsAt: startsAt,
                    hostName: hostName
                )
            }

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    CreateStep3ShareView(
        momentoName: "Sopranos Party",
        joinCode: "SOPRAN",
        startsAt: Date(),
        hostName: "Asad",
        onDone: {}
    )
}
