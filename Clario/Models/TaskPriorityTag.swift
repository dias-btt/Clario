import Foundation

enum TaskPriorityTag: String, Codable, CaseIterable, Identifiable {
    case urgent = "urgent"
    case important = "important"
    case lowPriority = "low_priority"

    var id: String { rawValue }

    static func from(aiString: String) -> TaskPriorityTag {
        let trimmed = aiString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return TaskPriorityTag(rawValue: trimmed) ?? .important
    }
}
