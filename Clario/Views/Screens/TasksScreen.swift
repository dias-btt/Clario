import SwiftUI
import SwiftData

struct TasksScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    private var todayTasks: [TaskItem] {
        tasks.filter { $0.isToday && !$0.isCompleted }
    }

    private var upcomingTasks: [TaskItem] {
        tasks.filter { !$0.isToday && !$0.isCompleted }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter(\.isCompleted)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: languageStore.localized("tasks.screen.title"),
                    subtitle: languageStore.localizedFormat(
                        "tasks.screen.subtitle_open",
                        Int64(tasks.filter { !$0.isCompleted }.count)
                    )
                )

                if tasks.isEmpty {
                    EmptyStateView(
                        title: languageStore.localized("tasks.empty.title"),
                        message: languageStore.localized("tasks.empty.message"),
                        systemImage: "checklist.checked"
                    )
                } else {
                    if !todayTasks.isEmpty {
                        taskSection(
                            title: languageStore.localized("tasks.section.today"),
                            subtitle: languageStore.localized("tasks.section.today_subtitle"),
                            tasks: todayTasks
                        )
                    }

                    if !upcomingTasks.isEmpty {
                        taskSection(
                            title: languageStore.localized("tasks.section.next_up"),
                            subtitle: languageStore.localized("tasks.section.next_up_subtitle"),
                            tasks: upcomingTasks
                        )
                    }

                    if !completedTasks.isEmpty {
                        taskSection(
                            title: languageStore.localized("tasks.section.done"),
                            subtitle: languageStore.localized("tasks.section.done_subtitle"),
                            tasks: completedTasks
                        )
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .animation(.snappy, value: tasks.count)
    }

    @ViewBuilder
    private func taskSection(title: String, subtitle: String, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title, subtitle: subtitle)

            ForEach(tasks) { task in
                TaskCardView(
                    task: task,
                    onToggleComplete: { toggleCompletion(for: task) },
                    onToggleToday: { toggleToday(for: task) },
                    onDelete: { delete(task) }
                )
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func toggleCompletion(for task: TaskItem) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            task.isCompleted.toggle()
        }
        saveContext()
    }

    private func toggleToday(for task: TaskItem) {
        withAnimation(.snappy) {
            task.isToday.toggle()
        }
        saveContext()
    }

    private func delete(_ task: TaskItem) {
        withAnimation(.snappy) {
            modelContext.delete(task)
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save task changes: \(error)")
        }
    }
}
