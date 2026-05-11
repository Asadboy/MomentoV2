//
//  EmptyHomeView.swift
//  Momento
//
//  Shown when the user has no events at all — the "Start your first event"
//  landing. The two CTAs route through HomeRouter.
//

import SwiftUI

struct EmptyHomeView: View {
    @ObservedObject var router: HomeRouter

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("📷")
                        .font(.system(size: 56))

                    Text("Start your first\nevent")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("10 shots. No retakes. Revealed together.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button { router.showCreate() } label: {
                        Text("Create an event")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                    Button { router.showJoin() } label: {
                        Text("Join with a code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        EmptyHomeView(router: HomeRouter())
    }
}
