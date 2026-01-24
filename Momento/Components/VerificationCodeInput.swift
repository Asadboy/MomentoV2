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

            // Visual character boxes
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .frame(width: 44, height: 56)

            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrent ? royalPurple : royalPurple.opacity(0.5),
                    lineWidth: isCurrent ? 2 : 1
                )
                .frame(width: 44, height: 56)

            if isCurrent && character.isEmpty {
                // Blinking cursor
                Rectangle()
                    .fill(royalPurple)
                    .frame(width: 2, height: 24)
                    .opacity(0.8)
            }

            Text(character)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .shadow(color: isCurrent ? royalPurple.opacity(0.4) : .clear, radius: 8)
    }
}

#Preview {
    ZStack {
        Color(red: 0.05, green: 0.05, blue: 0.1)
            .ignoresSafeArea()

        VerificationCodeInput(code: .constant("HIJ"), maxLength: 8)
    }
}
