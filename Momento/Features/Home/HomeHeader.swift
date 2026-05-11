//
//  HomeHeader.swift
//  Momento
//
//  Top bar of the home screen — app wordmark + QR scan + profile shortcut.
//  Both icons funnel through HomeRouter so navigation stays centralised.
//

import SwiftUI

struct HomeHeader: View {
    @ObservedObject var router: HomeRouter

    var body: some View {
        HStack {
            Text("10shots")
                .font(.custom("RalewayDots-Regular", size: 32))
                .foregroundColor(.white)

            Spacer()

            Button { router.showJoin() } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button { router.showSettings() } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HomeHeader(router: HomeRouter())
    }
}
