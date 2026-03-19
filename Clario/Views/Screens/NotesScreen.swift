import SwiftUI
import SwiftData

struct NotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: "Notes",
                    subtitle: "\(notes.count) stored"
                )

                if notes.isEmpty {
                    EmptyStateView(
                        title: "A quiet page",
                        message: "General thoughts that aren’t tasks or ideas will show up here with clean, readable spacing.",
                        systemImage: "note.text"
                    )
                } else {
                    ForEach(notes) { note in
                        NoteCardView(note: note) {
                            delete(note)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .animation(.snappy, value: notes.count)
    }

    private func delete(_ note: NoteItem) {
        withAnimation(.snappy) {
            modelContext.delete(note)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save note deletion: \(error)")
        }
    }
}
