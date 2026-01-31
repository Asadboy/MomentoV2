import SwiftUI

enum PhotoFilter: String, CaseIterable {
    case br = "BR"
    case hf = "HF"
    case raw = "RAW"

    var displayName: String {
        rawValue
    }

    var description: String {
        switch self {
        case .br: return "Warm vintage tones"
        case .hf: return "Cool film look"
        case .raw: return "No filter applied"
        }
    }
}

struct FilterPickerView: View {
    @Binding var selectedFilter: PhotoFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ForEach(PhotoFilter.allCases, id: \.self) { filter in
                    FilterOptionView(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                            HapticsManager.shared.selectionChanged()
                        }
                    )
                }
            }

            Text(selectedFilter.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct FilterOptionView: View {
    let filter: PhotoFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Filter preview thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(filterPreviewGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(filter.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )

                // Selection indicator dot
                Circle()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var filterPreviewGradient: LinearGradient {
        switch filter {
        case .br:
            return LinearGradient(
                colors: [Color.orange.opacity(0.6), Color.red.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hf:
            return LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .raw:
            return LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FilterPickerView(selectedFilter: .constant(.br))
            .padding()
    }
}
