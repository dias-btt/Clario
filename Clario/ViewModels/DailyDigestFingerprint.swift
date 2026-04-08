import CryptoKit
import Foundation

/// Stable across launches (unlike `Hasher`). Changes when tasks, ideas, notes, language, or calendar day change.
enum DailyDigestFingerprint {
    static func identifier(
        tasks: [TaskItem],
        ideas: [IdeaItem],
        notes: [NoteItem],
        languageCode: String,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> String {
        let dayStart = calendar.startOfDay(for: now).timeIntervalSince1970

        var lines: [String] = []
        lines.append("v1")
        lines.append("day:\(dayStart)")
        lines.append("lang:\(languageCode)")

        for task in tasks.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            lines.append(
                "t:\(task.id.uuidString)|\(task.isCompleted)|\(task.isToday)|\(task.priorityTag.rawValue)|\(task.title)"
            )
        }
        for idea in ideas.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            lines.append(
                "i:\(idea.id.uuidString)|\(idea.createdAt.timeIntervalSinceReferenceDate)|\(idea.content)"
            )
        }
        for note in notes.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            lines.append(
                "n:\(note.id.uuidString)|\(note.createdAt.timeIntervalSinceReferenceDate)|\(note.content)"
            )
        }

        let raw = lines.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
