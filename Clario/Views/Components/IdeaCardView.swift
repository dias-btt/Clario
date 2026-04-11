import SwiftUI

struct IdeaCardView: View {
    let idea: IdeaItem
    let onDelete: () -> Void

    @Bindable private var languageStore = AppLanguageStore.shared
    @State private var isExpanded = false

    var body: some View {
        ideaCardStack()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ideaCardGradient(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.44, green: 0.39, blue: 0.98).opacity(0.10), radius: 22, y: 12)
            .rotationEffect(.degrees(isExpanded ? 0 : -0.4))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    isExpanded.toggle()
                }
            }
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
                .foregroundStyle(Color(red: 0.48, green: 0.39, blue: 0.97))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.48, green: 0.39, blue: 0.97).opacity(0.10), in: Capsule())

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func ideaCardBody() -> some View {
        Text(idea.content)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 3)
    }

    @ViewBuilder
    private func ideaCardMetaRow() -> some View {
        HStack {
            Text(idea.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: isExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func ideaCardGradient() -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color(red: 0.96, green: 0.94, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
