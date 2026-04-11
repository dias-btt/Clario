import SwiftUI
import SwiftData

struct IdeasScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \IdeaItem.createdAt, order: .reverse) private var ideas: [IdeaItem]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ideasScrollContent()
        }
        .scrollClipDisabled()
        .animation(.snappy, value: ideas.count)
    }

    @ViewBuilder
    private func ideasScrollContent() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ideasScreenHeader()
            ideasBody()
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func ideasScreenHeader() -> some View {
        SectionHeaderView(
            title: languageStore.localized("ideas.screen.title"),
            subtitle: languageStore.localizedFormat("ideas.screen.subtitle_captured", Int64(ideas.count))
        )
    }

    @ViewBuilder
    private func ideasBody() -> some View {
        if ideas.isEmpty {
            EmptyStateView(
                title: languageStore.localized("ideas.empty.title"),
                message: languageStore.localized("ideas.empty.message"),
                systemImage: "lightbulb.max"
            )
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(ideas) { idea in
                    IdeaCardView(idea: idea) {
                        delete(idea)
                    }
                }
            }
        }
    }

    private func delete(_ idea: IdeaItem) {
        withAnimation(.snappy) {
            modelContext.delete(idea)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save idea deletion: \(error)")
        }
    }
}
