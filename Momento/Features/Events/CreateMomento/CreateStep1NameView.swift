//
//  CreateStep1NameView.swift
//  Momento
//
//  Step 1 of Create Momento flow: Name your momento
//

import SwiftUI

struct CreateStep1NameView: View {
    @Binding var momentoName: String
    let onNext: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var showSuggestions = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text("Step 1 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                // Invisible spacer for balance
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Main content
            VStack(spacing: 32) {
                // Title
                VStack(spacing: 12) {
                    Text("Name your momento")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("What are you capturing?")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Name input with glow effect
                ZStack {
                    // Glow effect when focused
                    if isNameFocused {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.glowBlue.opacity(0.3), AppTheme.Colors.royalPurple.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 60)
                            .blur(radius: 20)
                            .animation(.easeInOut(duration: 0.3), value: isNameFocused)
                    }

                    VStack(spacing: 8) {
                        TextField("", text: $momentoName)
                            .placeholder(when: momentoName.isEmpty) {
                                Text("e.g. Sopranos Party")
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isNameFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                if isValidName {
                                    onNext()
                                }
                            }

                        // Underline with glow when focused
                        Rectangle()
                            .fill(
                                isNameFocused
                                    ? LinearGradient(
                                        colors: [AppTheme.Colors.glowBlue, AppTheme.Colors.royalPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(momentoName.isEmpty ? 0.2 : 0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                            )
                            .frame(height: 2)
                            .frame(maxWidth: 280)
                            .animation(.easeInOut(duration: 0.2), value: isNameFocused)
                    }
                }
                .padding(.horizontal, 40)

                // Suggested names - prominent chips
                if showSuggestions && momentoName.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(suggestedNames, id: \.self) { suggestion in
                            Button(action: {
                                momentoName = suggestion
                                showSuggestions = false
                                HapticsManager.shared.selectionChanged()
                            }) {
                                Text(suggestion)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(24)
                            }
                        }
                    }
                    .padding(.top, 24)
                }
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
                .foregroundColor(isValidName ? .black : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isValidName
                        ? Color.white
                        : Color.white.opacity(0.1)
                )
                .cornerRadius(16)
            }
            .disabled(!isValidName)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(backgroundGradient)
        .onAppear {
            // Delay focus slightly so the view layout settles before keyboard appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
    }
    
    private var isValidName: Bool {
        !momentoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var suggestedNames: [String] {
        ["Birthday", "Weekend Trip", "Night Out", "Game Day", "Celebration"]
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

            // Ambient glow orb in upper portion (blue + purple reveal colors)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Colors.royalPurple.opacity(0.25),
                            AppTheme.Colors.glowBlue.opacity(0.1),
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

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    CreateStep1NameView(
        momentoName: .constant(""),
        onNext: {},
        onCancel: {}
    )
}

