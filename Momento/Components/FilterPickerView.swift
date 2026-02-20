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
        HStack(spacing: 16) {
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
    }
}

struct FilterOptionView: View {
    let filter: PhotoFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Filter preview thumbnail - smaller, subtle
                RoundedRectangle(cornerRadius: 10)
                    .fill(filterPreviewGradient)
                    .frame(width: 50, height: 50)
                    .opacity(isSelected ? 1.0 : 0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )

                // Label - subtle
                Text(filter.displayName)
                    .font(AppTheme.Fonts.micro)
                    .foregroundColor(isSelected ? AppTheme.Colors.textSecondary : AppTheme.Colors.textQuaternary)
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
