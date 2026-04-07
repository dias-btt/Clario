import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var isToday: Bool
    var priorityTag: TaskPriorityTag
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        isToday: Bool = false,
        priorityTag: TaskPriorityTag = .important,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isToday = isToday
        self.priorityTag = priorityTag
        self.createdAt = createdAt
    }
}
