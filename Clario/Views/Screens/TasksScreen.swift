import SwiftData
import SwiftUI

struct TasksScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \IdeaItem.createdAt, order: .reverse) private var ideas: [IdeaItem]
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    @State private var selectedFilter: TaskListFilter = .all
    @State private var digestSummaryText: String?

    private var filteredTasks: [TaskItem] {
        switch selectedFilter {
        case .all:
            tasks
        case .urgent:
            tasks.filter { !$0.isCompleted && $0.priorityTag == .urgent }
        case .important:
            tasks.filter { !$0.isCompleted && $0.priorityTag == .important }
        case .lowPriority:
            tasks.filter { !$0.isCompleted && $0.priorityTag == .lowPriority }
        case .done:
            tasks.filter(\.isCompleted)
        }
    }

    private var todayTasks: [TaskItem] {
        filteredTasks.filter { $0.isToday && !$0.isCompleted }
    }

    private var upcomingTasks: [TaskItem] {
        filteredTasks.filter { !$0.isToday && !$0.isCompleted }
    }

    private var completedTasks: [TaskItem] {
        filteredTasks.filter(\.isCompleted)
    }

    private var digestData: DailyDigestData {
        DailyDigestBuilder.make(tasks: tasks, ideas: ideas, notes: notes)
    }

    private var digestSummary: String {
        digestSummaryText ?? DailyDigestSummaryService.localSummary(data: digestData, languageStore: languageStore)
    }

    private var digestSpotlightTasks: [TaskItem] {
        Array(digestData.prioritizedTasks.filter { !$0.isCompleted }.prefix(2))
    }

    /// Stable id for digest task: changes when digest input changes.
    private var digestTaskIdentifier: String {
        DailyDigestFingerprint.identifier(
            tasks: tasks,
            ideas: ideas,
            notes: notes,
            languageCode: languageStore.code
        )
    }

    private func hydrateDigestFromCache() {
        if let cached = DailyDigestCache.summary(forFingerprint: digestTaskIdentifier) {
            digestSummaryText = cached
        } else {
            digestSummaryText = nil
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            tasksScrollContent()
        }
        .scrollClipDisabled()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tasks.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: ideas.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: notes.count)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: selectedFilter)
    }

    @ViewBuilder
    private func tasksScrollContent() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            tasksScreenHeader()
            digestCard()
            tasksMainBody()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tasksScreenHeader() -> some View {
        SectionHeaderView(
            title: languageStore.localized("tasks.screen.title"),
            subtitle: languageStore.localizedFormat(
                "tasks.screen.subtitle_open",
                Int64(tasks.filter { !$0.isCompleted }.count)
            )
        )
    }

    @ViewBuilder
    private func digestCard() -> some View {
        DigestCardView(
            greeting: languageStore.localized("digest.greeting"),
            summary: digestSummary,
            spotlightTasks: digestSpotlightTasks
        )
        .onAppear { hydrateDigestFromCache() }
        .onChange(of: digestTaskIdentifier) { _, _ in hydrateDigestFromCache() }
        .task(id: digestTaskIdentifier) {
            digestSummaryText = await DailyDigestSummaryService.summarize(
                tasks: tasks,
                ideas: ideas,
                notes: notes,
                languageStore: languageStore,
                aiService: aiService
            )
        }
        .animation(.easeOut(duration: 0.28), value: digestData)
    }

    @ViewBuilder
    private func tasksMainBody() -> some View {
        if !tasks.isEmpty {
            TaskFilterPillsView(selection: $selectedFilter, title: filterTitle)
        }

        if tasks.isEmpty {
            EmptyStateView(
                title: languageStore.localized("tasks.empty.title"),
                message: languageStore.localized("tasks.empty.message"),
                systemImage: "leaf.fill"
            )
        } else if filteredTasks.isEmpty {
            EmptyStateView(
                title: languageStore.localized("tasks.empty.filtered.title"),
                message: languageStore.localized("tasks.empty.filtered.message"),
                systemImage: "line.3.horizontal.decrease.circle"
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

    private func filterTitle(_ filter: TaskListFilter) -> String {
        switch filter {
        case .all:
            languageStore.localized("tasks.filter.all")
        case .urgent:
            languageStore.localized("tasks.filter.urgent")
        case .important:
            languageStore.localized("tasks.filter.important")
        case .lowPriority:
            languageStore.localized("tasks.filter.low_priority")
        case .done:
            languageStore.localized("tasks.filter.done")
        }
    }

    @ViewBuilder
    private func taskSection(title: String, subtitle: String, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: title, subtitle: subtitle)

            ForEach(tasks) { task in
                TaskCardView(
                    task: task,
                    onToggleComplete: { toggleCompletion(for: task) },
                    onToggleToday: { toggleToday(for: task) },
                    onDelete: { delete(task) }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(x: 20))
                    )
                )
            }
        }
    }

    private func toggleCompletion(for task: TaskItem) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            task.isCompleted.toggle()
        }
        saveContext()
    }

    private func toggleToday(for task: TaskItem) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            task.isToday.toggle()
        }
        saveContext()
    }

    private func delete(_ task: TaskItem) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
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
