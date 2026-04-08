import Foundation

struct CaptureDraft: Identifiable, Sendable {
    struct Item: Identifiable, Sendable, Hashable {
        let id: UUID
        var text: String
        var tag: TaskPriorityTag?
        var isKept: Bool

        init(id: UUID = UUID(), text: String, tag: TaskPriorityTag? = nil, isKept: Bool = true) {
            self.id = id
            self.text = text
            self.tag = tag
            self.isKept = isKept
        }
    }

    let id: UUID
    var tasks: [Item]
    var ideas: [Item]
    var notes: [Item]

    init(id: UUID = UUID(), tasks: [Item], ideas: [Item], notes: [Item]) {
        self.id = id
        self.tasks = tasks
        self.ideas = ideas
        self.notes = notes
    }

    init(result: AIResult) {
        self.init(
            tasks: result.tasks.map { Item(text: $0.title, tag: $0.tag) },
            ideas: result.ideas.map { Item(text: $0) },
            notes: result.notes.map { Item(text: $0) }
        )
    }

    var keptTasks: [String] { tasks.filter(\.isKept).map(\.text) }
    var keptIdeas: [String] { ideas.filter(\.isKept).map(\.text) }
    var keptNotes: [String] { notes.filter(\.isKept).map(\.text) }

    mutating func keepAll() {
        tasks.indices.forEach { tasks[$0].isKept = true }
        ideas.indices.forEach { ideas[$0].isKept = true }
        notes.indices.forEach { notes[$0].isKept = true }
    }

    mutating func removeAll() {
        tasks.indices.forEach { tasks[$0].isKept = false }
        ideas.indices.forEach { ideas[$0].isKept = false }
        notes.indices.forEach { notes[$0].isKept = false }
    }
}
