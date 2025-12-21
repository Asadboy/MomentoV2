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
                    Text("Create Your Momento")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Give it a name people will remember")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Name input
                VStack(spacing: 8) {
                    TextField("", text: $momentoName)
                        .placeholder(when: momentoName.isEmpty) {
                            Text("e.g. Sopranos Party")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                        .onSubmit {
                            if isValidName {
                                onNext()
                            }
                        }
                    
                    // Underline
                    Rectangle()
                        .fill(
                            momentoName.isEmpty 
                                ? Color.white.opacity(0.2) 
                                : Color.white.opacity(0.6)
                        )
                        .frame(height: 2)
                        .frame(maxWidth: 280)
                        .animation(.easeInOut(duration: 0.2), value: momentoName.isEmpty)
                }
                .padding(.horizontal, 40)
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
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
    
    private var isValidName: Bool {
        !momentoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

