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
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text("Step 1 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))

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
            VStack(spacing: 40) {
                // Title
                VStack(spacing: 8) {
                    Text("Name your\nevent")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("What are you capturing?")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Name input — minimal underline style
                VStack(spacing: 12) {
                    TextField("", text: $momentoName)
                        .placeholder(when: momentoName.isEmpty) {
                            Text("e.g. Sopranos Party")
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                        .onSubmit {
                            if isValidName { onNext() }
                        }

                    // Simple white underline
                    Rectangle()
                        .fill(Color.white.opacity(isNameFocused ? 0.4 : 0.15))
                        .frame(height: 1)
                        .frame(maxWidth: 260)
                        .animation(.easeInOut(duration: 0.2), value: isNameFocused)
                }
                .padding(.horizontal, 40)

                // Suggestion chips
                if momentoName.isEmpty {
                    suggestionChips
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                .background(isValidName ? Color.white : Color.white.opacity(0.08))
                .cornerRadius(28)
            }
            .disabled(!isValidName)
            .animation(.easeInOut(duration: 0.2), value: isValidName)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        let suggestions = ["Birthday", "Night Out", "Weekend Trip", "Game Day", "Celebration"]

        return FlowLayout(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    momentoName = suggestion
                    HapticsManager.shared.selectionChanged()
                } label: {
                    Text(suggestion)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private var isValidName: Bool {
        !momentoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Flow Layout (wrapping chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (idx, position) in result.positions.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        // First pass: get all sizes
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        // Calculate total width of all items + spacing to center rows
        for (_, size) in sizes.enumerated() {
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }

        // Center the layout
        let offsetX = max(0, (width - totalWidth) / 2)
        positions = positions.map { CGPoint(x: $0.x + offsetX, y: $0.y) }

        return (CGSize(width: width, height: y + rowHeight), positions)
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
