import SwiftData
import SwiftUI

struct IdeasScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \IdeaItem.createdAt, order: .reverse) private var ideas: [IdeaItem]

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ideasScrollContent()
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: ideas.count)
    }

    @ViewBuilder
    private func ideasScrollContent() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ideasScreenHeader()
            ideasBody()
        }
        .padding(.vertical, 8)
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
                systemImage: "sparkles"
            )
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(ideas.enumerated()), id: \.element.id) { index, idea in
                    IdeaCardView(idea: idea, paletteIndex: index) {
                        delete(idea)
                    }
                    .gridCellColumns(masonrySpan(for: index))
                }
            }
        }
    }

    /// Light masonry feel: every sixth card spans both columns like a “pin”.
    private func masonrySpan(for index: Int) -> Int {
        (index % 6 == 3) ? 2 : 1
    }

    private func delete(_ idea: IdeaItem) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            modelContext.delete(idea)
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save idea deletion: \(error)")
        }
    }
}
