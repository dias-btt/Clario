import SwiftUI
import SwiftData

struct IdeasScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IdeaItem.createdAt, order: .reverse) private var ideas: [IdeaItem]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: "Ideas",
                    subtitle: "\(ideas.count) captured"
                )

                if ideas.isEmpty {
                    EmptyStateView(
                        title: "No sparks yet",
                        message: "Ideas from your brain dumps will land here as little cards worth revisiting.",
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
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .animation(.snappy, value: ideas.count)
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
