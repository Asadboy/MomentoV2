//
//  BrandWordmark.swift
//  Momento
//
//  The 10shots "roll mark": bold sans wordmark sitting above a row of 10
//  filled dots — the literal shot counter, reused as the brand signature.
//  Replaces the previous RalewayDots-Regular text-only wordmark everywhere
//  except where space genuinely forbids the dot row (HomeHeader, via the
//  `compact` variant).
//
//  Size param drives text size in points; the dot row scales proportionally
//  so the lockup keeps its visual weight at any size.
//

import SwiftUI

struct BrandWordmark: View {
    /// Wordmark text size in points. The dot row scales from this.
    var size: CGFloat = 56
    var color: Color = .white
    /// When true, the dot row is hidden — use in tight chrome (HomeHeader).
    var compact: Bool = false

    var body: some View {
        VStack(spacing: size * 0.28) {
            Text("10Shots")
                .font(.system(size: size, weight: .bold))
                .tracking(-size * 0.04)
                .foregroundColor(color)

            if !compact {
                HStack(spacing: size * 0.14) {
                    ForEach(0..<10, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: size * 0.17, height: size * 0.17)
                    }
                }
            }
        }
    }
}

#Preview("Sizes on black") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 36) {
            BrandWordmark(size: 72)
            BrandWordmark(size: 56)
            BrandWordmark(size: 36)
            BrandWordmark(size: 24, compact: true)
        }
    }
}

#Preview("Compact only") {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack {
            BrandWordmark(size: 18, compact: true)
            Spacer()
        }
        .padding()
    }
}
