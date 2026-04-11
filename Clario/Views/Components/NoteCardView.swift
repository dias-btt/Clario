import SwiftUI

struct NoteCardView: View {
    let note: NoteItem
    let onDelete: () -> Void

    var body: some View {
        noteCardStack()
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
    }

    @ViewBuilder
    private func noteCardStack() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            noteCardHeader()
            noteCardBody()
        }
    }

    @ViewBuilder
    private func noteCardHeader() -> some View {
        HStack {
            Text(note.createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func noteCardBody() -> some View {
        Text(note.content)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
