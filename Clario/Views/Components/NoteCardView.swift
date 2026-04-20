import SwiftUI

struct NoteCardView: View {
    let note: NoteItem
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            noteCardHeader()
            noteCardBody()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ClarioPalette.cardSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ClarioPalette.cardStroke(colorScheme), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ClarioPalette.indigo.opacity(0.5), ClarioPalette.calmGreen.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.vertical, 18)
                .padding(.leading, 0)
        }
        .clarioCardShadow(colorScheme: colorScheme)
    }

    @ViewBuilder
    private func noteCardHeader() -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(note.createdAt, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                .font(.system(.caption, design: .serif, weight: .semibold))
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
                .textCase(.uppercase)
                .tracking(0.6)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
                    .frame(width: 32, height: 32)
                    .background(ClarioPalette.primaryText(colorScheme).opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func noteCardBody() -> some View {
        Text(note.content)
            .font(.system(.body, design: .serif))
            .foregroundStyle(ClarioPalette.primaryText(colorScheme))
            .lineSpacing(6)
            .kerning(0.15)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
