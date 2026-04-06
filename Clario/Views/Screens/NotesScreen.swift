import SwiftUI
import SwiftData

struct NotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: languageStore.localized("notes.screen.title"),
                    subtitle: languageStore.localizedFormat("notes.screen.subtitle_stored", Int64(notes.count))
                )

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
