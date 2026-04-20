import SwiftUI

enum TaskListFilter: String, CaseIterable, Identifiable {
    case all
    case urgent
    case important
    case lowPriority
    case done

    var id: String { rawValue }
}

struct TaskFilterPillsView: View {
    @Binding var selection: TaskListFilter
    let title: (TaskListFilter) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TaskListFilter.allCases) { filter in
                    FilterPillView(
                        title: title(filter),
                        isSelected: selection == filter
                    ) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                            selection = filter
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 4)
        }
    }
}
