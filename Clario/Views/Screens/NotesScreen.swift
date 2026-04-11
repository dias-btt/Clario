import SwiftUI
import SwiftData

struct NotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            notesScrollContent()
        }
        .scrollClipDisabled()
        .animation(.snappy, value: notes.count)
    }

    @ViewBuilder
    private func notesScrollContent() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            notesScreenHeader()
            notesBody()
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func notesScreenHeader() -> some View {
        SectionHeaderView(
            title: languageStore.localized("notes.screen.title"),
            subtitle: languageStore.localizedFormat("notes.screen.subtitle_stored", Int64(notes.count))
        )
    }

    @ViewBuilder
    private func notesBody() -> some View {
        if notes.isEmpty {
            EmptyStateView(
                title: languageStore.localized("notes.empty.title"),
                message: languageStore.localized("notes.empty.message"),
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
