import SwiftUI

struct AccordionRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    init(
        icon: String,
        title: String,
        subtitle: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticsManager.shared.selectionChanged()
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            // Expandable content
            if isExpanded {
                content()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.05))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            AccordionRow(
                icon: "calendar",
                title: "Start",
                subtitle: "Tomorrow at 6pm",
                isExpanded: .constant(true)
            ) {
                Text("Content here")
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}
