//
//  RevealCompleteView.swift
//  Momento
//
//  Closing moment after viewing all photos
//

import SwiftUI

struct RevealCompleteView: View {
    let onViewGallery: () -> Void
    let onClose: () -> Void

    @State private var showContent = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Closing message
            Text("That was the night.")
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            Spacer()

            // View Gallery button
            VStack(spacing: 16) {
                Button(action: onViewGallery) {
                    Text("View Gallery")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 40)

                Button(action: onClose) {
                    Text("Close")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .opacity(showContent ? 1 : 0)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RevealCompleteView(
            onViewGallery: { print("View Gallery") },
            onClose: { print("Close") }
        )
    }
}
