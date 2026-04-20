import SwiftData
import SwiftUI

struct NotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            notesScrollContent()
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: notes.count)
    }

    @ViewBuilder
    private func notesScrollContent() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            notesScreenHeader()
            notesBody()
        }
        .padding(.vertical, 8)
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
                systemImage: "text.book.closed.fill"
            )
        } else {
            VStack(spacing: 16) {
                ForEach(notes) { note in
                    NoteCardView(note: note) {
                        delete(note)
                    }
                    .transition(.opacity.combined(with: .offset(y: 10)))
                }
            }
        }
    }

    private func delete(_ note: NoteItem) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            modelContext.delete(note)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save note deletion: \(error)")
        }
    }
}
