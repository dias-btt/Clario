import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var isToday: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        isToday: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isToday = isToday
        self.createdAt = createdAt
    }
}
