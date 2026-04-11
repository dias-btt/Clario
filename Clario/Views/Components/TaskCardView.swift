import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let onToggleComplete: () -> Void
    let onToggleToday: () -> Void
    let onDelete: () -> Void

    @Bindable private var languageStore = AppLanguageStore.shared

    var body: some View {
        taskCardRow()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(task.isCompleted ? Color.white.opacity(0.65) : Color.white.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: .black.opacity(task.isCompleted ? 0.03 : 0.07), radius: 18, y: 10)
            .opacity(task.isCompleted ? 0.72 : 1)
            .scaleEffect(task.isCompleted ? 0.985 : 1)
    }

    @ViewBuilder
    private func taskCardRow() -> some View {
        HStack(alignment: .center, spacing: 14) {
            taskCompletionButton()
            taskCardMainColumn()
        }
    }

    @ViewBuilder
    private func taskCompletionButton() -> some View {
        Button(action: onToggleComplete) {
            ZStack {
                Circle()
                    .strokeBorder(task.isCompleted ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(task.isCompleted ? Color(red: 0.34, green: 0.78, blue: 0.50) : Color.white)
                    )

                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func taskCardMainColumn() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            taskTitleRow()
            taskMetaRow()
        }
    }

    @ViewBuilder
    private func taskTitleRow() -> some View {
        HStack(alignment: .top) {
            Text(task.title)
                .font(.body.weight(.medium))
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted, color: .secondary)
                .animation(.snappy, value: task.isCompleted)

            Spacer()

            Text(task.createdAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func taskMetaRow() -> some View {
        HStack(spacing: 8) {
            Text(task.priorityTag.localizedLabel(using: languageStore))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(task.priorityTag.labelBackgroundColor, in: Capsule())
                .foregroundStyle(task.priorityTag.labelForegroundColor)

            Button(action: onToggleToday) {
                Label(
                    task.isToday ? languageStore.localized("task.schedule.today") : languageStore.localized("task.schedule.later"),
                    systemImage: task.isToday ? "sun.max.fill" : "sun.max"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(task.isToday ? Color.orange.opacity(0.16) : Color.gray.opacity(0.10), in: Capsule())
                .foregroundStyle(task.isToday ? Color.orange : .secondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 10)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private extension TaskPriorityTag {
    func localizedLabel(using store: AppLanguageStore) -> String {
        switch self {
        case .urgent:
            store.localized("task.tag.urgent")
        case .important:
            store.localized("task.tag.important")
        case .lowPriority:
            store.localized("task.tag.low_priority")
        }
    }

    var labelForegroundColor: Color {
        switch self {
        case .urgent:
            Color.red.opacity(0.92)
        case .important:
            Color.orange
        case .lowPriority:
            Color.secondary
        }
    }

    var labelBackgroundColor: Color {
        labelForegroundColor.opacity(0.14)
    }
}
