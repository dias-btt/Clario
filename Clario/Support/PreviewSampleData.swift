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

            context.insert(TaskItem(title: "Send product update to team", isToday: true))
            context.insert(TaskItem(title: "Review onboarding copy", isCompleted: true, createdAt: .now.addingTimeInterval(-3600)))
            context.insert(IdeaItem(content: "Turn fleeting thoughts into a daily recap card."))
            context.insert(NoteItem(content: "Users should feel relief the moment they brain-dump something."))

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
