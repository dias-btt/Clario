import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let onToggleComplete: () -> Void
    let onToggleToday: () -> Void
    let onDelete: () -> Void

    @Bindable private var languageStore = AppLanguageStore.shared

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .animation(.snappy, value: task.isCompleted)

                HStack(spacing: 8) {
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

                    Text(task.createdAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
}
