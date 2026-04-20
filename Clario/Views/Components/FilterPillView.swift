import SwiftUI

struct FilterPillView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [ClarioPalette.indigo, ClarioPalette.indigoDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Capsule(style: .continuous)
                            .fill(
                                ClarioPalette.cardSurface(colorScheme)
                                    .opacity(colorScheme == .dark ? 0.5 : 0.55)
                            )
                    }
                }
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(stroke, lineWidth: isSelected ? 0 : 1)
                )
                .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isSelected)
    }

    private var foreground: Color {
        isSelected ? .white : ClarioPalette.primaryText(colorScheme).opacity(0.82)
    }

    private var stroke: Color {
        isSelected ? .clear : ClarioPalette.indigo.opacity(colorScheme == .dark ? 0.28 : 0.2)
    }
}
