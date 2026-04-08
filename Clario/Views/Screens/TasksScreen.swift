import SwiftUI
import SwiftData

struct TasksScreen: View {
    private enum TaskFilter: String, CaseIterable, Identifiable {
        case all
        case urgent
        case important
        case lowPriority
        case done

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Bindable private var languageStore = AppLanguageStore.shared
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \IdeaItem.createdAt, order: .reverse) private var ideas: [IdeaItem]
    @Query(sort: \NoteItem.createdAt, order: .reverse) private var notes: [NoteItem]

    @State private var selectedFilter: TaskFilter = .all
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

    /// Stable id for `.task`: changes when digest input changes (same rules as `DailyDigestFingerprint`).
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
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderView(
                    title: languageStore.localized("tasks.screen.title"),
                    subtitle: languageStore.localizedFormat(
                        "tasks.screen.subtitle_open",
                        Int64(tasks.filter { !$0.isCompleted }.count)
                    )
                )

                DailyDigestCard(summary: digestSummary)
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
                    .animation(.easeOut(duration: 0.22), value: digestData)

                if !tasks.isEmpty {
                    taskFilterChips
                }

                if tasks.isEmpty {
                    EmptyStateView(
                        title: languageStore.localized("tasks.empty.title"),
                        message: languageStore.localized("tasks.empty.message"),
                        systemImage: "checklist.checked"
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
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .animation(.snappy, value: tasks.count)
        .animation(.snappy, value: ideas.count)
        .animation(.snappy, value: notes.count)
        .animation(.snappy, value: selectedFilter)
    }

    private var taskFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filterTitle(filter))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Color.accentColor.opacity(0.22) : Color.black.opacity(0.05),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedFilter == filter ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterTitle(_ filter: TaskFilter) -> String {
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
