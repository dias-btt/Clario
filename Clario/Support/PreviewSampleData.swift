import Foundation
import SwiftData

enum PreviewSampleData {
    @MainActor
    static var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(
                for: TaskItem.self,
                IdeaItem.self,
                NoteItem.self,
                configurations: config
            )

            let context = container.mainContext

            context.insert(TaskItem(title: AppLanguageStore.shared.localized("preview.task1"), isToday: true, priorityTag: .urgent))
            context.insert(TaskItem(title: AppLanguageStore.shared.localized("preview.task2"), isCompleted: true, priorityTag: .important, createdAt: .now.addingTimeInterval(-3600)))
            context.insert(IdeaItem(content: AppLanguageStore.shared.localized("preview.idea1")))
            context.insert(NoteItem(content: AppLanguageStore.shared.localized("preview.note1")))

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
