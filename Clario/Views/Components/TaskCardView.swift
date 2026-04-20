import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let onToggleComplete: () -> Void
    let onToggleToday: () -> Void
    let onDelete: () -> Void

    @Bindable private var languageStore = AppLanguageStore.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            priorityRail()
            taskCardRow()
                .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: ClarioRadius.card, style: .continuous)
                .fill(ClarioPalette.cardSurface(colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: ClarioRadius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ClarioPalette.indigo.opacity(colorScheme == .dark ? 0.06 : 0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .opacity(task.isCompleted ? 0 : 1)
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: ClarioRadius.card, style: .continuous)
                .stroke(ClarioPalette.cardStroke(colorScheme), lineWidth: 1)
        )
        .clarioCardShadow(colorScheme: colorScheme)
        .opacity(task.isCompleted ? 0.68 : 1)
        .scaleEffect(task.isCompleted ? 0.98 : 1)
        .offset(x: task.isCompleted ? 4 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.76), value: task.isCompleted)
    }

    @ViewBuilder
    private func priorityRail() -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(task.priorityTag.railColor)
            .frame(width: 4)
            .padding(.vertical, 14)
            .padding(.leading, 10)
            .opacity(task.isCompleted ? 0.35 : 1)
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
                    .strokeBorder(
                        task.isCompleted ? Color.clear : ClarioPalette.secondaryText(colorScheme).opacity(0.35),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle()
                            .fill(
                                task.isCompleted
                                    ? ClarioPalette.calmGreen
                                    : ClarioPalette.mist.opacity(colorScheme == .dark ? 0.12 : 1)
                            )
                    )

                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 30, height: 30)
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
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(
                    task.isCompleted
                        ? ClarioPalette.secondaryText(colorScheme)
                        : ClarioPalette.primaryText(colorScheme)
                )
                .strikethrough(task.isCompleted, color: ClarioPalette.secondaryText(colorScheme).opacity(0.5))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: task.isCompleted)

            Spacer()

            Text(task.createdAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
        }
    }

    @ViewBuilder
    private func taskMetaRow() -> some View {
        HStack(spacing: 8) {
            Text(task.priorityTag.localizedLabel(using: languageStore))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(task.priorityTag.pillBackground(colorScheme: colorScheme), in: Capsule())
                .foregroundStyle(task.priorityTag.pillForeground)

            Button(action: onToggleToday) {
                Label(
                    task.isToday ? languageStore.localized("task.schedule.today") : languageStore.localized("task.schedule.later"),
                    systemImage: task.isToday ? "sun.max.fill" : "sun.max"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    task.isToday
                        ? ClarioPalette.warmAmber.opacity(0.18)
                        : ClarioPalette.primaryText(colorScheme).opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(
                    task.isToday ? ClarioPalette.warmAmber : ClarioPalette.secondaryText(colorScheme)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 10)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
                    .frame(width: 34, height: 34)
                    .background(ClarioPalette.primaryText(colorScheme).opacity(0.06), in: Circle())
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

    var pillForeground: Color {
        switch self {
        case .urgent:
            ClarioPalette.roseGlow
        case .important:
            ClarioPalette.warmAmber
        case .lowPriority:
            ClarioPalette.calmGreen.opacity(0.95)
        }
    }

    func pillBackground(colorScheme: ColorScheme) -> Color {
        pillForeground.opacity(colorScheme == .dark ? 0.18 : 0.14)
    }

    var railColor: Color {
        switch self {
        case .urgent:
            ClarioPalette.roseGlow
        case .important:
            ClarioPalette.warmAmber
        case .lowPriority:
            ClarioPalette.calmGreen
        }
    }
}
