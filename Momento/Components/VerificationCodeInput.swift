//
//  VerificationCodeInput.swift
//  Momento
//
//  Verification-style spread character input for join codes
//

import SwiftUI

struct VerificationCodeInput: View {
    @Binding var code: String
    let maxLength: Int
    var onComplete: (() -> Void)?

    @FocusState private var isFocused: Bool

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var cardBackground: Color {
        Color(red: 0.12, green: 0.1, blue: 0.16)
    }

    var body: some View {
        ZStack {
            // Hidden text field for keyboard input
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    // Extract code from URL if pasted
                    let extracted = extractCodeFromPaste(newValue)
                    // Limit to maxLength and filter to alphanumeric
                    let filtered = String(extracted.uppercased().prefix(maxLength))
                        .filter { $0.isLetter || $0.isNumber }
                    if filtered != code {
                        code = filtered
                    }
                    // Auto-submit when complete
                    if code.count == maxLength {
                        onComplete?()
                    }
                }

            // Visual character boxes - relaxed spacing
            HStack(spacing: 8) {
                ForEach(0..<maxLength, id: \.self) { index in
                    CharacterBox(
                        character: characterAt(index),
                        isCurrent: index == code.count && isFocused,
                        isFilled: index < code.count,
                        royalPurple: royalPurple,
                        cardBackground: cardBackground
                    )
                }
            }
        }
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }

    private func characterAt(_ index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }

    /// Extracts code from pasted URL or returns raw input
    private func extractCodeFromPaste(_ input: String) -> String {
        // Handle momento://join/CODE format
        if input.lowercased().contains("momento://join/") {
            if let range = input.range(of: "momento://join/", options: .caseInsensitive) {
                let afterPrefix = String(input[range.upperBound...])
                return afterPrefix.components(separatedBy: CharacterSet(charactersIn: "?/#")).first ?? input
            }
        }
        // Handle https://*/join/CODE format
        if input.contains("/join/") {
            if let code = input.components(separatedBy: "/join/").last?
                .components(separatedBy: CharacterSet(charactersIn: "?/#")).first {
                return code
            }
        }
        return input
    }
}

private struct CharacterBox: View {
    let character: String
    let isCurrent: Bool
    let isFilled: Bool
    let royalPurple: Color
    let cardBackground: Color

    @State private var cursorVisible = true

    var body: some View {
        ZStack {
            // Ambient glow when current - soft, not harsh
            if isCurrent {
                RoundedRectangle(cornerRadius: 14)
                    .fill(royalPurple.opacity(0.12))
                    .frame(width: 44, height: 54)
                    .blur(radius: 8)
            }

            // Soft filled background
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isFilled
                        ? royalPurple.opacity(0.15)
                        : (isCurrent ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                )
                .frame(width: 40, height: 50)

            // Ultra-subtle border
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrent ? royalPurple.opacity(0.5) : (isFilled ? royalPurple.opacity(0.2) : Color.white.opacity(0.04)),
                    lineWidth: isCurrent ? 1 : 0.5
                )
                .frame(width: 40, height: 50)

            if isCurrent && character.isEmpty {
                // Gentle breathing cursor
                RoundedRectangle(cornerRadius: 1)
                    .fill(royalPurple.opacity(0.7))
                    .frame(width: 2, height: 18)
                    .opacity(cursorVisible ? 0.9 : 0.3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            cursorVisible.toggle()
                        }
                    }
            }

            Text(character)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(isFilled ? .white.opacity(0.95) : .white.opacity(0.3))
        }
        .shadow(color: isFilled ? royalPurple.opacity(0.15) : .clear, radius: 6)
        .scaleEffect(isFilled ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFilled)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCurrent)
    }
}

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        VerificationCodeInput(code: .constant("HIJ"), maxLength: 6)
    }
}
