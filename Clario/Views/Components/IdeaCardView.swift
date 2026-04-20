import SwiftUI

struct IdeaCardView: View {
    let idea: IdeaItem
    let paletteIndex: Int
    let onDelete: () -> Void

    @Bindable private var languageStore = AppLanguageStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        ideaCardStack()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ClarioPalette.cardStroke(colorScheme), lineWidth: 1)
            }
            .shadow(color: accentGlow.opacity(0.22), radius: 20, y: 12)
            .rotationEffect(.degrees(isExpanded ? 0 : (paletteIndex % 2 == 0 ? -0.6 : 0.6)))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    isExpanded.toggle()
                }
            }
    }

    private var accentGlow: Color {
        let colors = [ClarioPalette.indigo, ClarioPalette.warmAmber, ClarioPalette.calmGreen, ClarioPalette.roseGlow]
        return colors[paletteIndex % colors.count]
    }

    private var cardGradient: LinearGradient {
        let bases: [[Color]] = [
            [Color(hex: "EEF2FF"), Color(hex: "E0E7FF")],
            [Color(hex: "ECFDF5"), Color(hex: "D1FAE5")],
            [Color(hex: "FFF7ED"), Color(hex: "FFEDD5")],
            [Color(hex: "FDF2F8"), Color(hex: "FCE7F3")]
        ]
        let darkBases: [[Color]] = [
            [ClarioPalette.slateSoft, Color(hex: "312E81").opacity(0.55)],
            [ClarioPalette.slateSoft, Color(hex: "064E3B").opacity(0.45)],
            [ClarioPalette.slateSoft, Color(hex: "78350F").opacity(0.4)],
            [ClarioPalette.slateSoft, Color(hex: "831843").opacity(0.4)]
        ]
        let pair = colorScheme == .dark ? darkBases[paletteIndex % darkBases.count] : bases[paletteIndex % bases.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func ideaCardStack() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ideaCardToolbar()
            ideaCardBody()
            ideaCardMetaRow()
        }
    }

    @ViewBuilder
    private func ideaCardToolbar() -> some View {
        HStack {
            Label(languageStore.localized("card.badge.idea"), systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(accentGlow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accentGlow.opacity(0.14), in: Capsule())

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func ideaCardBody() -> some View {
        Text(idea.content)
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(ClarioPalette.primaryText(colorScheme))
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .lineLimit(isExpanded ? nil : 4)
    }

    @ViewBuilder
    private func ideaCardMetaRow() -> some View {
        HStack {
            Text(idea.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme))

            Spacer()

            Image(systemName: isExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme).opacity(0.85))
        }
    }
}
